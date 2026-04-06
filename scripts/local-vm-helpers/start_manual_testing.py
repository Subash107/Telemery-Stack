from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from create_manual_report import DEFAULT_TARGET, DEFAULT_TITLE, build_entry_url, create_manual_report, prompt


DEFAULT_KALI_HOST = "192.168.1.22"


def open_path(path: Path) -> None:
    os.startfile(str(path))  # type: ignore[attr-defined]


def launch_kali_ssh(*, helper_dir: Path, python_cmd: str, kali_host: str) -> None:
    ssh_script = helper_dir / "Finalscriptkalisubash.py"
    command = [
        "powershell",
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        (
            f"Set-Location -LiteralPath '{helper_dir}'; "
            f"& {python_cmd} -u '.\\{ssh_script.name}' --host '{kali_host}'"
        ),
    ]
    subprocess.Popen(command)


def resolve_python_cmd() -> str:
    launcher = shutil.which("py")
    if launcher:
        return "py"
    launcher = shutil.which("python")
    if launcher:
        return "python"
    return sys.executable


def start_manual_session(
    *,
    helper_dir: Path,
    target: str,
    title: str,
    entry_url: str,
    kali_host: str,
    open_editor: bool = True,
    open_ssh: bool = True,
) -> None:
    paths = create_manual_report(target=target, title=title, entry_url=entry_url)

    if open_editor:
        open_path(paths.notes_path)
        open_path(paths.report_path)

    if open_ssh:
        launch_kali_ssh(helper_dir=helper_dir, python_cmd=resolve_python_cmd(), kali_host=kali_host)

    print()
    print("Manual testing session started.")
    print(f"Kali host        : {kali_host}")
    print(f"Notes file       : {paths.notes_path}")
    print(f"Report file      : {paths.report_path}")
    print(f"Evidence folder  : {paths.evidence_dir}")
    print(f"Requests folder  : {paths.requests_dir}")
    if open_editor:
        print("Editors          : notes and report opened with the default Markdown app")
    else:
        print("Editors          : skipped")
    if open_ssh:
        print("Kali SSH         : new interactive window opened")
    else:
        print("Kali SSH         : skipped")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a fresh manual report, open notes and report, and launch Kali SSH."
    )
    parser.add_argument("--target", default=DEFAULT_TARGET, help="Target host or label")
    parser.add_argument("--title", default=DEFAULT_TITLE, help="Short issue title")
    parser.add_argument("--entry-url", default="", help="Optional exact URL for the finding")
    parser.add_argument("--host", default=DEFAULT_KALI_HOST, help="Kali VM IP or hostname")
    parser.add_argument("--no-prompt", action="store_true", help="Use CLI values without prompting")
    parser.add_argument("--no-open-editor", action="store_true", help="Do not open notes or report files")
    parser.add_argument("--no-open-ssh", action="store_true", help="Do not launch the Kali SSH window")
    args = parser.parse_args()

    helper_dir = Path(__file__).resolve().parent

    target = args.target
    title = args.title
    entry_url = args.entry_url
    kali_host = args.host

    if not args.no_prompt:
        kali_host = prompt("Enter Kali VM IP/hostname", kali_host)
        target = prompt("Enter target host or label", target)
        title = prompt("Enter short issue title", title)
        entry_url = prompt("Enter exact entry URL", build_entry_url(target, entry_url or None))

    start_manual_session(
        helper_dir=helper_dir,
        target=target,
        title=title,
        entry_url=entry_url,
        kali_host=kali_host,
        open_editor=not args.no_open_editor,
        open_ssh=not args.no_open_ssh,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
