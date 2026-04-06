from __future__ import annotations

import argparse
from datetime import datetime
import pathlib
import shlex
import sys

try:
    from Finalscriptkalisubash import (
        DEFAULT_HOST,
        DEFAULT_PORT,
        DEFAULT_USERNAME,
        connect_ssh,
        resolve_password,
    )
except ImportError as exc:
    print(f"Failed to import SSH helper: {exc}", file=sys.stderr)
    raise SystemExit(1)


DEFAULT_TARGET = "secure-test.six-swiss-exchange.com"
DEFAULT_TLS_PORT = 443
DEFAULT_CIDR = "192.168.1.0/24"
REPORTS_DIR = pathlib.Path(__file__).resolve().parent / "reports"


def prompt(prompt_text: str, default: str) -> str:
    value = input(f"{prompt_text} [{default}]: ").strip()
    return value or default


def wrap_bash(command: str) -> str:
    return "bash -lc " + shlex.quote(command)


def python_one_liner(code: str) -> str:
    return "python3 -c " + shlex.quote(code)


def run_section(client, title: str, command: str, report_handle) -> None:
    print(f"[{title}]")
    report_handle.write("================================================================\n")
    report_handle.write(f"{title}\n")
    report_handle.write("================================================================\n\n")

    stdin, stdout, stderr = client.exec_command(wrap_bash(command))
    del stdin
    exit_code = stdout.channel.recv_exit_status()

    stdout_text = stdout.read().decode("utf-8", errors="replace")
    stderr_text = stderr.read().decode("utf-8", errors="replace")

    if stdout_text:
        report_handle.write(stdout_text)
        if not stdout_text.endswith("\n"):
            report_handle.write("\n")

    if stderr_text:
        report_handle.write(stderr_text)
        if not stderr_text.endswith("\n"):
            report_handle.write("\n")

    if exit_code != 0 and not stderr_text:
        report_handle.write(f"Command exited with status {exit_code}.\n")

    report_handle.write("\n\n")


