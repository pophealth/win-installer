@echo off
setlocal

REM ==========================================================================
REM preparefor.bat
REM
REM This batch file will prepare the NSIS build directory to build a specific
REM version of the windows installer for popHealth.
REM
REM Some of the popHealth dependencies are available in both 32- and 64-bit
REM variants.  Also, some of the dependencies are distributed as .zip files
REM rather than executable installers.  For the .zip based dependencies, we
REM unpack them in this folder and then incorporate them into the popHealth
REM installer.
REM
REM This batch file expects a single argument which can be either 32 or 64.
REM If no argument is provided, 32 is assumed.
REM
REM Original Author: Tim Taylor <ttaylor@mitre.org>
REM ==========================================================================

REM Specify the version number of the installer.  This number will be used in
REM forming the filenames of the installer executables.
set installer_ver=1.4.1

set myarch=32
set installer_dir=%CD%

REM ====================
REM Tag or branch names of projects to bundle with the installer.  The machine
REM building the installer will need git, but clients won't any more.
REM
REM When it comes time to build an installer for a new version of popHealth,
REM just update these and rebuild.
REM ====================
set pophealth_tag=v1.4.1
set measures_tag=v1.4.1
set qme_tag=v1.1.1
set patient-importer_tag=v0.2

REM ====================
REM Information about native gems we need to build, and include in the
REM installer.
REM ====================
REM nagive_gem_list is a semi-colon (;) separated list of the gems we need.
REM For each gem, define a variable named gem_<gem_name>_info that contains
REM the repo tag for the version we want and the git repo url separated by a
REM ';'.  For example
REM gem_bson_ext_info=1.5.1;https://github.com/mongodb/mongo-ruby-driver.git
set native_gem_list=bson_ext;json
set gem_bson_ext_info=1.5.1;https://github.com/mongodb/mongo-ruby-driver.git
set gem_json_info=v1.4.6;https://github.com/flori/json.git

REM The directory to build native gems in
set gem_build_dir=%TEMP%\popHealth_gems

REM Check options provided to the script
if not "%1"=="" (
  if "%1"=="all" (
    call %0 32
    call %0 64
    exit /B
  ) else (
    if "%1"=="32" (set myarch=32
    ) else (
      if "%1"=="64" (set myarch=64
      ) else (
        echo Invalid option "%1" received.
        echo Usage: %0 [all^|32^|64]
        exit /b 1
      )
    )
  )
)

echo Preparing to build a %myarch%-bit installer...

REM We need unzip, tar, curl, grep and makensis on the path.  Check for 'em
set unzipcmd=
set tarcmd=
set curlcmd=
set grepcmd=
set makensiscmd=
for %%e in (%PATHEXT%) do (
  for %%x in (unzip%%e) do (
    if not defined unzipcmd (set unzipcmd=%%~$PATH:x)
  )
)
if "%unzipcmd%"=="" (
  echo unzip command was not found on the path.  Please correct.
  echo If you've installed git, try adding [git_home]\bin to path.
  exit /b 1
)
for %%e in (%PATHEXT%) do (
  for %%x in (tar%%e) do (
    if not defined tarcmd (set tarcmd=%%~$PATH:x)
  )
)
if "%tarcmd%"=="" (
  echo tar command was not found on the path.  Please correct.
  echo If you've installed git, try adding [git_home]\bin to path.
  exit /b 1
)
for %%e in (%PATHEXT%) do (
  for %%x in (curl%%e) do (
    if not defined curlcmd (set curlcmd=%%~$PATH:x)
  )
)
if "%curlcmd%"=="" (
  echo curl command was not found on the path.  Please correct.
  echo If you've installed git, try adding [git_home]\bin to path.
  exit /b 1
)
for %%e in (%PATHEXT%) do (
  for %%x in (grep%%e) do (
    if not defined grepcmd (set grepcmd=%%~$PATH:x)
  )
)
if "%grepcmd%"=="" (
  echo grep command was not found on the path.  Please correct.
  echo If you've installed git, try adding [git_home]\bin to path.
  exit /b 1
)
for %%e in (%PATHEXT%) do (
  for %%x in (makensis%%e) do (
    if not defined makensiscmd (set makensiscmd=%%~$PATH:x)
  )
)
if "%makensiscmd%"=="" (
  echo makensis command was not found on the path.  Please correct.
  exit /b 1
)

REM Check and make sure the rake-compiler gem is installed.
gem list --local | grep -q rake-compiler
if ERRORLEVEL 1 (
  echo The rake-compiler gem is not installed.  Please run the command:
  echo   gem install rake-compiler
  exit /b 1
)

REM We need a sane development environment to build native gems.  Look for
REM a compiler on the path, and define environment variables the ruby devkit
REM sets up.
set gcccmd=
for %%e in (%PATHEXT%) do (
  for %%x in (gcc%%e) do (
    if not defined gcccmd (set gcccmd=%%~$PATH:x)
  )
)
if "%gcccmd%"=="" (
  echo Development tools were not found on the path.
  set /P RI_DEVKIT="Enter path to ruby devkit home: "
)
if not exist %RI_DEVKIT%\mingw\bin\gcc.exe (
  echo %RI_DEVKIT% doesn't appear to contain the mingw tools.
  exit /b 1
)
path=%RI_DEVKIT%\bin;%RI_DEVKIT%\mingw\bin;%path%
set CC=gcc
set CPP=cpp
set CXX=g++

