import argparse
import base64
import getpass
import os
import shutil
import sys
import threading
import time

try:
    import paramiko
except ModuleNotFoundError:
    print(
        "This script needs the 'paramiko' package.\n"
        "Install it with: py -m pip install paramiko",
        file=sys.stderr,
    )
    raise SystemExit(1)

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


DEFAULT_HOST = "192.168.1.22"
DEFAULT_PORT = 22
DEFAULT_USERNAME = "subash"
PASSWORD_ENV_VAR = "KALI_VM_PASSWORD"
TIMEOUT_SECONDS = 10

# Minimal ANSI mappings so arrow keys work in the remote shell on Windows.
WINDOWS_SPECIAL_KEYS = {
    "H": "\x1b[A",  # Up
    "P": "\x1b[B",  # Down
    "K": "\x1b[D",  # Left
    "M": "\x1b[C",  # Right
    "G": "\x1b[H",  # Home
    "O": "\x1b[F",  # End
    "R": "\x1b[2~",  # Insert
    "S": "\x1b[3~",  # Delete
}


def connect_ssh(host, port, username, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=host,
        port=port,
        username=username,
        password=password,
        timeout=TIMEOUT_SECONDS,
        banner_timeout=TIMEOUT_SECONDS,
        auth_timeout=TIMEOUT_SECONDS,
        look_for_keys=False,
        allow_agent=False,
    )
    return client


def resolve_password(password: str | None) -> str:
    if password:
        return password

    env_password = os.getenv(PASSWORD_ENV_VAR, "")
    if env_password:
        return env_password

    if not sys.stdin.isatty():
        raise RuntimeError(
            f"SSH password was not provided. Set {PASSWORD_ENV_VAR} or pass --password."
        )

    prompted_password = getpass.getpass("Enter Kali VM SSH password: ")
    if not prompted_password:
        raise RuntimeError("An SSH password is required to connect to the Kali VM.")

    return prompted_password


def run_single_command(client, command):
    stdin, stdout, stderr = client.exec_command(command)
    del stdin
    exit_code = stdout.channel.recv_exit_status()
    stdout_text = stdout.read().decode("utf-8", errors="ignore")
    stderr_text = stderr.read().decode("utf-8", errors="ignore")

    if stdout_text:
        print(stdout_text, end="")
    if stderr_text:
        print(stderr_text, end="", file=sys.stderr)

    return exit_code


def _read_remote_output(channel, stop_event):
    while not stop_event.is_set():
        try:
            if channel.recv_ready():
                data = channel.recv(4096)
                if not data:
                    break
                sys.stdout.write(data.decode("utf-8", errors="ignore"))
                sys.stdout.flush()
            elif channel.closed:
                break
            else:
                time.sleep(0.02)
        except Exception:
            break

    stop_event.set()


def open_interactive_shell(client):
    if not sys.platform.startswith("win"):
        raise RuntimeError("This launcher is intended to be used from Windows.")

    import msvcrt

    transport = client.get_transport()
    if transport is None or not transport.is_active():
        raise RuntimeError("SSH transport is not active.")

    terminal_size = shutil.get_terminal_size((120, 40))
    channel = transport.open_session()
    channel.get_pty(term="xterm", width=terminal_size.columns, height=terminal_size.lines)
    channel.invoke_shell()

    stop_event = threading.Event()
    reader = threading.Thread(
        target=_read_remote_output,
        args=(channel, stop_event),
        daemon=True,
    )
    reader.start()

    try:
        while not stop_event.is_set():
            if channel.closed:
                stop_event.set()
                break

            if not msvcrt.kbhit():
                time.sleep(0.02)
                continue

            key = msvcrt.getwch()

            if key in ("\x00", "\xe0"):
                special_key = msvcrt.getwch()
                mapped_key = WINDOWS_SPECIAL_KEYS.get(special_key)
                if mapped_key:
                    channel.send(mapped_key)
                continue

            if key == "\r":
                channel.send("\n")
            elif key == "\x08":
                channel.send("\x7f")
            elif key == "\x03":
                channel.send("\x03")
            else:
                channel.send(key)
    except KeyboardInterrupt:
        try:
            channel.send("\x03")
        except Exception:
            pass
    finally:
        stop_event.set()
        try:
            channel.close()
        except Exception:
            pass
        reader.join(timeout=1)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Connect from Windows to the Kali VM over SSH."
    )
    parser.add_argument(
        "--host",
        default=os.getenv("KALI_VM_HOST", DEFAULT_HOST),
        help=f"Kali VM IP/hostname. Default: {DEFAULT_HOST}",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("KALI_VM_PORT", DEFAULT_PORT)),
        help=f"SSH port. Default: {DEFAULT_PORT}",
    )
    parser.add_argument(
        "--username",
        default=os.getenv("KALI_VM_USERNAME", DEFAULT_USERNAME),
        help=f"SSH username. Default: {DEFAULT_USERNAME}",
    )
    parser.add_argument(
        "--password",
        default="",
        help=f"SSH password. If omitted, {PASSWORD_ENV_VAR} or a secure prompt is used.",
    )
    parser.add_argument(
        "-c",
        "--command",
        help="Run one remote command and exit instead of opening an interactive shell.",
    )
    parser.add_argument(
        "--command-b64",
        help="Run one base64-encoded UTF-8 remote command and exit.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    client = None
    host = args.host
    port = args.port
    username = args.username
    password = resolve_password(args.password)

    try:
        print(f"Connecting to {username}@{host}:{port} ...")
        client = connect_ssh(host, port, username, password)
        print("Connected.")

        command = args.command
        if args.command_b64:
            command = base64.b64decode(args.command_b64).decode("utf-8")

        if command:
            return run_single_command(client, command)

        print("Interactive Kali shell started. Type 'exit' to disconnect.\n")
        open_interactive_shell(client)
        return 0
    except paramiko.AuthenticationException:
        print("Authentication failed. Check the username or password.", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"SSH connection failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
