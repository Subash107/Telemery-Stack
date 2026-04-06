@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

where docker >nul 2>&1
if errorlevel 1 (
    echo Docker was not found on this computer.
    echo Start Docker Desktop and run this file again.
    pause
    exit /b 1
)

echo Starting repo mock API stack...
docker compose -f "%REPO_ROOT%\docker-compose.yml" up -d
if errorlevel 1 (
    echo Failed to start the repo mock API stack.
    pause
    exit /b 1
)

echo.
echo Starting repo observability stack...
docker compose -f "%REPO_ROOT%\ops\observability\docker-compose.yml" up -d
if errorlevel 1 (
    echo Failed to start the observability stack.
    pause
    exit /b 1
)

echo.
echo Current local Docker containers:
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo Local project URLs
echo ==================
echo Mock API routes  : http://127.0.0.1:18080/mock-six-api/routes
echo Mock API health  : http://127.0.0.1:18080/mock-six-api/health
echo gRPC reflection  : grpcurl -plaintext 127.0.0.1:50061 list
echo Grafana          : http://127.0.0.1:3000
echo Prometheus       : http://127.0.0.1:9090
echo Alertmanager     : http://127.0.0.1:9093
echo blackbox_exporter: http://127.0.0.1:9115
echo cAdvisor         : http://127.0.0.1:8080

echo.
echo Remote Kali URLs
echo ================
echo MQTT Dashboard   : http://192.168.1.22:5000
echo MQTT App Metrics : http://192.168.1.22:8000/metrics
echo Kali Grafana     : http://192.168.1.22:3000
echo Kali Prometheus  : http://192.168.1.22:9090
echo Kali Mock API    : http://192.168.1.22:30080/mock-six-api/routes
echo Kali gRPC list   : grpcurl -plaintext 192.168.1.22:30061 list

echo.
echo Tip: use project_debug_report_kali.bat for DNS, PTR, CIDR, TLS, API, MQTT, and port reports.
if not defined NO_PAUSE pause
exit /b 0
