#!/usr/bin/env python3
"""
Connect to two URLs automatically and print the result.

Edit the URLS list below or pass two URLs on the command line.
"""

from __future__ import annotations

import sys
import urllib.error
import urllib.request

URLS = [
    "https://example.com",
    "https://example.org",
]
TIMEOUT_SECONDS = 10


def check_url(url: str) -> bool:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "SimplePythonUrlConnector/1.0"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            print(f"[OK] {url} -> HTTP {response.status}")
            return True
    except urllib.error.URLError as exc:
        print(f"[ERROR] {url} -> {exc}")
        return False


def main() -> int:
    urls = sys.argv[1:] if len(sys.argv) > 1 else URLS
    if len(urls) != 2:
        print("Usage: python \"New Text Document.py\" <url1> <url2>")
        print("Or edit the URLS list inside the script.")
        return 1

    success = all(check_url(url) for url in urls)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
