@echo off
setlocal
set "GODOT=C:\Users\JU\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
set "PROJ=%~dp0"
rem Isolated save/temp so the watch run never touches the real demo save.
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%t"
set "T=D:\w\temp\home-demo-watch-%STAMP%"
mkdir "%T%\appdata" "%T%\localappdata" "%T%\tmp" >nul 2>&1
set "APPDATA=%T%\appdata"
set "LOCALAPPDATA=%T%\localappdata"
set "TEMP=%T%\tmp"
set "TMP=%T%\tmp"
"%GODOT%" --path "%PROJ:~0,-1%" --resolution 540x960 res://tests/run_paths.tscn -- --watch
echo exit=%ERRORLEVEL%
endlocal
pause
