rem @echo off

if "%1" == ""         goto x86
if /i %1 == x86       goto x86
if /i %1 == x64       goto x64
goto usage

:x86
set platform=x86
goto check_vs_install_dir
:x64
set platform=x64
goto check_vs_install_dir

:check_vs_install_dir
if not "%VSINSTALLDIR%"=="" goto vs_install_dir_defined

:define_vs_install_dir
if not defined VS_VERSION (
  set VS_VERSION=vs140
)
if "%VS_VERSION%"=="vs90" (
  set VS_VERSION_NUMBER=90
  set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2008"
) else if "%VS_VERSION%"=="vs100" (
  set VS_VERSION_NUMBER=100
  set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2010"
) else if "%VS_VERSION%"=="vs110" (
  set VS_VERSION_NUMBER=110
  set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2012"
) else if "%VS_VERSION%"=="vs120" (
  set VS_VERSION_NUMBER=120
  set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2013"
) else if "%VS_VERSION%"=="vs140" (
  set VS_VERSION_NUMBER=140
  if exist "C:\Program Files (x86)\Microsoft Visual Studio 14.0\" (
    set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 14.0"
  ) else (
    set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2015"
  )
) else if "%VS_VERSION%"=="vs150" (
  set VS_VERSION_NUMBER=150
  set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio 2017"
)
if not defined VSINSTALLDIR (
  echo Error: No Visual C++ environment found.
  echo Please run this script from a Visual Studio Command Prompt
  echo or run "%%VSnnCOMNTOOLS%%\VC\vcvarsall.bat" first.
  exit /b 1
)

:vs_install_dir_defined

if defined VCINSTALLDIR goto vs_vars_loaded
call %VSINSTALLDIR%\VC\vcvarsall.bat %platform%

:vs_vars_loaded

rem Set CMake Generator
rem
rem Visual Studio 15 2017 [arch] = Generates Visual Studio 2017 project files.
rem                                Optional [arch] can be "Win64" or "ARM".
rem Visual Studio 14 2015 [arch] = Generates Visual Studio 2015 project files.
rem                                Optional [arch] can be "Win64" or "ARM".
rem Visual Studio 12 2013 [arch] = Generates Visual Studio 2013 project files.
rem                                Optional [arch] can be "Win64" or "ARM".
rem Visual Studio 11 2012 [arch] = Generates Visual Studio 2012 project files.
rem                                Optional [arch] can be "Win64" or "ARM".
rem Visual Studio 10 2010 [arch] = Generates Visual Studio 2010 project files.
rem                                Optional [arch] can be "Win64" or "IA64".
rem Visual Studio 9 2008 [arch]  = Generates Visual Studio 2008 project files.
rem                                Optional [arch] can be "Win64" or "IA64".
rem
if "%VS_VERSION%"=="vs90" (
  set CMAKE_GENERATOR=Visual Studio 9 2008
) else if "%VS_VERSION%"=="vs100" (
  set CMAKE_GENERATOR=Visual Studio 10 2010
) else if "%VS_VERSION%"=="vs110" (
  set CMAKE_GENERATOR=Visual Studio 11 2012
) else if "%VS_VERSION%"=="vs120" (
  set CMAKE_GENERATOR=Visual Studio 12 2013
) else if "%VS_VERSION%"=="vs140" (
  set CMAKE_GENERATOR=Visual Studio 14 2015
) else if "%VS_VERSION%"=="vs150" (
  set CMAKE_GENERATOR=Visual Studio 15 2017
) else (
  echo Error: VS_VERSION not set
  exit /b 1
)
if "%platform%" == "x64" (
  set CMAKE_GENERATOR=%CMAKE_GENERATOR% Win64
)

rem Build Poco
set POCO_BASE=%cd%

echo Building poco Release

mkdir cmake_build_Release
cd cmake_build_Release

cmake .. ^
  -G "%CMAKE_GENERATOR%" ^
  -DENABLE_PDF=OFF ^
  -DENABLE_MONGODB=OFF ^
  -DENABLE_DATA=OFF ^
  -DENABLE_PAGECOMPILER=OFF ^
  -DENABLE_CPPPARSER=OFF ^
  -DENABLE_APACHECONNECTOR=OFF ^
  -DENABLE_SEVENZIP=OFF ^
  -DENABLE_REDIS=OFF ^
  -DENABLE_POCODOC=OFF ^
  -DPOCO_STATIC=1 ^
  -DPOCO_MT=ON ^
  -DCMAKE_INSTALL_PREFIX=%POCO_BASE%/cmake_install_Release
cmake --build . --config Release --target install
cd ..

echo Building poco Debug
mkdir cmake_build_Debug
cd cmake_build_Debug

cmake .. ^
  -G "%CMAKE_GENERATOR%" ^
  -DENABLE_PDF=OFF ^
  -DENABLE_MONGODB=OFF ^
  -DENABLE_DATA=OFF ^
  -DENABLE_PAGECOMPILER=OFF ^
  -DENABLE_CPPPARSER=OFF ^
  -DENABLE_APACHECONNECTOR=OFF ^
  -DENABLE_SEVENZIP=OFF ^
  -DENABLE_REDIS=OFF ^
  -DENABLE_POCODOC=OFF ^
  -DPOCO_STATIC=1 ^
  -DPOCO_MT=ON ^
  -DCMAKE_INSTALL_PREFIX=%POCO_BASE%/cmake_install_Debug
cmake --build . --config Release --target install
cd ..

goto :eof

:usage
echo Error in script usage. The correct usage is:
echo     %0 [option]
echo where [option] is: x86 ^| x64
echo :
goto :eof
