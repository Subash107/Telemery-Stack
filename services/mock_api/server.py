"""Serve the repo-owned mock API over HTTP and gRPC."""

from __future__ import annotations

import argparse
from concurrent import futures
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import pathlib
import signal
import sys
import threading
from typing import Any
from urllib.parse import parse_qs, urlsplit

import grpc
from grpc_health.v1 import health, health_pb2, health_pb2_grpc
from grpc_reflection.v1alpha import reflection

from services.mock_api.app import (
    AuthenticationError,
    MockAPIError,
    MockAPISettings,
    MockSixAPIApplication,
    ValidationError,
    normalize_base_path,
)

GENERATED_DIR = pathlib.Path(__file__).resolve().parent / "generated"
if str(GENERATED_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATED_DIR))

import bbp_mock_api_pb2 as pb2  # noqa: E402
import bbp_mock_api_pb2_grpc as pb2_grpc  # noqa: E402


class MockHTTPServer(ThreadingHTTPServer):
    """HTTP compatibility server that exposes the existing shell endpoints."""

    daemon_threads = True

    def __init__(
        self,
        server_address: tuple[str, int],
        request_handler: type[BaseHTTPRequestHandler],
        *,
        app: MockSixAPIApplication,
        base_path: str,
    ) -> None:
        super().__init__(server_address, request_handler)
        self.app = app
        self.base_path = normalize_base_path(base_path)


class MockHTTPRequestHandler(BaseHTTPRequestHandler):
    """Small JSON/HTTP adapter for the shared application layer."""

    server_version = "MockSixAPIHTTP/1.0"

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        if parsed.path in self._route_aliases(""):
            self._send_json(HTTPStatus.OK, self._routes_payload())
            return

        if parsed.path in self._route_aliases("/health"):
            self._send_json(HTTPStatus.OK, self.server.app.health_payload())  # type: ignore[attr-defined]
            return

        if parsed.path in self._route_aliases("/routes"):
            self._send_json(HTTPStatus.OK, self._routes_payload())
            return

        self._send_error(HTTPStatus.NOT_FOUND, "Unknown endpoint.")

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        if parsed.path != self._route("/login"):
            self._send_error(HTTPStatus.NOT_FOUND, "Unknown endpoint.")
            return

        try:
            payload = self._read_json_body()
            response = self.server.app.login(  # type: ignore[attr-defined]
                username=str(payload.get("username", "")),
                password=str(payload.get("password", "")),
            )
        except AuthenticationError as exc:
            self._send_error(HTTPStatus.UNAUTHORIZED, str(exc))
            return
        except ValidationError as exc:
            self._send_error(HTTPStatus.BAD_REQUEST, str(exc))
            return

        self._send_json(HTTPStatus.OK, response)

    def do_PUT(self) -> None:  # noqa: N802
        parsed = urlsplit(self.path)
        if parsed.path != self._route("/upload"):
            self._send_error(HTTPStatus.NOT_FOUND, "Unknown endpoint.")
            return

        query = parse_qs(parsed.query)
        archive = self._read_binary_body()

        try:
            response = self.server.app.upload_archive(  # type: ignore[attr-defined]
                program=self._query_value(query, "program"),
                filename=self._query_value(query, "filename"),
                archive=archive,
                expected_sha256=self._query_value(query, "sha256", required=False),
                authorization=self.headers.get("Authorization"),
            )
        except AuthenticationError as exc:
            self._send_error(HTTPStatus.UNAUTHORIZED, str(exc))
            return
        except ValidationError as exc:
            self._send_error(HTTPStatus.BAD_REQUEST, str(exc))
            return

        self._send_json(HTTPStatus.OK, response)

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        message = format % args
        sys.stderr.write(f"[mock-api:http] {self.client_address[0]} - {message}\n")

    def _route(self, suffix: str) -> str:
        base_path = self.server.base_path  # type: ignore[attr-defined]
        return f"{base_path}{suffix}" if base_path else suffix

    def _route_aliases(self, suffix: str) -> set[str]:
        route = self._route(suffix)
        aliases = {route}
        if suffix == "":
            aliases.add(route.rstrip("/") or "/")
        else:
            aliases.add(route.rstrip("/"))
        return {alias for alias in aliases if alias}

    def _routes_payload(self) -> dict[str, Any]:
        health_payload = self.server.app.health_payload()  # type: ignore[attr-defined]
        base_path = self.server.base_path  # type: ignore[attr-defined]
        return {
            "service": "mock-six-api",
            "http_base_path": base_path,
            "http_endpoints": [
                {
                    "method": "GET",
                    "path": base_path,
                    "description": "List the available HTTP and gRPC surfaces.",
                },
                {
                    "method": "GET",
                    "path": self._route("/routes"),
                    "description": "List the available HTTP and gRPC surfaces.",
                },
                {
                    "method": "GET",
                    "path": self._route("/health"),
                    "description": "Return service health and transport metadata.",
                },
                {
                    "method": "POST",
                    "path": self._route("/login"),
                    "description": "Obtain a bearer token using the mock credentials.",
                },
                {
                    "method": "PUT",
                    "path": self._route("/upload?program=<name>&filename=<file>&sha256=<optional>"),
                    "description": "Upload an archive with Authorization: Bearer <token>.",
                },
            ],
            "grpc_address": health_payload["grpc_address"],
            "grpc_services": [
                "bbp.mockapi.v1.MockSixAPI",
                "grpc.health.v1.Health",
                "grpc.reflection.v1alpha.ServerReflection",
            ],
        }

    def _query_value(
        self,
        query: dict[str, list[str]],
        key: str,
        *,
        required: bool = True,
    ) -> str:
        values = query.get(key, [])
        if values:
            return values[0]
        if required:
            raise ValidationError(f"{key} query parameter is required.")
        return ""

    def _read_json_body(self) -> dict[str, Any]:
        raw_body = self._read_binary_body()
        if not raw_body:
            raise ValidationError("Request body is empty.")

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValidationError(f"Invalid JSON body: {exc}") from exc

        if not isinstance(payload, dict):
            raise ValidationError("JSON body must be an object.")

        return payload

    def _read_binary_body(self) -> bytes:
        content_length_header = self.headers.get("Content-Length")
        if not content_length_header:
            return b""

        try:
            content_length = int(content_length_header)
        except ValueError as exc:
            raise ValidationError("Invalid Content-Length header.") from exc

        return self.rfile.read(content_length)

    def _send_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, status: HTTPStatus, message: str) -> None:
        self._send_json(status, {"error": message})


