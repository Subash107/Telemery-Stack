#!/usr/bin/env python3
"""Reusable URL checking logic shared by the script and extension host."""

from __future__ import annotations

from collections.abc import Sequence
import ssl
import sys
from urllib.parse import urlparse
import urllib.error
import urllib.request
import webbrowser

sys.dont_write_bytecode = True

DEFAULT_URLS = [
    "https://example.com",
    "https://example.org",
]
DEFAULT_PROXY_URL = "http://192.168.1.6:8082"
TIMEOUT_SECONDS = 10
USER_AGENT = "SimplePythonUrlConnector/1.0"


def emit(message: str) -> None:
    """Write output only when a console stream is available."""
    if sys.stdout is None:
        return

    try:
        print(message)
    except OSError:
        # Windowed/no-console builds may not have a writable stdout stream.
        return


def normalize_proxy_url(proxy_url: str | None) -> str:
    candidate = (proxy_url or DEFAULT_PROXY_URL).strip()
    parsed = urlparse(candidate)

    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(
            "Proxy URL must look like http://192.168.1.6:8082 or https://host:port"
        )

    return candidate


def build_proxy_opener(proxy_url: str) -> urllib.request.OpenerDirector:
    proxy_handler = urllib.request.ProxyHandler(
        {
            "http": proxy_url,
            "https": proxy_url,
        }
    )
    return urllib.request.build_opener(proxy_handler)


def format_proxy_error(url: str, proxy_url: str, exc: Exception) -> str:
    reason = getattr(exc, "reason", exc)
    details = str(reason or exc)

    if isinstance(reason, ssl.SSLCertVerificationError) or "CERTIFICATE_VERIFY_FAILED" in details:
        return (
            f"[ERROR] {url} -> HTTPS certificate verification failed through proxy {proxy_url}. "
            "Install the mitmproxy CA certificate in Windows/Python trust stores."
        )

    return f"[ERROR] {url} via {proxy_url} -> {exc}"


def check_url(url: str, proxy_url: str) -> tuple[bool, str]:
    opener = build_proxy_opener(proxy_url)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with opener.open(request, timeout=TIMEOUT_SECONDS) as response:
            return True, f"[OK] {url} via {proxy_url} -> HTTP {response.status}"
    except urllib.error.URLError as exc:
        return False, format_proxy_error(url, proxy_url, exc)


def run_checks(urls: Sequence[str], proxy_url: str | None = None) -> tuple[bool, list[str], str]:
    resolved_proxy_url = normalize_proxy_url(proxy_url)
    results: list[str] = [f"[PROXY] Using {resolved_proxy_url}"]
    overall_success = True

    for url in urls:
        success, message = check_url(url, resolved_proxy_url)
        results.append(message)
        overall_success = overall_success and success

    return overall_success, results, resolved_proxy_url


def open_second_url(urls: Sequence[str]) -> tuple[bool, str]:
    second_url = urls[1]
    opened = webbrowser.open(second_url, new=2)

    if opened:
        return True, f"[OPENED] {second_url} -> Opened automatically in your browser"

    return False, f"[ERROR] {second_url} -> Could not open automatically in your browser"


def run_checks_and_open_second_url(
    urls: Sequence[str], proxy_url: str | None = None
) -> tuple[bool, list[str], str]:
    success, results, resolved_proxy_url = run_checks(urls, proxy_url)
    opened, open_message = open_second_url(urls)
    results.append(open_message)
    return success and opened, results, resolved_proxy_url


def main(argv: Sequence[str] | None = None) -> int:
    raw_args = list(argv if argv is not None else sys.argv[1:])
    proxy_url = DEFAULT_PROXY_URL
    args = raw_args

    if len(raw_args) >= 2 and raw_args[0] == "--proxy-url":
        proxy_url = raw_args[1]
        args = raw_args[2:]

    urls = args if args else list(DEFAULT_URLS)

    if len(urls) != 2:
        emit('Usage: python "New Text Document.pyw" [--proxy-url http://192.168.1.6:8082] <url1> <url2>')
        emit("Or edit DEFAULT_URLS and DEFAULT_PROXY_URL inside url_checker.pyw.")
        return 1

    try:
        success, results, _ = run_checks_and_open_second_url(urls, proxy_url)
    except ValueError as exc:
        emit(f"[ERROR] {exc}")
        return 1

    for line in results:
        emit(line)

    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
