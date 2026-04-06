#!/usr/bin/env python3
"""Compatibility wrapper for the original script filename."""

import sys

sys.dont_write_bytecode = True

from url_checker import main


if __name__ == "__main__":
    raise SystemExit(main())
