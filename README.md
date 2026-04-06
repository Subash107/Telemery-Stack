# BBP Final Pro Framework

This project now supports two workflows:

- manual bug bounty preparation for a single scoped host
- local simulation with a mock SIX-style API when you explicitly opt into it

The default profile is now the safer manual workflow for `https://secure-test.six-swiss-exchange.com/`.

## Scripts Layout

The `scripts/` directory is now split into two parts:

- `scripts/core/`: the actual project pipeline implementation
- `scripts/local-vm-helpers/`: Windows/Kali helper launchers and their reports

For compatibility, the documented entrypoints still work from the top-level
`scripts/` directory. For example, `bash scripts/run.sh` and `bash scripts/start_mock_api.sh`
still forward to the files in `scripts/core/`.

## Manual Quick Start

1. Copy `.env.example` to `.env`.
2. Keep `WORKFLOW_MODE=manual`.
3. Run:

```bash
bash scripts/run.sh
```

This creates `results/secure-test.six-swiss-exchange.com/` with:

- `scope-summary.md`
- `burp-setup.md`
- `manual-notes.md`
- `finding-draft.md`
- `gitbash-helpers.sh`
- `seed-urls.txt`
- `requests/`, `evidence/`, and `reports/` folders

Then in Git Bash:

```bash
source results/secure-test.six-swiss-exchange.com/gitbash-helpers.sh
bbp_curl "$BBP_ENTRY_URL"
```

That helper sends a single proxied request through Burp using a `User-Agent` that already includes `bugbounty`.

Program reminders captured in the workspace:

- manual traffic only
- no automated scans
- use only your own or issued accounts
- stop if you hit PII
- no brute force, degradation, or post-exploitation

Target-specific notes are stored in:

- `targets/secure-test.six-swiss-exchange.com/program-guidelines.md`
- `targets/secure-test.six-swiss-exchange.com/seed-urls.txt`

## Simulation Quick Start

If you want the old mock API flow, set `WORKFLOW_MODE=simulation` in `.env`, then:

1. Set local-only credentials in `.env`.
2. Start the mock API:

```bash
bash scripts/start_mock_api.sh
```

3. In a second terminal, run:

```bash
bash scripts/run.sh
```

In simulation mode the workflow will:

- create/update `database/findings.db`
- generate per-target result folders under `results/`
- package each target folder into `artifacts/*.zip`
- upload those ZIP files to the mock API when `ENABLE_API_SYNC=true`

Uploaded archives are written locally under `mock_api_uploads/` by the mock server.

The repo now owns the mock API contract and Python service implementation:

- `proto/bbp_mock_api.proto`: source-of-truth service contract
- `services/mock_api/generated/`: generated Python protobuf + gRPC stubs
- `services/mock_api/server.py`: shared HTTP + gRPC server
- `services/mock_api/client.py`: small gRPC client for local testing

When you start the mock API through `bash scripts/start_mock_api.sh`, it now serves:

- HTTP compatibility endpoints on `http://localhost:18080/mock-six-api`
- gRPC on `127.0.0.1:50061` by default

You can regenerate the checked-in stubs after editing the proto with:

```bash
python -m pip install -r services/mock_api/requirements.txt
python services/mock_api/generate_stubs.py
```

## Environment Switching

Default manual preparation uses `.env` with:

```env
ENV=dev
WORKFLOW_MODE=manual
TARGET_SCHEME=https
TARGET_ENTRY_PATH=/member_section/
BURP_PROXY=http://127.0.0.1:8080
BUGBOUNTY_USER_AGENT=Mozilla/5.0 (...) bugbounty
MANUAL_RESULTS_DIR=results
```

If you switch to simulation or production-like runs, keep a separate local-only file such as `.env.prod` based on `.env.prod.example`, then run:

```bash
ENV=prod bash scripts/run.sh
```

The loader prefers `.env.prod` when `ENV=prod`, otherwise it falls back to `.env`.

With `API_URL=auto`, the config resolves the endpoint like this:

- normal host run: `http://localhost:18080/mock-six-api`
- Docker/container run: `http://host.docker.internal:18080/mock-six-api`
- native Linux Docker fallback: uses the container's default gateway when `host.docker.internal` is unavailable

Useful overrides:

- `API_RUNTIME_CONTEXT=docker`: force Docker-style resolution even if auto-detect is unavailable
- `API_HOST=my-api.internal`: bypass auto resolution and use a fixed hostname
- `MOCK_API_BIND_HOST=0.0.0.0`: lets containers reach the host mock API more reliably

If you run a Linux container and `host.docker.internal` is not present, you can also start the container with:

```bash
docker run --add-host host.docker.internal:host-gateway ...
```

## Secret Handling

Do not commit real credentials.

- Local development: keep secrets in `.env` or `.env.prod`
- Windows/Kali helper credentials: keep `KALI_VM_PASSWORD`, `KALI_MQTT_USERNAME`, and `KALI_MQTT_PASSWORD` in your local environment only
- GitHub Actions: store them in `MOCK_API_USERNAME` / `MOCK_API_PASSWORD`
- Advanced setups: map `API_USERNAME` / `API_PASSWORD` from Vault or another secret manager before running the scripts

