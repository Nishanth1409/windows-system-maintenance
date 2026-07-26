@echo off
title System Maintenance - Admin
color 0B
echo.
echo  ========================================
echo   SYSTEM MAINTENANCE (Administrator)
echo  ========================================
echo.

echo [1/7] Removing old Windows files (fast cleanup)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SystemMaintenance\scripts\System_WindowsJunk.ps1" -Level Admin -Silent -ShowProgress -NoDism
echo        Step 1 done.
echo.

echo [2/7] Cleaning superseded Windows update files (DISM)...
echo        Can take 10-30 minutes. Please wait.
echo.
DISM /Online /Cleanup-Image /StartComponentCleanup
echo        Step 2 done.
echo.

echo [3/7] Flushing DNS cache...
ipconfig /flushdns
echo        Step 3 done.
echo.

echo [4/7] Running DISM health restore...
echo        Can take 10-20 minutes. Please wait.
echo.
DISM /Online /Cleanup-Image /RestoreHealth
echo        Step 4 done.
echo.

echo [5/7] Running system file check...
sfc /scannow
echo        Step 5 done.
echo.

echo [6/7] Resetting network stack (winsock)...
netsh winsock reset
echo        Step 6 done.
echo        NOTE: Reboot after Full Maintenance for winsock reset to apply.
echo.

echo [7/7] Updating machine-wide apps (Administrator winget)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SystemMaintenance\scripts\System_WingetAdmin.ps1" -Silent
echo        Step 7 done. User updates run next (not in admin).
echo.

echo  === ADMIN TASKS COMPLETED ===
echo.
timeout /t 5 /nobreak >nul
exit /b 0
