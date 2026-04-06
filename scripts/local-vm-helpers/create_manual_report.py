from __future__ import annotations

import argparse
from dataclasses import dataclass
import re
from datetime import datetime
from pathlib import Path


DEFAULT_TARGET = "secure-test.six-swiss-exchange.com"
DEFAULT_TITLE = "candidate-finding"


@dataclass(frozen=True)
class ManualReportPaths:
    target_root: Path
    report_path: Path
    evidence_dir: Path
    requests_dir: Path
    notes_path: Path


def prompt(label: str, default: str) -> str:
    value = input(f"{label} [{default}]: ").strip()
    return value or default


def normalize_target(value: str) -> str:
    value = value.strip()
    value = re.sub(r"^https?://", "", value, flags=re.IGNORECASE)
    value = value.split("/")[0]
    return value


def sanitize_target(value: str) -> str:
    return re.sub(r'[\\/:*?"<>|]+', "_", normalize_target(value))


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"^https?://", "", value, flags=re.IGNORECASE)
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    return value or "finding"


def build_entry_url(target: str, explicit_url: str | None) -> str:
    if explicit_url:
        return explicit_url.strip()
    return f"https://{normalize_target(target)}/"


def render_report(
    template_text: str,
    *,
    target: str,
    title: str,
    entry_url: str,
    tested_date: str,
    evidence_path: Path,
    requests_path: Path,
    repo_root: Path,
) -> str:
    relative_evidence = evidence_path.relative_to(repo_root).as_posix()
    relative_requests = requests_path.relative_to(repo_root).as_posix()

    rendered = template_text
    rendered = rendered.replace("- Title:", f"- Title: {title}", 1)
    rendered = rendered.replace("- Asset / Hostname:", f"- Asset / Hostname: {target}", 1)
    rendered = rendered.replace("- Entry URL:", f"- Entry URL: {entry_url}", 1)
    rendered = rendered.replace("- Date Tested:", f"- Date Tested: {tested_date}", 1)
    rendered = rendered.replace(
        "- Relevant file paths:",
        f"- Relevant file paths: `{relative_evidence}` and `{relative_requests}`",
        1,
    )
    return rendered


def ensure_target_workspace(target_root: Path) -> None:
    (target_root / "evidence").mkdir(parents=True, exist_ok=True)
    (target_root / "requests").mkdir(parents=True, exist_ok=True)
    (target_root / "reports").mkdir(parents=True, exist_ok=True)


def ensure_manual_notes(target_root: Path, target: str, entry_url: str) -> Path:
    notes_path = target_root / "manual-notes.md"
    if notes_path.exists():
        return notes_path

    notes_path.write_text(
        "\n".join(
            [
                "# Manual Notes",
                "",
                "## Target",
                f"- Host: https://{target}",
                f"- Entry URL: {entry_url}",
                "- Test date:",
                "- Account used:",
                "",
                "## Endpoints",
                f"- https://{target}/",
                f"- {entry_url}",
                "",
                "## Observations",
                "- ",
                "",
                "## Candidate Findings",
                "1. ",
                "2. ",
                "3. ",
                "",
                "## Cleanup Notes",
                "- ",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return notes_path


def create_manual_report(
    *,
    target: str,
    title: str,
    entry_url: str = "",
    repo_root: Path | None = None,
) -> ManualReportPaths:
    repo_root = repo_root or Path(__file__).resolve().parents[2]
    template_path = repo_root / "sbubas_toolkit" / "07-manual-bounty-report-template.md"
    results_root = repo_root / "results"

    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")

    normalized_target = normalize_target(target)
    resolved_entry_url = build_entry_url(normalized_target, entry_url or None)
    safe_target = sanitize_target(normalized_target)
    slug = slugify(title)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    tested_date = datetime.now().strftime("%Y-%m-%d")

    target_root = results_root / safe_target
    ensure_target_workspace(target_root)

    evidence_dir = target_root / "evidence" / slug
    requests_dir = target_root / "requests" / slug
    reports_dir = target_root / "reports"

    evidence_dir.mkdir(parents=True, exist_ok=True)
    requests_dir.mkdir(parents=True, exist_ok=True)
    notes_path = ensure_manual_notes(target_root, normalized_target, resolved_entry_url)

    report_path = reports_dir / f"{timestamp}_{slug}.md"
    template_text = template_path.read_text(encoding="utf-8")
    report_text = render_report(
        template_text,
        target=normalized_target,
        title=title,
        entry_url=resolved_entry_url,
        tested_date=tested_date,
        evidence_path=evidence_dir,
        requests_path=requests_dir,
        repo_root=repo_root,
    )
    report_path.write_text(report_text, encoding="utf-8")

    return ManualReportPaths(
        target_root=target_root,
        report_path=report_path,
        evidence_dir=evidence_dir,
        requests_dir=requests_dir,
        notes_path=notes_path,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a fresh manual bounty report draft.")
    parser.add_argument("--target", default=DEFAULT_TARGET, help="Target host or label")
    parser.add_argument("--title", default=DEFAULT_TITLE, help="Short issue title")
    parser.add_argument("--entry-url", default="", help="Optional exact URL for the finding")
    parser.add_argument("--no-prompt", action="store_true", help="Use defaults and CLI values")
    parser.add_argument("--emit-paths", action="store_true", help="Print output paths in KEY=VALUE form")
    args = parser.parse_args()

    target = args.target
    title = args.title
    entry_url = args.entry_url

    if not args.no_prompt:
        target = prompt("Enter target host or label", target)
        title = prompt("Enter short issue title", title)
        entry_url = prompt("Enter exact entry URL", build_entry_url(target, entry_url or None))

    paths = create_manual_report(target=target, title=title, entry_url=entry_url)

    print()
    print("Manual report draft created.")
    print(f"Target workspace : {paths.target_root}")
    print(f"Report file      : {paths.report_path}")
    print(f"Evidence folder  : {paths.evidence_dir}")
    print(f"Requests folder  : {paths.requests_dir}")
    print(f"Notes file       : {paths.notes_path}")
    print()
    print("Next steps")
    print("1. Save screenshots and raw responses in the new evidence folder.")
    print("2. Save the exact HTTP requests in the new requests folder.")
    print("3. Fill the new report file before submitting anything.")
    print("4. Keep one vulnerability per report.")

    if args.emit_paths:
        print(f"REPORT_PATH={paths.report_path}")
        print(f"NOTES_PATH={paths.notes_path}")
        print(f"EVIDENCE_DIR={paths.evidence_dir}")
        print(f"REQUESTS_DIR={paths.requests_dir}")
        print(f"TARGET_ROOT={paths.target_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
