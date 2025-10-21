@echo off
REM ============================================================
REM Bootstrap Launcher
REM Bypasses PowerShell execution policy and runs Bootstrap.ps1
REM ============================================================

echo.
echo ========================================
echo Environment Bootstrap
echo ========================================
echo.

REM Check if Bootstrap.ps1 exists
if not exist "%~dp0Bootstrap.ps1" (
    echo ERROR: Bootstrap.ps1 not found in current directory
    echo.
    pause
    exit /b 1
)

REM Try to set execution policy for future runs (fails silently if no permission)
echo Configuring PowerShell execution policy...
powershell.exe -NoProfile -Command "try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force } catch { }" 2>nul

REM Run Bootstrap.ps1 with execution policy bypass
echo Running Bootstrap.ps1...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bootstrap.ps1"

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Bootstrap completed successfully
    echo ========================================
) else (
    echo.
    echo ========================================
    echo Bootstrap failed with error code %ERRORLEVEL%
    echo ========================================
)

echo.
pause
