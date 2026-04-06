# Project Debug Guide

Use this folder as your Windows-side control panel for the repo and the Kali VM.

## Open The Helper Menu

Run:

```bat
helper_menu.bat
```

This shows the active helper actions in one console window and lets you launch them by number.

Use menu option `W` to open the workflow and submission PDF directly.
Use menu option `S` to open the exact secure-test report samples folder directly.

## Start A Manual Testing Session

Run:

```bat
start_manual_testing.bat
```

This will:

- create a fresh report draft
- open `manual-notes.md`
- open the new report file
- open a new Kali SSH window

Optional unattended example:

```bat
start_manual_testing.bat --host 192.168.1.22 --target secure-test.six-swiss-exchange.com --title stored-xss-profile --entry-url https://secure-test.six-swiss-exchange.com/member_section/profile --no-prompt
```

## Pick A Target From Existing Workspaces

Run:

```bat
pick_manual_target.bat
```

This reads your existing folders in `results/`, lets you choose one, and then:

- creates a fresh report draft for that target
- opens `manual-notes.md`
- opens the new report file
- opens a new Kali SSH window

Optional unattended example:

```bat
pick_manual_target.bat --workspace secure-test.six-swiss-exchange.com --host 192.168.1.22 --title idor-profile --no-prompt
```

## Create A Fresh Manual Report

Run:

```bat
new_manual_report.bat
```

Optional unattended mode:

```bat
new_manual_report.bat --target secure-test.six-swiss-exchange.com --title stored-xss-profile --entry-url https://secure-test.six-swiss-exchange.com/member_section/profile --no-prompt
```

This creates:

- a ready-to-fill report in `results/<target>/reports/`
- a matching evidence folder
- a matching requests folder

## Start The Local Repo Stacks

Run:

```bat
start_project_dockers.bat
```

This starts:

- the repo mock API stack from `docker-compose.yml`
- the repo observability stack from `ops/observability/docker-compose.yml`

Key local URLs:

- Mock API routes: `http://127.0.0.1:18080/mock-six-api/routes`
- Mock API health: `http://127.0.0.1:18080/mock-six-api/health`
- gRPC reflection: `grpcurl -plaintext 127.0.0.1:50061 list`
- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`
- Alertmanager: `http://127.0.0.1:9093`
- blackbox_exporter: `http://127.0.0.1:9115`
- cAdvisor: `http://127.0.0.1:8080`

## Generate One Full Kali Debug Report

Run:

```bat
project_debug_report_kali.bat
```

Optional unattended mode:

```bat
project_debug_report_kali.bat --no-prompt
```

This writes a report into `reports\project_debug_YYYYMMDD_HHMMSS.txt` with:

- host summary
- Docker containers
- important listening ports
- mock API and gRPC listing
- MQTT dashboard data and metrics
- Prometheus targets
- DNS lookup
- reverse PTR lookup
- CIDR membership check
- TLS certificate summary
- target port check
- saved response and upload receipt locations

## MQTT And Telemetry

Use:

```bat
telemetry_debug_kali.bat
```

Where to look:

- dashboard UI: `http://192.168.1.22:5000`
- collected MQTT data feed: `http://192.168.1.22:5000/data`
- app metrics: `http://192.168.1.22:8000/metrics`
- Prometheus on Kali: `http://192.168.1.22:9090`
- Grafana on Kali: `http://192.168.1.22:3000`

## TLS And Certificates

Use:

- `tls_test_kali.bat` for MQTT/TLS validation on Kali
- `public_tls_sample_check.bat` for public HTTPS certificate checks
- `project_debug_report_kali.bat` for a quick certificate summary

## Ports

Use:

- `project_debug_report_kali.bat` for the normal combined port view
- `open_kali_ssh.bat` if you want to run a custom `ss` or `nmap` command manually

## DNS, PTR, CIDR, And Target Checks

Use:

```bat
project_debug_report_kali.bat
```

That is the main entry point for:

- hostname resolution
- A and AAAA records
- reverse PTR lookup
- CIDR membership testing
- HTTPS response headers
- quick target port checks

## Direct Access Helpers

Use:

- `open_kali_ssh.bat` to get an interactive SSH shell on the Kali VM

## Archived Helpers

Older overlapping launchers and Cloudflare-specific helpers were moved into `legacy/`
to keep the active helper folder smaller and easier to use.

## Notes

- The Windows repo is your main working copy.
- The Kali VM has its own deployed snapshot and telemetry stack.
- The Kali deployment now exposes the same mock API HTTP `/routes` endpoint as the Windows repo stack, and the gRPC service supports reflection.
