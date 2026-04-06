# Core Scripts

This directory contains the implementation for the bug bounty workspace pipeline.

Key files:

- `run.sh`: main workflow entrypoint
- `prepare_manual_scope.sh`: builds the manual-only workspace
- `start_mock_api.sh`: starts the local simulation server
- `mock_six_api.py`: compatibility wrapper into the repo-owned mock API service
- `package_results.sh`: zips result folders into `artifacts/`
- `upload_results.sh`: uploads ZIP artifacts to the configured API
- `write_pipeline_metrics.sh`: writes the latest simulation run snapshot in
  Prometheus textfile format
- `python_db.py`: SQLite helper used by `init_db.sh` and `db_insert.sh`
- `lib/config.sh`: environment loading and path/config helpers
- `lib/api_client.sh`: curl-based mock API client

Notes:

- The top-level wrappers in `scripts/` forward here.
- `start_mock_api.sh` now launches the repo-owned implementation under
  `services/mock_api/` through `mock_six_api.py`.
