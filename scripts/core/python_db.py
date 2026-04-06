#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import re
import sqlite3
import sys
from pathlib import Path

FIND_URL = re.compile(r"https?://\S+")

SCHEMA = """
CREATE TABLE IF NOT EXISTS findings (
    id INTEGER PRIMARY KEY,
    hash TEXT UNIQUE,
    program TEXT,
    url TEXT,
    vuln TEXT,
    cvss REAL,
    priority INTEGER,
    status TEXT
);
"""


def init_db(db_path: Path) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as connection:
        connection.execute(SCHEMA)
        connection.commit()


def insert_findings(db_path: Path, input_path: Path, program: str) -> None:
    with sqlite3.connect(db_path) as connection:
        for raw_line in input_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line:
                continue

            match = FIND_URL.search(line)
            url = match.group(0) if match else ""
            digest = hashlib.sha256(line.encode("utf-8")).hexdigest()

            connection.execute(
                """
                INSERT OR IGNORE INTO findings
                (hash, program, url, vuln, cvss, priority, status)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (digest, program, url, line, 9.8, 5, "new"),
            )

        connection.commit()


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(
            "Usage: python_db.py <init|insert> <db_path> [input_path] [program]",
            file=sys.stderr,
        )
        return 1

    command = argv[1]
    db_path = Path(argv[2]).resolve()

    if command == "init":
        init_db(db_path)
        return 0

    if command == "insert":
        if len(argv) != 5:
            print(
                "Usage: python_db.py insert <db_path> <input_path> <program>",
                file=sys.stderr,
            )
            return 1

        input_path = Path(argv[3]).resolve()
        program = argv[4]
        insert_findings(db_path, input_path, program)
        return 0

    print(f"Unsupported command: {command}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
