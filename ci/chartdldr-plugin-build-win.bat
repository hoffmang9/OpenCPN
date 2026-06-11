@echo off
setlocal enabledelayedexpansion

set "SCRIPTDIR=%~dp0"
if "%CONFIGURATION%" == "" set "CONFIGURATION=Release"

if exist D:\a\OpenCPN\OpenCPN (subst N: D:\a\OpenCPN\OpenCPN)
if exist N:\ (
  n:
  cd \
)

if not defined VCINSTALLDIR (
  for /f "tokens=* USEBACKQ" %%p in (
    `"%programfiles(x86)%\Microsoft Visual Studio\Installer\vswhere" ^
    -latest -property installationPath`
  ) do call "%%p\Common7\Tools\vsDevCmd.bat"
)

call %SCRIPTDIR%..\buildwin\win_deps.bat wx32
call %SCRIPTDIR%..\cache\wx-config.bat

if exist build (rmdir /s /q build)
mkdir build && cd build

set "PATH=%PATH%;%PROGRAMFILES%\Poedit\Gettexttools\bin"

cmake -A Win32 -G "Visual Studio 17 2022" ^
    -DCMAKE_GENERATOR_PLATFORM=Win32 ^
    -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
    -DwxWidgets_LIB_DIR=!wxWidgets_LIB_DIR! ^
    -DwxWidgets_ROOT_DIR=!wxWidgets_ROOT_DIR! ^
    -DwxWidgets_CONFIGURATION=mswu ^
    -DOCPN_TARGET_TUPLE=msvc-wx32;10;x86_64 ^
    -DOCPN_CI_BUILD=ON ^
    -DOCPN_BUNDLE_WXDLLS=ON ^
    -DOCPN_RELEASE=0 ^
    -DOCPN_BUILD_TEST=OFF ^
    ..

cmake --build . --config %CONFIGURATION% --target chartdldr_pi
