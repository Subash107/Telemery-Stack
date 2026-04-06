# Observability Stack

This folder contains a repo-managed observability stack for the Kali lab and the
BBP project. It is meant to run on a Linux host, preferably the Kali VM at
`192.168.1.22`, because `node_exporter` and `cAdvisor` mount Linux host paths.

## What It Includes

- `Prometheus` for metrics collection and alert rule evaluation
- `Alertmanager` with a safe no-op receiver so alerts can be reviewed without
  sending notifications yet
- `Grafana` with provisioned data sources and a starter dashboard
- `blackbox_exporter` for SSH, ICMP, and TCP port probing
- `node_exporter` for Linux host metrics
- `cAdvisor` for Docker container metrics

## Start The Stack

1. Copy `ops/observability/.env.example` to `ops/observability/.env` if you want
   to change ports, credentials, or image versions.
2. Review `ops/observability/prometheus/targets/service-probes.yml` and adjust
   the target IPs or ports if your lab layout changes.
3. Start the stack:

```bash
docker compose --env-file ops/observability/.env -f ops/observability/docker-compose.yml up -d
```

If you prefer the defaults and do not create `.env`, this also works:

```bash
docker compose -f ops/observability/docker-compose.yml up -d
```

## Default Endpoints

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Alertmanager: `http://localhost:9093`
- blackbox_exporter: `http://localhost:9115`
- cAdvisor: `http://localhost:8080`

Default Grafana login:

- Username: `admin`
- Password: `change-me`

## BBP Pipeline Metrics

The main pipeline can now write a Prometheus textfile snapshot after each
simulation run. This is opt-in so the manual workflow stays untouched.

Enable it like this from the repo root:

```bash
ENABLE_PIPELINE_METRICS=true \
PIPELINE_METRICS_DIR=ops/observability/data/node-exporter/textfile \
bash scripts/run.sh
```

The stack mounts `ops/observability/data/node-exporter/textfile` into
`node_exporter`, so Grafana can show:

- last pipeline success/failure
- last run duration
- targets processed
- archives created
- upload attempts and failures

## Probe Notes

`service-probes.yml` ships with your current Kali VM defaults:

- host ICMP probe to `192.168.1.22`
- SSH probe on `192.168.1.22:22`
- TCP checks for the gRPC services on `50051`, `50052`, `50061`, and `50062`

The gRPC ports use TCP probes by default because the current demo services do
not expose the standard gRPC health service yet. Once they do, you can switch
the target `module` values from `tcp_connect` to `grpc_plain` or `grpc_tls`.

SNMP is not directly probed in the default stack because your SNMP service is
UDP-based and needs a dedicated SNMP exporter or custom v3 check to monitor at
the protocol level.
