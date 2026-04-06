# Credentials And Links (Sanitized)

This version is intended for easier sharing or printing.
It keeps the useful links, usernames, paths, and commands, but removes passwords and other secret values.

## Main Repo Paths

- Repo root: `d:\Kali linux\bbp_final_pro_framework`
- Local-only inventory: `d:\Kali linux\bbp_final_pro_framework\credentials-and-links.local.md`
- Helper guide: `d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\PROJECT_DEBUG_GUIDE.md`
- Windows helper folder: `d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers`

## Kali VM Access

- SSH host: `192.168.1.22`
- SSH username: `subash`
- SSH password: stored only in `credentials-and-links.local.md`

Useful commands:

```powershell
kubectl config use-context kali-k3s
kubectl get all -n bbp-dev
kubectl logs -n bbp-dev deployment/bbp-mock-api
kubectl logs -n bbp-dev job/bbp-pipeline-simulation
```

## Kubernetes Contexts

- Windows contexts:
  - `kali-k3s`
  - `kind-bbp-dev`
- Windows kubeconfig: `C:\Users\Lamas\.kube\config`
- Kali kubeconfig: `/home/subash/.kube/config`

## Local Repo Stack

- Mock API routes: `http://127.0.0.1:18080/mock-six-api/routes`
- Mock API health: `http://127.0.0.1:18080/mock-six-api/health`
- gRPC endpoint: `127.0.0.1:50061`
- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`
- Alertmanager: `http://127.0.0.1:9093`
- blackbox_exporter: `http://127.0.0.1:9115`
- cAdvisor: `http://127.0.0.1:8080`

Local Grafana login:

- Username: `admin`
- Password: stored only in `credentials-and-links.local.md`

Mock API login:

- Username: `mock-user`
- Password: stored only in `credentials-and-links.local.md`

Login example:

```powershell
$body = @{ username='mock-user'; password='<stored-locally>' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18080/mock-six-api/login' -ContentType 'application/json' -Body $body
```

## Kali k3s Deployment

- HTTP routes: `http://192.168.1.22:30080/mock-six-api/routes`
- HTTP health: `http://192.168.1.22:30080/mock-six-api/health`
- gRPC endpoint: `192.168.1.22:30061`
- gRPC list command: `grpcurl -plaintext 192.168.1.22:30061 list`

Mock API login:

- Username: `mock-user`
- Password: stored only in `credentials-and-links.local.md`

Login example:

```powershell
$body = @{ username='mock-user'; password='<stored-locally>' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'http://192.168.1.22:30080/mock-six-api/login' -ContentType 'application/json' -Body $body
```

## Kali Telemetry Stack

- MQTT dashboard: `http://192.168.1.22:5000`
- MQTT collected data: `http://192.168.1.22:5000/data`
- MQTT/Kafka app metrics: `http://192.168.1.22:8000/metrics`
- Kali Grafana: `http://192.168.1.22:3000`
- Kali Prometheus: `http://192.168.1.22:9090`
- cAdvisor on Kali: `http://192.168.1.22:8080`

Kali Grafana login:

- Username: `subash`
- Password: stored only in `credentials-and-links.local.md`

MQTT broker details:

- Plain MQTT: `192.168.1.22:1883`
- TLS MQTT: `192.168.1.22:8883`
- MQTT username: `subash`
- MQTT password: stored only in `credentials-and-links.local.md`

Test example:

```bash
mosquitto_pub -h 192.168.1.22 -p 1883 -u subash -P <stored-locally> -t test/local/1883 -m hello
```

## SNMP

- SNMP host: `192.168.1.22:161`
- Access mode: SNMPv3 `authPriv`
- Username: `snmpmgr_jaqun8lt`
- Auth protocol: `SHA`
- Auth password: stored only in `credentials-and-links.local.md`
- Priv protocol: `AES`
- Priv password: stored only in `credentials-and-links.local.md`
- Saved on Kali at: `/home/subash/snmpv3-credentials.txt`

Test command:

```bash
snmpget -v3 -l authPriv -u snmpmgr_jaqun8lt -a SHA -A <stored-locally> -x AES -X <stored-locally> 192.168.1.22 1.3.6.1.2.1.1.1.0
```

## Helper Scripts To Use

- Start local project stacks:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\start_project_dockers.bat
```

- Open the all-in-one helper menu:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\helper_menu.bat
```

- Start a full manual testing session:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\start_manual_testing.bat
```

- Pick a target from existing workspaces and start manual testing:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\pick_manual_target.bat
```

- Generate one full Kali debug report:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\project_debug_report_kali.bat
```

- Create a fresh manual report draft:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\new_manual_report.bat
```

- Generate one unattended report:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\project_debug_report_kali.bat --no-prompt
```

- Open SSH session to Kali:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\open_kali_ssh.bat
```

- Telemetry-focused check:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\telemetry_debug_kali.bat
```

- TLS-focused check:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\tls_test_kali.bat
```

- Public HTTPS/TLS-focused check:

```bat
d:\Kali linux\bbp_final_pro_framework\scripts\local-vm-helpers\public_tls_sample_check.bat
```

## Notes

- The Windows repo copy is your main working copy.
- The Kali repo copy is a deployed snapshot at `/home/subash/bbp_final_pro_framework`.
- The Kali `k3s` deployment exposes the same mock API route listing as the Windows repo stack.
- Secret values are intentionally omitted here. Use `credentials-and-links.local.md` for the live values.
- Older port-only and Cloudflare-specific helper launchers were archived under `scripts\local-vm-helpers\legacy`.
