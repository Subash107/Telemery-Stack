"""Small gRPC client for the repo-owned mock API."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import sys

import grpc

GENERATED_DIR = pathlib.Path(__file__).resolve().parent / "generated"
if str(GENERATED_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATED_DIR))

import bbp_mock_api_pb2 as pb2  # noqa: E402
import bbp_mock_api_pb2_grpc as pb2_grpc  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Interact with the repo-owned gRPC mock API.")
    parser.add_argument("--target", default="127.0.0.1:50061", help="gRPC server address.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health", help="Call Health.")

    login = subparsers.add_parser("login", help="Call Login.")
    login.add_argument("--username", required=True)
    login.add_argument("--password", required=True)

    upload = subparsers.add_parser("upload", help="Call UploadArchive.")
    upload.add_argument("--token", required=True)
    upload.add_argument("--program", required=True)
    upload.add_argument("--file", required=True)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    with grpc.insecure_channel(args.target) as channel:
        stub = pb2_grpc.MockSixAPIStub(channel)

        if args.command == "health":
            response = stub.Health(pb2.HealthRequest())
            print(response)
            return 0

        if args.command == "login":
            response = stub.Login(
                pb2.LoginRequest(username=args.username, password=args.password)
            )
            print(response)
            return 0

        if args.command == "upload":
            archive_path = pathlib.Path(args.file).resolve()
            archive = archive_path.read_bytes()
            sha256 = hashlib.sha256(archive).hexdigest()
            response = stub.UploadArchive(
                pb2.UploadArchiveRequest(
                    program=args.program,
                    filename=archive_path.name,
                    sha256=sha256,
                    archive=archive,
                ),
                metadata=(("authorization", f"Bearer {args.token}"),),
            )
            print(response)
            return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
