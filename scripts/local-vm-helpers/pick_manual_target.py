from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from create_manual_report import DEFAULT_TARGET, DEFAULT_TITLE, build_entry_url, normalize_target, prompt
from start_manual_testing import DEFAULT_KALI_HOST, start_manual_session


@dataclass(frozen=True)
class WorkspaceInfo:
    name: str
    target: str
    entry_url: str
    path: Path


def parse_workspace_metadata(workspace: Path) -> WorkspaceInfo:
    target = workspace.name
    entry_url = build_entry_url(target, None)

    notes_path = workspace / "manual-notes.md"
    scope_path = workspace / "scope-summary.md"

    if notes_path.exists():
        for line in notes_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("- Host:"):
                host_value = line.split(":", 1)[1].strip()
                target = normalize_target(host_value)
            elif line.startswith("- Entry URL:"):
                entry_url = line.split(":", 1)[1].strip()

    if scope_path.exists():
        for line in scope_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("- Scope host:") and target == workspace.name:
                host_value = line.split(":", 1)[1].strip()
                target = normalize_target(host_value)
            elif line.startswith("- Observed public entry path:") and entry_url == build_entry_url(workspace.name, None):
                entry_url = line.split(":", 1)[1].strip()

    return WorkspaceInfo(name=workspace.name, target=target, entry_url=entry_url, path=workspace)


def discover_workspaces(results_root: Path) -> list[WorkspaceInfo]:
    return [parse_workspace_metadata(path) for path in sorted(results_root.iterdir()) if path.is_dir()]


def choose_workspace(workspaces: list[WorkspaceInfo]) -> WorkspaceInfo | None:
    if not workspaces:
        return None

    print()
    print("Existing result workspaces")
    for index, workspace in enumerate(workspaces, start=1):
        print(f"{index}. {workspace.name}  ->  {workspace.entry_url}")
    print("C. Custom target")

    while True:
        choice = input("Choose workspace number or C for custom [1]: ").strip()
        if not choice:
            return workspaces[0]
        if choice.lower() in {"c", "custom"}:
            return None
        if choice.isdigit():
            idx = int(choice)
            if 1 <= idx <= len(workspaces):
                return workspaces[idx - 1]
        print("Invalid choice. Enter a listed number or C.")


def find_workspace(workspaces: list[WorkspaceInfo], name: str) -> WorkspaceInfo | None:
    lowered = name.strip().lower()
    for workspace in workspaces:
        if workspace.name.lower() == lowered or workspace.target.lower() == lowered:
            return workspace
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Pick a target from existing results workspaces and start a manual testing session."
    )
    parser.add_argument("--workspace", default="", help="Existing workspace directory name under results/")
    parser.add_argument("--target", default=DEFAULT_TARGET, help="Fallback target for custom mode")
    parser.add_argument("--title", default=DEFAULT_TITLE, help="Short issue title")
    parser.add_argument("--entry-url", default="", help="Optional exact URL for the finding")
    parser.add_argument("--host", default=DEFAULT_KALI_HOST, help="Kali VM IP or hostname")
    parser.add_argument("--no-prompt", action="store_true", help="Use CLI values without prompting")
    parser.add_argument("--no-open-editor", action="store_true", help="Do not open notes or report files")
    parser.add_argument("--no-open-ssh", action="store_true", help="Do not launch the Kali SSH window")
    args = parser.parse_args()

    helper_dir = Path(__file__).resolve().parent
    repo_root = helper_dir.parents[1]
    results_root = repo_root / "results"
    workspaces = discover_workspaces(results_root)

    kali_host = args.host
    title = args.title
    entry_url = args.entry_url
    target = args.target

    chosen_workspace: WorkspaceInfo | None = None
    if args.workspace:
        chosen_workspace = find_workspace(workspaces, args.workspace)
        if chosen_workspace is None:
            raise SystemExit(f"Workspace not found: {args.workspace}")

    if not args.no_prompt:
        kali_host = prompt("Enter Kali VM IP/hostname", kali_host)
        if chosen_workspace is None:
            chosen_workspace = choose_workspace(workspaces)

        if chosen_workspace is not None:
            target = chosen_workspace.target
            entry_url = chosen_workspace.entry_url

        target = prompt("Confirm target host or label", target)
        title = prompt("Enter short issue title", title)
        entry_url = prompt("Enter exact entry URL", build_entry_url(target, entry_url or None))
    else:
        if chosen_workspace is not None:
            target = chosen_workspace.target
            if not entry_url:
                entry_url = chosen_workspace.entry_url

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