class MockSixAPIServicer(pb2_grpc.MockSixAPIServicer):
    """gRPC transport adapter around the shared application layer."""

    def __init__(self, app: MockSixAPIApplication) -> None:
        self._app = app

    def Health(self, request: pb2.HealthRequest, context: grpc.ServicerContext) -> pb2.HealthResponse:  # noqa: N802
        payload = self._app.health_payload()
        return pb2.HealthResponse(
            status=str(payload["status"]),
            service=str(payload["service"]),
            storage_dir=str(payload["storage_dir"]),
            transports=list(payload["transports"]),
            http_base_path=str(payload["http_base_path"]),
            grpc_address=str(payload["grpc_address"]),
        )

    def Login(self, request: pb2.LoginRequest, context: grpc.ServicerContext) -> pb2.LoginResponse:  # noqa: N802
        try:
            response = self._app.login(request.username, request.password)
        except AuthenticationError as exc:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, str(exc))

        return pb2.LoginResponse(
            access_token=response["access_token"],
            token_type=response["token_type"],
        )

    def UploadArchive(  # noqa: N802
        self,
        request: pb2.UploadArchiveRequest,
        context: grpc.ServicerContext,
    ) -> pb2.UploadArchiveResponse:
        metadata = {key.lower(): value for key, value in context.invocation_metadata()}
        authorization = metadata.get("authorization")
        if not authorization and metadata.get("access-token"):
            authorization = f"Bearer {metadata['access-token']}"

        try:
            response = self._app.upload_archive(
                program=request.program,
                filename=request.filename,
                archive=request.archive,
                expected_sha256=request.sha256,
                authorization=authorization,
            )
        except AuthenticationError as exc:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, str(exc))
        except ValidationError as exc:
            context.abort(grpc.StatusCode.INVALID_ARGUMENT, str(exc))

        return pb2.UploadArchiveResponse(
            message=str(response["message"]),
            program=str(response["program"]),
            filename=str(response["filename"]),
            bytes_written=int(response["bytes_written"]),
            sha256=str(response["sha256"]),
            saved_to=str(response["saved_to"]),
        )


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the repo-owned mock SIX-style API.")
    parser.add_argument("--host", default="127.0.0.1", help="HTTP bind host.")
    parser.add_argument("--port", default=18080, type=int, help="HTTP bind port.")
    parser.add_argument("--base-path", default="/mock-six-api", help="HTTP API base path.")
    parser.add_argument("--grpc-host", default="127.0.0.1", help="gRPC bind host.")
    parser.add_argument("--grpc-port", default=50061, type=int, help="gRPC bind port. Use 0 to disable gRPC.")
    parser.add_argument("--storage-dir", required=True, help="Directory used to store uploaded archives.")
    parser.add_argument("--username", required=True, help="Mock API username.")
    parser.add_argument("--password", required=True, help="Mock API password.")
    return parser


