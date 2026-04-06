#!/usr/bin/env python3
"""Compatibility wrapper that launches the repo-owned mock API service."""

from __future__ import annotations

import pathlib
import sys

PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from services.mock_api.server import main


if __name__ == "__main__":
    raise SystemExit(main())