REM ==========================================================================
REM Let's get to work!
REM ==========================================================================

REM ------
REM These steps need to be done regardless of the architecture
REM ------

REM ------
REM Fetch tarballs of the various pophealth repos we need.
REM ------
if not exist popHealth-%pophealth_tag%.tgz (
  "%curlcmd%" -s https://nodeload.github.com/pophealth/popHealth/tarball/%pophealth_tag% > popHealth-%pophealth_tag%.tgz
)
if not exist measures-%measures_tag%.tgz (
  "%curlcmd%" -s https://nodeload.github.com/pophealth/measures/tarball/%measures_tag% > measures-%measures_tag%.tgz
)
if not exist patient-importer-%patient-importer_tag%.tgz (
  "%curlcmd%" -s https://nodeload.github.com/pophealth/patient-importer/tarball/%patient-importer_tag% > patient-importer-%patient-importer_tag%.tgz
)

REM Unpack popHealth and prepare it accordingly.
echo Unpacking and preparing popHealth...
if exist popHealth ( rd /s /q popHealth )
mkdir popHealth
"%tarcmd%" --strip-components=1 -C popHealth -xf .\popHealth-%pophealth_tag%.tgz

REM Unpack measures and prepare it accordingly.
echo Unpacking and preparing measures...
if exist measures ( rd /s /q measures )
mkdir measures
"%tarcmd%" --strip-components=1 -C measures -xf .\measures-%measures_tag%.tgz

REM Unpack patient-importer and prepare it accordingly.
echo Unpacking and preparing patient-importer...
if exist patient-importer ( rd /s /q patient-importer )
mkdir patient-importer
"%tarcmd%" --strip-components=1 -C patient-importer -xf .\patient-importer-%patient-importer_tag%.tgz > nul 2> nul
REM Don't want the JRE versions included in the patient-importer repo
pushd patient-importer
if exist jre32_6u24 ( rd /s /q jre32_6u24 )
if exist jre1.6.0_31 ( rd /s /q jre1.6.0_31 )
rm .gitignore
rm start_importer.sh
REM Move lib subdir up a level and delete rest of source
move source/lib .
rd /s /q source
REM Modify the startup batch file to reflect new lib location
sed -i -e 's/^jre32_6u24\\\\bin\\\\//' -e 's/source\\\\//g' start_importer.bat > nul 2> nul
popd

REM ------
REM Build all the native gems we need to include.
REM ------
echo Building all the native gems required...
if exist binary_gems ( rd /s /q binary_gems )
mkdir binary_gems
if not exist %gem_build_dir% (mkdir %gem_build_dir%)
for %%g in (%native_gem_list%) do (
  for /f "tokens=1,2 delims=;" %%t in ('cmd /v:on /c @echo !gem_%%g_info!') do (
    pushd %gem_build_dir%
    echo Gem: %%g tag %%t at %%u
    if not exist %%g (
      echo Cloning for the first time
      git.exe clone %%u %%g
      cd %%g
    ) else (
      echo Updating existing repo for %%g
      cd %%g
      git.exe fetch origin
      git.exe checkout -f master
    )
    git.exe checkout -q -B mitre tags/%%t

    REM If we have a patch file required to build native gem, apply it
    if exist %installer_dir%\%%g.patch (
      echo Applying MITRE custom patch
      patch -p1 -t -F 0 -b -z .mitre < %installer_dir%\%%g.patch
    )

    REM prepare for building binary gem by removing package dir
    if exist pkg (
      if exist pkg\*.gem ( del pkg\*.gem )
    )

    REM Build the platform specific binary gem
    call rake.bat native gem > nul 2> nul

    popd

    REM Copy the compiled gem to the install directory
    move %gem_build_dir%\%%g\pkg\%%g-*-x86-mingw32.gem binary_gems
  )
)

REM Unpack redis and prepare it accordingly.
echo Unpacking and preparing redis...
set redisdir=redis-2.4.0
if exist %redisdir% ( rd /s /q %redisdir% )
mkdir %redisdir%
"%unzipcmd%" .\redis-2.4.0-win32-win64.zip -d %redisdir% > nul
REM Copy our slightly modified redis.conf file into place
copy redis.conf %redisdir%\32bit > nul
copy redis.conf %redisdir%\64bit > nul
REM Need to package an empty log file for redis
echo Empty log for install > %redisdir%\redis_log.txt
REM Create database directory
mkdir %redisdir%\db

set mongodbdir=mongodb-2.0.1
if exist %mongodbdir% ( rd /s /q %mongodbdir% )

if "%myarch%"=="32" (
  echo doing 32bit specific stuff...

  REM Delete the redis 64bit tree
  rd /s /q %redisdir%\64bit

  REM Unzip 32bit mongodb
  "%unzipcmd%" .\mongodb-win32-i386-2.0.1.zip > nul
  ren mongodb-win32-i386-2.0.1 %mongodbdir%
) else (
  echo doing 64bit specific stuff...

  REM Delete the redis 32bit tree
  rd /s /q %redisdir%\32bit
 
  REM Unzip 64bit mongodb
  "%unzipcmd%" .\mongodb-win32-x86_64-2.0.1.zip
  ren mongodb-win32-x86_64-2.0.1 %mongodbdir%
)

REM Run makensis to build installer
"%makensiscmd%" /DBUILDARCH=%myarch% /DINSTALLER_VER=%installer_ver% popHealth.nsi