## Docker Compose

The Compose setup is optional and dev-only. It does not change the normal local workflow, your target files, or the production example config.

Files:

- `docker-compose.yml`: runs the mock API and the pipeline together
- `Dockerfile.devops`: small shared image with Bash, curl, and Python
- `.dockerignore`: keeps secrets and generated artifacts out of the build context

Recommended commands:

```bash
docker compose up --build mock-api
```

This starts only the mock API and exposes it on `http://localhost:18080/mock-six-api`.
It also exposes the gRPC endpoint on `localhost:50061` by default.

```bash
docker compose run --rm pipeline
```

This runs the pipeline in a container against the Compose mock API service.

If you want both services started together in one go:

```bash
docker compose up --build
```

Compose safety defaults:

- forces `ENV=dev`
- points `API_URL` to the internal `mock-api` service, not production
- uses mock-only credentials by default: `mock-user` / `mock-pass`
- writes outputs back into the current workspace through the bind mount

Optional overrides:

```bash
COMPOSE_MOCK_API_USERNAME=my-mock-user COMPOSE_MOCK_API_PASSWORD=my-mock-pass docker compose up --build
```

If `18080` is busy on your host, change only the exposed host port:

```bash
COMPOSE_MOCK_API_PORT=28080 docker compose up --build mock-api
```

If `50061` is busy too, override the exposed gRPC port separately:

```bash
COMPOSE_MOCK_API_GRPC_PORT=25061 docker compose up --build mock-api
```

Compose-specific overrides intentionally use their own names so your regular `.env` does not change this dev-only flow. The most useful ones are:

- `COMPOSE_MOCK_API_USERNAME`
- `COMPOSE_MOCK_API_PASSWORD`
- `COMPOSE_TARGETS_FILE`
- `COMPOSE_RESULTS_DIR`
- `COMPOSE_ARTIFACTS_DIR`
- `COMPOSE_DB_PATH`
- `COMPOSE_ENABLE_API_SYNC`
- `COMPOSE_MOCK_API_GRPC_PORT`

## Observability

A separate repo-managed stack now lives under `ops/observability/` for the Kali
lab. It adds:

- `Prometheus`
- `Alertmanager`
- `Grafana`
- `blackbox_exporter`
- `node_exporter`
- `cAdvisor`

Start it from the repo root with:

```bash
docker compose -f ops/observability/docker-compose.yml up -d
```

If you want to change ports, admin credentials, or image tags first:

```bash
cp ops/observability/.env.example ops/observability/.env
docker compose --env-file ops/observability/.env -f ops/observability/docker-compose.yml up -d
```

The Prometheus target list is version-controlled in:

- `ops/observability/prometheus/targets/service-probes.yml`

That file already includes the current Kali VM checks for:

- `192.168.1.22`
- SSH on `:22`
- gRPC demo services on `:50051`, `:50052`, `:50061`, and `:50062`

For BBP simulation runs, the pipeline can now write a Prometheus textfile
snapshot into `ops/observability/data/node-exporter/textfile/` so Grafana can
show the last run status, duration, target count, archive count, and upload
failures. See `ops/observability/README.md` for the exact command.

## Kubernetes

A repo-managed Kubernetes layout now lives under `ops/kubernetes/`.

It includes:

- a `Deployment` for the mock API
- a `Service` exposing HTTP and gRPC
- a batch `Job` for the simulation pipeline
- a local `kind` cluster config and a Kustomize overlay

The local dev workflow is:

```bash
docker compose -f docker-compose.yml build
kind create cluster --config ops/kubernetes/kind/cluster.yaml
kind load docker-image bbp_final_pro_framework-mock-api:latest --name bbp-dev
kind load docker-image bbp_final_pro_framework-pipeline:latest --name bbp-dev
kubectl apply -k ops/kubernetes/overlays/kind
```

See `ops/kubernetes/README.md` for the full workflow and host access ports.

For the Kali VM, use the `k3s` overlay instead:

```bash
kubectl apply -k ops/kubernetes/overlays/k3s
```

## GitHub Actions

An example workflow is included at `.github/workflows/devops-simulation.yml`.

For private or customized runs, add these repository secrets:

- `MOCK_API_USERNAME`
- `MOCK_API_PASSWORD`

If those secrets are not set, the example workflow now falls back to the mock-only
demo credentials `mock-user` / `mock-pass` so the public repo can still run the
local simulation safely.

## Key Scripts

- `scripts/run.sh`: stable entrypoint for the main pipeline
- `scripts/core/prepare_manual_scope.sh`: creates the manual testing workspace
- `scripts/start_mock_api.sh`: stable entrypoint for the local mock API launcher
- `scripts/core/package_results.sh`: creates ZIP archives safely
- `scripts/core/upload_results.sh`: uploads an archive using the configured API
- `scripts/core/python_db.py`: portable SQLite operations via Python
- `scripts/local-vm-helpers/`: local Windows/Kali helper launchers and saved reports
- `services/mock_api/`: repo-owned mock API contract, generated stubs, and transport code
