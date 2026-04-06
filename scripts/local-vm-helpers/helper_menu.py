from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class MenuAction:
    key: str
    label: str
    filename: str | None = None
    open_path: str | None = None


def clear_screen() -> None:
    os.system("cls")


def print_header(helper_dir: Path) -> None:
    print("BBP Helper Menu")
    print("=" * 64)
    print(f"Folder: {helper_dir}")
    print("Choose one action and press Enter.")
    print()
    print("Recommended workflow")
    print("- New target: 1 -> test in Kali -> save evidence -> finish report")
    print("- Existing target: 2 -> continue notes/report from that workspace")
    print("- Raw facts only: 5 for DNS, TLS, ports, API, MQTT, and responses")
    print("- Repo services: 4 when you need local Docker stacks on Windows")
    print()


def build_actions() -> list[MenuAction]:
    return [
        MenuAction("1", "Start manual testing session", "start_manual_testing.bat"),
        MenuAction("2", "Pick target from existing workspaces", "pick_manual_target.bat"),
        MenuAction("3", "Create fresh manual report only", "new_manual_report.bat"),
        MenuAction("4", "Start local project dockers", "start_project_dockers.bat"),
        MenuAction("5", "Generate Kali debug report", "project_debug_report_kali.bat"),
        MenuAction("6", "Open Kali SSH shell", "open_kali_ssh.bat"),
        MenuAction("7", "Telemetry debug on Kali", "telemetry_debug_kali.bat"),
        MenuAction("8", "Public HTTPS/TLS check", "public_tls_sample_check.bat"),
        MenuAction("9", "MQTT/TLS check on Kali", "tls_test_kali.bat"),
        MenuAction(
            "W",
            "Open workflow and submission PDF",
            open_path="../../results/secure-test.six-swiss-exchange.com/reports/000_manual_testing_workflow_and_submission_guide.pdf",
        ),
        MenuAction(
            "S",
            "Open secure-test report samples folder",
            open_path="../../results/secure-test.six-swiss-exchange.com/reports",
        ),
        MenuAction("G", "Open helper guide", open_path="PROJECT_DEBUG_GUIDE.md"),
        MenuAction("R", "Open helper README", open_path="README.md"),
        MenuAction("F", "Open helper folder", open_path="."),
        MenuAction("Q", "Quit"),
    ]


def render_menu(actions: list[MenuAction]) -> None:
    for action in actions:
        print(f"[{action.key}] {action.label}")
    print()


def run_batch(helper_dir: Path, filename: str) -> None:
    script_path = helper_dir / filename
    if not script_path.exists():
        print(f"Missing file: {script_path}")
        input("Press Enter to return to the menu...")
        return

    result = subprocess.run(["cmd", "/c", str(script_path)], cwd=helper_dir)
    print()
    print(f"Finished: {filename} (exit code {result.returncode})")
    input("Press Enter to return to the menu...")


def open_item(helper_dir: Path, relative_path: str) -> None:
    target = (helper_dir / relative_path).resolve()
    if not target.exists():
        print(f"Missing path: {target}")
        input("Press Enter to return to the menu...")
        return

    os.startfile(str(target))  # type: ignore[attr-defined]
    print(f"Opened: {target}")
    input("Press Enter to return to the menu...")


def main() -> int:
    helper_dir = Path(__file__).resolve().parent
    actions = build_actions()
    action_map = {action.key.lower(): action for action in actions}

    while True:
        clear_screen()
        print_header(helper_dir)
        render_menu(actions)
        choice = input("Selection [1]: ").strip().lower() or "1"
        action = action_map.get(choice)

        if action is None:
            print()
            print("Invalid selection.")
            input("Press Enter to try again...")
            continue

        if action.key.lower() == "q":
            return 0

        clear_screen()
        print_header(helper_dir)
        print(f"Running: {action.label}")
        print()

        if action.filename:
            run_batch(helper_dir, action.filename)
        elif action.open_path:
            open_item(helper_dir, action.open_path)


if __name__ == "__main__":
    raise SystemExit(main())
