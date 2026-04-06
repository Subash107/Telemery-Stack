# Local VM Helpers

This directory contains helper tools that are useful for your personal Kali VM setup,
but are not part of the core project pipeline.

Active contents:

- `Finalscriptkalisubash.py`: Windows-side SSH launcher used by the interactive helpers
- `PROJECT_DEBUG_GUIDE.md`: quick map of which helper to use for which task
- `helper_menu.bat`: one-window launcher menu for the active helper actions
- `helper_menu.py`: implementation behind the helper menu
- helper menu shortcut `W`: opens the workflow and submission PDF directly
- helper menu shortcut `S`: opens `results/secure-test.six-swiss-exchange.com/reports`
- `start_project_dockers.bat`: starts the repo Docker stacks on Windows and prints the key URLs
- `start_manual_testing.bat`: creates a fresh report, opens notes and report files, and launches Kali SSH
- `start_manual_testing.py`: implementation behind the manual testing launcher
- `pick_manual_target.bat`: lets you choose from existing `results/` workspaces and then starts a manual testing session
- `pick_manual_target.py`: implementation behind the workspace picker
- `new_manual_report.bat`: creates a fresh ready-to-fill manual bounty report in `results/<target>/reports/`
- `create_manual_report.py`: the report generator used by `new_manual_report.bat`
- `project_debug_report_kali.bat`: Windows launcher for the Python-based Kali debug reporter
- `project_debug_report_kali.py`: generates a single read-only report covering MQTT, API routes,
  TLS certificate details, CIDR checks, DNS, PTR lookups, ports, and saved response artifacts
- `open_kali_ssh.bat`: opens an interactive SSH shell to the Kali VM
- `telemetry_debug_kali.bat`: telemetry-focused report launcher for the Kali VM stack
- `public_tls_sample_check.bat`: public HTTPS certificate and handshake helper
- `tls_test_kali.bat`: MQTT/TLS validation helper for the Kali VM
- `reports/`: saved output from the helper launchers
- `legacy/`: archived older or off-project helpers that are no longer part of the main workflow

These files are intentionally separated from `scripts/core/` so it is clearer which
scripts belong to the repository workflow and which scripts are just local operator
tooling for your Kali environment.

## Local Secret Handling

Keep live VM and broker secrets out of source control.

- `Finalscriptkalisubash.py` and `project_debug_report_kali.py` will use the local `KALI_VM_PASSWORD` environment variable or prompt securely at runtime.
- `telemetry_debug_kali.bat` reads `KALI_MQTT_USERNAME` and `KALI_MQTT_PASSWORD` from your local environment for optional live probes.
- `credentials-and-links.local.md` is the local-only inventory for sensitive values and should remain unshared.
