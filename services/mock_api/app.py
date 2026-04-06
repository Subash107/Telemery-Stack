"""Shared application logic for the repo-owned mock SIX-style API."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
import secrets
import threading


class MockAPIError(Exception):
    """Base class for mock API validation errors."""


class AuthenticationError(MockAPIError):
    """Raised when credentials or tokens are invalid."""


class ValidationError(MockAPIError):
    """Raised when request data is incomplete or unsafe."""


def normalize_base_path(base_path: str) -> str:
    normalized = "/" + base_path.strip("/")
    return "" if normalized == "/" else normalized


def sanitize_path_segment(value: str, *, fallback: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
    safe = safe.strip("._")
    return safe or fallback


@dataclass(frozen=True)
class MockAPISettings:
    http_host: str
    http_port: int
    http_base_path: str
    grpc_host: str
    grpc_port: int
    storage_dir: Path
    username: str
    password: str

    @property
    def grpc_address(self) -> str:
        return f"{self.grpc_host}:{self.grpc_port}"


class MockSixAPIApplication:
    """Stateful mock API implementation shared by HTTP and gRPC transports."""

    def __init__(self, settings: MockAPISettings) -> None:
        self.settings = settings
        self.settings.storage_dir.mkdir(parents=True, exist_ok=True)
        self._tokens: dict[str, str] = {}
        self._token_lock = threading.Lock()

    def health_payload(self) -> dict[str, object]:
        return {
            "status": "ok",
            "service": "mock-six-api",
            "storage_dir": str(self.settings.storage_dir.resolve()),
            "transports": ["http", "grpc"],
            "http_base_path": self.settings.http_base_path or "/",
            "grpc_address": self.settings.grpc_address,
        }

    def login(self, username: str, password: str) -> dict[str, str]:
        if username != self.settings.username or password != self.settings.password:
            raise AuthenticationError("Invalid credentials.")

        token = secrets.token_urlsafe(24)
        with self._token_lock:
            self._tokens[token] = username

        return {
            "access_token": token,
            "token_type": "Bearer",
        }

    def validate_token(self, authorization: str | None) -> str:
        token = self._extract_bearer_token(authorization)
        if not token:
            raise AuthenticationError("Missing Bearer token.")

        with self._token_lock:
            username = self._tokens.get(token)

        if not username:
            raise AuthenticationError("Invalid or expired token.")

        return username

    def upload_archive(
        self,
        *,
        program: str,
        filename: str,
        archive: bytes,
        expected_sha256: str,
        authorization: str | None,
    ) -> dict[str, object]:
        self.validate_token(authorization)

        program = program.strip()
        if not program:
            raise ValidationError("program is required.")

        raw_filename = filename.strip()
        if not raw_filename:
            raise ValidationError("filename is required.")

        if not archive:
            raise ValidationError("archive payload is empty.")

        actual_sha256 = hashlib.sha256(archive).hexdigest()
        if expected_sha256 and expected_sha256.lower() != actual_sha256:
            raise ValidationError(
                f"sha256 mismatch: expected {expected_sha256.lower()}, got {actual_sha256}."
            )

        program_dir = self.settings.storage_dir / sanitize_path_segment(program, fallback="program")
        program_dir.mkdir(parents=True, exist_ok=True)

        safe_filename = sanitize_path_segment(Path(raw_filename).name, fallback="archive.zip")
        destination = program_dir / safe_filename
        destination.write_bytes(archive)

        return {
            "message": "Archive accepted by mock API",
            "program": program,
            "filename": safe_filename,
            "bytes_written": len(archive),
            "sha256": actual_sha256,
            "saved_to": str(destination.resolve()),
        }

    @staticmethod
    def _extract_bearer_token(authorization: str | None) -> str | None:
        if not authorization:
            return None

        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            return None

        return token.strip()
