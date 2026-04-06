# Scripts Layout

This directory is split into two areas:

- `core/`: the actual project pipeline implementation
- `local-vm-helpers/`: Windows/Kali helper launchers and their saved reports

Compatibility entrypoints such as `scripts/run.sh` and `scripts/start_mock_api.sh`
still exist at this level and forward into `scripts/core/` so the documented commands
and CI configuration keep working.

The observability helper `scripts/write_pipeline_metrics.sh` is also available at
this level and forwards into `scripts/core/` when you want to generate a
Prometheus textfile snapshot explicitly.
