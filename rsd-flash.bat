@echo off
setlocal
cd /d "%~dp0"

REM Moto RSD Lite for Windows - launches PowerShell flasher
REM Double-click this file, or run: rsd-flash.bat [firmware dir] [xml]

where powershell >nul 2>nul
if errorlevel 1 (
  echo [-] PowerShell not found. Windows PowerShell is required.
  pause
  exit /b 1
)

if not exist "%~dp0files\fastboot.exe" (
  echo [-] Missing files\fastboot.exe
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rsd-flash.ps1" %*
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo.
  echo [-] Exit code %ERR%
  pause
)
exit /b %ERR%
