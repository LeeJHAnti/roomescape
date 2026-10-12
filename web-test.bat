@echo off
rem Export the demo to Web and serve it locally.
rem   web-test.bat        -> this PC only (http://127.0.0.1:8765)
rem   web-test.bat lan    -> also reachable from a phone on the same Wi-Fi while this window is open
setlocal
set "GODOT=C:\Users\JU\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
set "PROJ=%~dp0."
set "OUT=%~dp0build\web"
set "PORT=8765"
set "BIND=127.0.0.1"
if /i "%~1"=="lan" set "BIND=0.0.0.0"

for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%t"
set "TEMP=D:\w\temp\home-demo-web-%STAMP%"
set "TMP=%TEMP%"
mkdir "%TEMP%" >nul 2>&1
if not exist "%OUT%" mkdir "%OUT%"

echo [1/2] Web export...
"%GODOT%" --headless --path "%PROJ%" --export-release "Web" "%OUT%\index.html"
if errorlevel 1 (
  echo Export failed.
  pause
  exit /b 1
)

set "PY=%~dp0..\.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=py -3"

echo [2/2] Serving %OUT% on %BIND%:%PORT%  (close this window to stop)
if /i "%BIND%"=="0.0.0.0" (
  echo Phone: open one of these on the same Wi-Fi:
  powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' } | ForEach-Object { '  http://' + $_.IPAddress + ':%PORT%/' }"
)
start "" "http://127.0.0.1:%PORT%/"
%PY% -m http.server %PORT% --bind %BIND% --directory "%OUT%"
endlocal
