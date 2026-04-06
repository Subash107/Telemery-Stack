#!/usr/bin/env python3
"""Chrome/Edge native messaging host for the URL checker extension."""

from __future__ import annotations

import json
import struct
import sys
import traceback

sys.dont_write_bytecode = True

from url_checker import DEFAULT_PROXY_URL, run_checks_and_open_second_url

HOST_NAME = "com.bbp.url_checker"


def read_message() -> dict | None:
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        return None

    message_length = struct.unpack("<I", raw_length)[0]
    payload = sys.stdin.buffer.read(message_length).decode("utf-8")
    return json.loads(payload)


def send_message(message: dict) -> None:
    encoded = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def handle_message(message: dict) -> dict:
    action = message.get("action", "check_urls")
    urls = message.get("urls", [])
    proxy_url = message.get("proxyUrl", DEFAULT_PROXY_URL)

    if action != "check_urls":
        return {
            "ok": False,
            "error": f"Unsupported action: {action}",
            "host": HOST_NAME,
        }

    if not isinstance(urls, list) or len(urls) != 2 or not all(
        isinstance(url, str) and url.strip() for url in urls
    ):
        return {
            "ok": False,
            "error": "Expected exactly two non-empty URL strings.",
            "host": HOST_NAME,
        }

    if not isinstance(proxy_url, str) or not proxy_url.strip():
        return {
            "ok": False,
            "error": "Expected proxyUrl to be a non-empty string.",
            "host": HOST_NAME,
        }

    try:
        success, results, resolved_proxy_url = run_checks_and_open_second_url(urls, proxy_url)
    except ValueError as exc:
        return {
            "ok": False,
            "error": str(exc),
            "host": HOST_NAME,
        }

    return {
        "ok": success,
        "host": HOST_NAME,
        "proxyUrl": resolved_proxy_url,
        "exitCode": 0 if success else 1,
        "results": results,
    }


def main() -> int:
    try:
        message = read_message()
        if message is None:
            return 0

        send_message(handle_message(message))
        return 0
    except Exception:
        send_message(
            {
                "ok": False,
                "error": "Native host crashed.",
                "traceback": traceback.format_exc(),
                "host": HOST_NAME,
            }
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
