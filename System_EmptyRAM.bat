@echo off
setlocal EnableExtensions
title RAM Map Empty
cd /d "%~dp0"

:: Self-elevate to Administrator (required for RAMMap deep empty)
net session >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0.'"
    exit /b 0
)

set "LOG=%~dp0logs\RAMMap_Empty.log"
set "RAM=%~dp0app\RAMMap64.exe"
echo [%date% %time%] RAM Map Empty started >> "%LOG%"

if not exist "%RAM%" (
    echo [%date% %time%] ERROR: RAMMap64.exe not found >> "%LOG%"
    powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('RAMMap64.exe not found in %~dp0app','System Maintenance','OK','Warning')"
    exit /b 1
)

echo Running RAMMap64 deep empty (5 steps)...
"%RAM%" -accepteula -Ew
echo [%date% %time%] -Ew Working Sets exit %ERRORLEVEL% >> "%LOG%"
"%RAM%" -accepteula -Es
echo [%date% %time%] -Es System Working Set exit %ERRORLEVEL% >> "%LOG%"
"%RAM%" -accepteula -E0
echo [%date% %time%] -E0 Priority 0 Standby exit %ERRORLEVEL% >> "%LOG%"
"%RAM%" -accepteula -Et
echo [%date% %time%] -Et Standby List exit %ERRORLEVEL% >> "%LOG%"
"%RAM%" -accepteula -Em
echo [%date% %time%] -Em Modified Page List exit %ERRORLEVEL% >> "%LOG%"
echo [%date% %time%] RAM Map Empty finished >> "%LOG%"

powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('RAM Map Empty completed. All 5 RAMMap actions ran as Administrator.','System Maintenance','OK','Information')"
exit /b 0