def build_sections(target_host: str, tls_port: int, cidr_value: str) -> list[tuple[str, str]]:
    target_q = shlex.quote(target_host)
    tls_port_q = shlex.quote(str(tls_port))

    prometheus_code = (
        "import json, urllib.request; "
        "data = json.load(urllib.request.urlopen('http://127.0.0.1:9090/api/v1/targets?state=active')); "
        "targets = data.get('data', {}).get('activeTargets', []); "
        "print('Prometheus targets'); "
        "print('=================='); "
        "[print(' - {} health={} lastError={}'.format(t.get('scrapeUrl'), t.get('health'), t.get('lastError'))) for t in targets]"
    )

    cidr_code = (
        "import ipaddress, socket; "
        f"cidr = {cidr_value!r}; "
        f"target = {target_host!r}; "
        "print('CIDR analysis'); "
        "print('============='); "
        "net = ipaddress.ip_network(cidr, strict=False); "
        "print(f'network={net}'); "
        "print(f'netmask={net.netmask}'); "
        "broadcast = getattr(net, 'broadcast_address', 'n/a'); "
        "print(f'broadcast={broadcast}'); "
        "print(f'hosts={net.num_addresses}'); "
        "print(); "
        "print('Target membership'); "
        "print('================='); "
        "ips = [target] if target.replace('.', '').isdigit() else socket.gethostbyname_ex(target)[2]; "
        "[print(f'{ip} in {net}: {ipaddress.ip_address(ip) in net}') for ip in ips]"
    )

    return [
        (
            "Host Summary",
            "date -Is && printf '\\n'; hostnamectl || uname -a; "
            "printf '\\nAddresses\\n=========\\n'; hostname -I 2>/dev/null || ip -br addr",
        ),
        (
            "Docker Containers",
            "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'",
        ),
        (
            "Important Listening Ports",
            "ss -tulpn | grep -E ':(22|161|1883|8883|3000|5000|8000|8080|9090|18080|50061|30080|30061)\\b' "
            "|| echo 'No matching ports found.'",
        ),
        (
            "Project API Listing",
            "printf 'HTTP routes\\n===========\\n'; "
            "curl -fsS http://127.0.0.1:30080/mock-six-api/routes 2>/dev/null "
            "|| curl -fsS http://127.0.0.1:18080/mock-six-api/routes 2>/dev/null "
            "|| printf 'Mock API routes endpoint not available in the current Kali deployment.\\n"
            "Expected HTTP routes:\\n"
            " - GET /mock-six-api/health\\n"
            " - POST /mock-six-api/login\\n"
            " - PUT /mock-six-api/upload?program=<name>&filename=<file>&sha256=<optional>\\n'; "
            "printf '\\n\\ngRPC services\\n=============\\n'; "
            "grpcurl -plaintext 127.0.0.1:30061 list 2>/dev/null "
            "|| grpcurl -plaintext 127.0.0.1:50061 list 2>/dev/null "
            "|| echo 'gRPC service list not reachable.'",
        ),
        (
            "MQTT Collections",
            "printf 'MQTT dashboard root\\n===================\\n'; "
            "curl -fsS http://127.0.0.1:5000/ || echo 'MQTT dashboard root not reachable.'; "
            "printf '\\n\\nMQTT collected data\\n===================\\n'; "
            "curl -fsS http://127.0.0.1:5000/data || echo 'MQTT dashboard data not reachable.'; "
            "printf '\\n\\nMQTT and Kafka metrics\\n======================\\n'; "
            "curl -fsS http://127.0.0.1:8000/metrics | "
            "grep -E 'mqtt_messages_total|kafka_messages_total|kafka_errors_total' "
            "|| echo 'MQTT/Kafka metrics not reachable.'",
        ),
        (
            "Prometheus Targets",
            python_one_liner(prometheus_code) + " 2>/dev/null || echo 'Prometheus targets not reachable.'",
        ),
        (
            "DNS And Reverse IP",
            f"printf 'DNS records\\n===========\\n'; "
            f"dig +short {target_q} A; "
            f"dig +short {target_q} AAAA; "
            f"printf '\\nCanonical and PTR hints\\n=======================\\n'; "
            f"host {target_q} 2>/dev/null || nslookup {target_q} 2>/dev/null || echo 'DNS lookup failed.'; "
            f"printf '\\nReverse PTR for resolved IPs\\n============================\\n'; "
            f"for ip in $(dig +short {target_q} A); do echo \"IP: $ip\"; dig +short -x \"$ip\"; echo; done",
        ),
        (
            "CIDR Check",
            python_one_liner(cidr_code),
        ),
        (
            "SSL Certificate",
            f"printf 'TLS certificate summary\\n=======================\\n'; "
            f"timeout 15 openssl s_client -connect {target_q}:{tls_port_q} -servername {target_q} "
            f"</dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256 "
            "|| echo 'TLS certificate check failed.'",
        ),
        (
            "Target Port Check",
            f"printf 'Target port check\\n=================\\n'; "
            f"timeout 45 nmap -Pn -T4 --max-retries 1 --version-light -sT -sV -p {tls_port_q},80,443,8443,8080 {target_q} 2>/dev/null "
            "|| echo 'Port scan timed out or failed.'",
        ),
        (
            "Response Collections",
            f"printf 'HTTP response collection\\n========================\\n'; "
            f"curl -k -I --max-time 15 https://{target_q}:{tls_port_q} 2>&1 || echo 'HTTPS headers not reachable.'; "
            "printf '\\n\\nMock API health response\\n========================\\n'; "
            "curl -fsS http://127.0.0.1:30080/mock-six-api/health "
            "|| curl -fsS http://127.0.0.1:18080/mock-six-api/health "
            "|| echo 'Mock API health not reachable.'; "
            "printf '\\n\\nSaved project receipts\\n=====================\\n'; "
            "find ~/bbp_final_pro_framework/results -maxdepth 2 -name api_upload_receipt.json -print 2>/dev/null | "
            "while IFS= read -r f; do echo \"$f\"; echo '---'; cat \"$f\"; echo; done; "
            "find ~/bbp_final_pro_framework/results -maxdepth 2 -name api_upload_receipt.json -print -quit 2>/dev/null | "
            "grep -q . || echo 'No upload receipts found in the project copy on Kali.'",
        ),
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a Kali project debug report over SSH.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--username", default=DEFAULT_USERNAME)
    parser.add_argument("--password", default="")
    parser.add_argument("--target", default=DEFAULT_TARGET)
    parser.add_argument("--tls-port", type=int, default=DEFAULT_TLS_PORT)
    parser.add_argument("--cidr", default=DEFAULT_CIDR)
    parser.add_argument("--no-prompt", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    host = args.host
    target = args.target
    tls_port = args.tls_port
    cidr_value = args.cidr
    password = resolve_password(args.password)

    if not args.no_prompt:
        host = prompt("Enter Kali VM IP/hostname", host)
        target = prompt("Enter hostname/IP to debug", target)
        tls_port = int(prompt("Enter TLS port to inspect", str(tls_port)))
        cidr_value = prompt("Enter CIDR or IP/CIDR for range checks", cidr_value)

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORTS_DIR / f"project_debug_{datetime.now():%Y%m%d_%H%M%S}.txt"

    with connect_ssh(host, args.port, args.username, password) as client, report_path.open(
        "w", encoding="utf-8"
    ) as report_handle:
        report_handle.write("Kali VM Project Debug Report\n")
        report_handle.write("================================================================\n")
        report_handle.write(f"Generated on Windows side: {datetime.now().isoformat()}\n")
        report_handle.write(f"Remote host: {host}\n")
        report_handle.write(f"Target host: {target}\n")
        report_handle.write(f"TLS port: {tls_port}\n")
        report_handle.write(f"CIDR input: {cidr_value}\n")
        report_handle.write("Collection mode: read-only checks only; no services modified\n\n")

        for title, command in build_sections(target, tls_port, cidr_value):
            run_section(client, title, command, report_handle)

    print("\nProject debug report complete.")
    print("Report saved to:")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
