# Mock API Service

This directory contains the repo-owned mock SIX-style API implementation.

## Layout

- `../../proto/bbp_mock_api.proto`: source-of-truth service contract
- `generated/`: checked-in Python protobuf and gRPC stubs generated from the proto
- `app.py`: shared business logic used by both transports
- `server.py`: HTTP compatibility server plus gRPC server
- `client.py`: simple gRPC client for manual testing
- `generate_stubs.py`: regenerate the checked-in stubs after editing the proto

## Why Both HTTP And gRPC

The existing shell pipeline still talks to the mock API over HTTP with `curl`.
This service keeps that compatibility layer so `scripts/run.sh` and
`scripts/start_mock_api.sh` do not need a full rewrite.

At the same time, the repo now has a real gRPC contract and generated code, so
future internal services can talk to the same mock API through typed RPC calls.

## Local Dev

Install dependencies:

```bash
python -m pip install -r services/mock_api/requirements.txt
```

Regenerate stubs after editing `proto/bbp_mock_api.proto`:

```bash
python services/mock_api/generate_stubs.py
```

Start the service through the stable wrapper:

```bash
bash scripts/start_mock_api.sh
```

That starts:

- HTTP on `127.0.0.1:18080/mock-six-api`
- gRPC on `127.0.0.1:50061`

## gRPC Smoke Examples

Health:

```bash
python services/mock_api/client.py --target 127.0.0.1:50061 health
```

Login:

```bash
python services/mock_api/client.py --target 127.0.0.1:50061 login --username mock-user --password mock-pass
```
