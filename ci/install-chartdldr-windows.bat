@echo off
setlocal EnableExtensions

REM Install chartdldr_pi from an unzipped Windows release artifact.
set "SCRIPT_DIR=%~dp0"
set "OCPN_DIR=%ProgramFiles%\OpenCPN"
if not "%~1"=="" set "OCPN_DIR=%~1"

set "LIB_SRC=%SCRIPT_DIR%plugins\chartdldr_pi.dll"
set "DATA_SRC=%SCRIPT_DIR%plugins\chartdldr_pi"

if not exist "%LIB_SRC%" (
  echo error: missing "%LIB_SRC%"
  echo Run this script from the unzipped Windows artifact folder.
  exit /b 1
)
if not exist "%DATA_SRC%" (
  echo error: missing "%DATA_SRC%"
  exit /b 1
)
if not exist "%OCPN_DIR%\opencpn.exe" (
  echo error: OpenCPN not found at "%OCPN_DIR%"
  echo Pass your install directory as the first argument if needed.
  exit /b 1
)

tasklist /FI "IMAGENAME eq opencpn.exe" 2>nul | find /I "opencpn.exe" >nul
if %ERRORLEVEL%==0 (
  echo error: OpenCPN is running — quit it completely, then run this script again.
  exit /b 1
)

set "LIB_DST=%OCPN_DIR%\plugins\chartdldr_pi.dll"
set "DATA_DST=%OCPN_DIR%\plugins\chartdldr_pi"

if exist "%LIB_DST%" (
  for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "STAMP=%%t"
  echo Backing up existing plugin to "%LIB_DST%.bak.%STAMP%"
  copy /Y "%LIB_DST%" "%LIB_DST%.bak.%STAMP%" >nul
)

if not exist "%OCPN_DIR%\plugins" mkdir "%OCPN_DIR%\plugins"
if not exist "%DATA_DST%" mkdir "%DATA_DST%"

copy /Y "%LIB_SRC%" "%LIB_DST%" >nul
xcopy /E /I /Y "%DATA_SRC%\*" "%DATA_DST%\" >nul

echo Installed chartdldr_pi into "%OCPN_DIR%"
echo Start OpenCPN and enable Chart Downloader under Options - Plugins.
exit /b 0
