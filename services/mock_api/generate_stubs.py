#!/usr/bin/env python3
"""Generate Python gRPC stubs for the repo-owned mock API."""

from __future__ import annotations

import pathlib
import sys

from grpc_tools import protoc


def main() -> int:
    service_dir = pathlib.Path(__file__).resolve().parent
    project_root = service_dir.parent.parent
    proto_path = project_root / "proto" / "bbp_mock_api.proto"
    output_dir = service_dir / "generated"
    output_dir.mkdir(parents=True, exist_ok=True)

    command = [
        "grpc_tools.protoc",
        f"-I{proto_path.parent}",
        f"--python_out={output_dir}",
        f"--grpc_python_out={output_dir}",
        str(proto_path),
    ]

    result = protoc.main(command)
    if result != 0:
        return result

    return 0


if __name__ == "__main__":
    sys.exit(main())
