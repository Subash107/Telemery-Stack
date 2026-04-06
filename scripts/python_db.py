#!/usr/bin/env python3

from pathlib import Path
import runpy


if __name__ == "__main__":
    core_script = Path(__file__).resolve().parent / "core" / "python_db.py"
    runpy.run_path(str(core_script), run_name="__main__")