def start_http_server(settings: MockAPISettings, app: MockSixAPIApplication) -> tuple[MockHTTPServer, threading.Thread]:
    server = MockHTTPServer(
        (settings.http_host, settings.http_port),
        MockHTTPRequestHandler,
        app=app,
        base_path=settings.http_base_path,
    )

    thread = threading.Thread(target=server.serve_forever, name="mock-api-http", daemon=True)
    thread.start()
    return server, thread


def start_grpc_server(settings: MockAPISettings, app: MockSixAPIApplication) -> grpc.Server | None:
    if settings.grpc_port == 0:
        return None

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb2_grpc.add_MockSixAPIServicer_to_server(MockSixAPIServicer(app), server)

    health_servicer = health.HealthServicer()
    health_servicer.set("", health_pb2.HealthCheckResponse.SERVING)
    health_servicer.set("bbp.mockapi.v1.MockSixAPI", health_pb2.HealthCheckResponse.SERVING)
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)

    service_names = (
        "bbp.mockapi.v1.MockSixAPI",
        health_pb2.DESCRIPTOR.services_by_name["Health"].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(service_names, server)

    bound_port = server.add_insecure_port(settings.grpc_address)
    if bound_port == 0:
        raise RuntimeError(f"Unable to bind gRPC server to {settings.grpc_address}.")

    server.start()
    return server


def run(settings: MockAPISettings) -> int:
    app = MockSixAPIApplication(settings)
    http_server, http_thread = start_http_server(settings, app)
    grpc_server = start_grpc_server(settings, app)
    stop_event = threading.Event()

    def _request_stop(signum: int, frame: Any) -> None:
        del frame
        print(f"Received signal {signum}, shutting down mock API.", flush=True)
        stop_event.set()

    for signum_name in ("SIGINT", "SIGTERM"):
        signum = getattr(signal, signum_name, None)
        if signum is not None:
            signal.signal(signum, _request_stop)

    http_url = f"http://{settings.http_host}:{settings.http_port}{settings.http_base_path or '/'}"
    print(f"Mock HTTP API listening on {http_url}", flush=True)
    if grpc_server is not None:
        print(f"Mock gRPC API listening on {settings.grpc_address}", flush=True)
    else:
        print("Mock gRPC API disabled.", flush=True)

    try:
        stop_event.wait()
    except KeyboardInterrupt:
        stop_event.set()
    finally:
        if grpc_server is not None:
            grpc_server.stop(grace=2).wait(2)
        http_server.shutdown()
        http_thread.join(timeout=2)
        http_server.server_close()

    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_argument_parser()
    args = parser.parse_args(argv)

    settings = MockAPISettings(
        http_host=args.host,
        http_port=args.port,
        http_base_path=normalize_base_path(args.base_path),
        grpc_host=args.grpc_host,
        grpc_port=args.grpc_port,
        storage_dir=pathlib.Path(args.storage_dir).resolve(),
        username=args.username,
        password=args.password,
    )

    return run(settings)


if __name__ == "__main__":
    raise SystemExit(main())
