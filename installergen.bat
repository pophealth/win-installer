@echo off
setlocal

REM ==========================================================================
REM installergen.bat
REM
REM This batch file will prepare the NSIS build directory to build a specific
REM version of the windows installer for popHealth and/or cypress.
REM
REM Some of the dependencies are available in both 32- and 64-bit
REM variants.  Also, some of the dependencies are distributed as .zip files
REM rather than executable installers.  For the .zip based dependencies, we
REM unpack them in this folder and then incorporate them into the 
REM installer.
REM
REM This batch file expects three mandatory arguments(default value)
REM   %1 the target architecture: 32|64
REM   %2 the product:		  popHealth|cypress
REM   %3 the version tag:	  version of the product (e.g. v1.1)
REM
REM Additionally you can pass the following switches on the command line
REM   --help	 to show usage information
REM   --verbose	 to turn echo on and see eberything that is happening
REM   --noclean	 to not delete any lingering files from a previous installation
REM   --nofetch	 to not pull the tar files for measures and product
REM   --noop	 to run through what would be performed but without doing it
REM   --fat-and-happy to generate a self-contained installer that packages all 
REM                   requisite gems in the installer
REM   --lean-and-mean to generate the bare minimum installer which relies on
REM                   the client machine pulling gems at install time
REM
REM Original Author: Tim Taylor <ttaylor@mitre.org>
REM Secondary:	     Tim Brown  <timbrown@mitre.org>
REM ==========================================================================

REM Specify the version number of the installer.  This number will be used in
REM forming the filenames of the installer executables.
set arch=%1
set product=%2
set installer_ver=%3

set installer_dir=%CD%

REM ====================
REM Tag or branch names of projects to bundle with the installer.  The machine
REM building the installer will need git, but clients won't any more.
REM
REM There is currently a dependency on the measures project, redis, and mongodb
REM
REM When it comes time to build an installer for a new version of popHealth or
REM cypress, just update these if necessary and rebuild.
REM ====================
set measures_tag=v1.4.1
set redisdir=redis-2.4.0
set mongodbdir=mongodb-2.0.1

REM The directory to build native gems in
set gem_build_dir=%TEMP%\native_gems
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

REM process all of the switches that were on the command line
set self_contained=0
set showhelp=0
set fetch=1
set clean=1
set verbose=0
set build=1
set noop=0
for %%A in (%*) do (
  REM generate a "lean and mean" installer - one that has the bare 
  REM minimum in the package and requires the client machine to pull the
  REM rest from rubygems
  if "%%A"=="--lean-and-mean"  (set self_contained=0)

  REM generate a "fat and happy" installer - one that has all of the requisite
  REM gems bundled within it
  if "%%A"=="--fat-and-happy"  (set self_contained=1)
  if "%%A"=="--verbose"        (set verbose=1)
  if "%%A"=="--nofetch"        (set fetch=0)
  if "%%A"=="--noclean"        (set clean=0)
  if "%%A"=="--noop"           (set build=0)
  if "%%A"=="--help"           (set showhelp=1)
)
if %showhelp%==1 (goto :USAGE)

REM Check mandatory arguments provided to the script
if not "%arch%"=="32" (
  if not "%arch%"=="64" (
    echo.
    echo *** %arch% is not a known archictecture, please use 32 or 64
    echo.
    goto :USAGE
  )
)
if not "%product%"=="cypress" (
  if not "%product%"=="popHealth" (
    echo.
    echo *** %product% is not a known product, please use cypress or popHealth
    echo.
    goto :USAGE
  )
)
set ver=%installer_ver:v=X%
if "%installer_ver%"=="%version%" (
    echo.
    echo *** the version should begin with v, for example v1.2.1
    echo.
    goto :USAGE
)

if %verbose% == 1 (@echo on)

if %build%==0 (
  echo *------------------------------------------------------------*
  echo *
  echo * you have requested a %arch%-bit installer for %product% %installer_ver%
  if %self_contained%==1 ( 
    echo *    - as a self-contained package 
  ) else (
    echo *    - as a minimal-size package 
  )
  echo *
  echo * (remove the --noop switch to go ahead and build it
  echo *------------------------------------------------------------*
  goto :EOF
)

echo --------------------------------------------------------------------------------
echo Preparing to build a %arch%-bit %product% installer...
echo --------------------------------------------------------------------------------

REM We need unzip, tar, curl, grep, bundle and makensis on the path.  Check for 'em
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
REM a compiler on the path, and define environment variables the RailsInstaller
REM devkit sets up.
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
REM Clean out whatever was leftover from previous builds
REM ------
if %clean% == 1 (
  echo ...cleaning up from previous builds
  if exist cypress      (rd /s /q cypress)
  if exist popHealth    (rd /s /q popHealth)
  if exist measures     (rd /s /q measures)
  if exist %mongodbdir% (rd /s /q %mongodbdir%)
  if exist %redisdir%   (rd /s /q %redisdir%)
  if exist cypress*.tgz (del cypress*.tgz)
  if exist popHealth*.tgz (del popHealth*.tgz)
  if exist measurs*.tgz (del measures*.tgz)
)

REM ------
REM Fetch tarballs of the various repos we need.
REM ------
if "%product%"=="cypress" (set github_url=https://github.com/projectcypress/cypress)
if "%product%"=="popHealth" (set github_url=https://github.com/pophealth/popHealth)
if %fetch% == 1 (
  if not exist %product%-%installer_ver%.tgz (
    echo ...fetching tarball from github for %product%-%installer_ver%
    "%curlcmd%" -s -k -L %github_url%/tarball/%installer_ver% > %product%-%installer_ver%.tgz
  )

  REM measures is used by both products
  if not exist measures-%measures_tag%.tgz (
    echo ...fetching tarball from github for  measures-%measures_tag%
    "%curlcmd%" -s -k -L https://github.com/pophealth/measures/tarball/%measures_tag% > measures-%measures_tag%.tgz
  )
)
if %build% == 0 (
  echo --------------------------------------------------------------------------------
  echo NOT building an installer with the following characteristics
  echo     	      %arch%-bit %product%
  if %self_contained% == 1 (
    echo ...with ALL of the requisite gems ^(fat and happy^)
  ) else (
    echo ...with the bare minimum bundled gems ^(lean and mean^)
  )
  echo.
  echo %*
  echo.
  goto :EOF
)
REM Unpack the product and prepare it accordingly.
mkdir %product%
"%tarcmd%" --strip-components=1 -C %product% -xf .\%product%-%installer_ver%.tgz
if %self_contained% == 1 (
  pushd %product%
  echo ...packaging up all of the requisite gems into %product%/vendors/cache
  if not exist Gemfile.lock ( call bundle.bat install --without="test build" )
  call bundle.bat install --deployment
  call bundle.bat package
  popd
)
REM Unpack the producmeasures project and prepare it accordingly.
mkdir measures
"%tarcmd%" --strip-components=1 -C measures -xf .\measures-%measures_tag%.tgz
if %self_contained% == 1 (
  pushd measures
  echo ...packaging up all of the requisite gems into measures/vendors/cache
  if not exist Gemfile.lock ( call bundle.bat install --without="test build" )
  call bundle.bat install --deployment
  call bundle.bat package
  popd
)

REM determine the size of product+measures to be added using AddSize in the NSIS script
echo ...determining how much space will be needed for the installed product
du --summarize --total %product% measures | findstr total > foo.tmp
set /p tempsize= < foo.tmp
REM trim off the size portion
for /f "tokens=1,2 delims=/	" %%a in ("%tempsize%") do set size=%%a
del foo.tmp

REM ------
REM Build all the native gems we need to include.
REM ------
if exist binary_gems ( 
  echo ...removing existing binary_gems directory 
  rd /s /q binary_gems
)
echo Building all the native gems required...
mkdir binary_gems
if not exist %gem_build_dir% (mkdir %gem_build_dir%)
for %%g in (%native_gem_list%) do (
  for /f "tokens=1,2 delims=;" %%t in ('cmd /v:on /c @echo !gem_%%g_info!') do (
    pushd %gem_build_dir%
    echo Gem: %%g tag %%t at %%u
    if not exist %%g (
      echo ...cloning for the first time
      git.exe clone %%u %%g
      cd %%g
    ) else (
      echo ...updating existing repo for %%g
      cd %%g
      git.exe fetch origin
      git.exe checkout -f master
    )
    git.exe checkout -q -B mitre tags/%%t

    REM If we have a patch file required to build native gem, apply it
    if exist %installer_dir%\%%g.patch (
      echo ...applying MITRE custom patch for %%g
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
    move %gem_build_dir%\%%g\pkg\%%g-*-x86-mingw32.gem binary_gems\
  )
)

REM Unpack redis and prepare it accordingly.
echo ...unpacking and preparing redis...
if exist %redisdir% ( 
  echo removing existing %resdir% directory 
  rd /s /q %redisdir%
)
mkdir %redisdir%
"%unzipcmd%" .\redis-2.4.0-win32-win64.zip -d %redisdir% > nul
REM Copy our slightly modified redis.conf file into place
copy redis.conf %redisdir%\32bit > nul
copy redis.conf %redisdir%\64bit > nul
REM Need to package an empty log file for redis
echo Empty log for install > %redisdir%\redis_log.txt
REM Create database directory
mkdir %redisdir%\db

if exist %mongodbdir% ( 
  echo ...removing existing %mongodbdir% directory 
  rd /s /q %mongodbdir%
)
if "%arch%"=="32" (
  echo ...doing 32bit specific stuff

  REM Delete the redis 64bit tree
  rd /s /q %redisdir%\64bit

  REM Unzip 32bit mongodb
  "%unzipcmd%" .\mongodb-win32-i386-2.0.1.zip > nul
  ren mongodb-win32-i386-2.0.1 %mongodbdir%
) else (
  echo ...doing 64bit specific stuff

  REM Delete the redis 32bit tree
  rd /s /q %redisdir%\32bit
 
  REM Unzip 64bit mongodb
  "%unzipcmd%" .\mongodb-win32-x86_64-2.0.1.zip
  ren mongodb-win32-x86_64-2.0.1 %mongodbdir%
)

REM Run makensis to build product installer
echo To run the install generator use:
echo "%makensiscmd%" /DBUILDARCH=%arch% /DINSTALLER_VER=%installer_ver% /DPRODUCT_NAME=%product% /DSIZE_TO_ADD=%size% main.nsi
"%makensiscmd%" /DBUILDARCH=%arch% /DINSTALLER_VER=%installer_ver% /DPRODUCT_NAME=%product% /DSIZE_TO_ADD=%size% main.nsi

echo.
echo --------------------------------------------------------------------------------
if %arch%==32 (
  echo Installer is available for testing: %product%-%installer_ver%-i386.exe
) else (
  echo Installer is available for testing: %product%-%installer_ver%-x86_64.exe
)
echo --------------------------------------------------------------------------------
echo.
goto :EOF

:USAGE
  echo.
  echo Usage: ^<architecture^> ^<product^> ^<version^> [switches]
  echo.
  echo       where ^<architecture^> is one of 32 or 64
  echo       and   ^<product^> is either cypress or popHealth
  echo       and   ^<version^> is the tag or branch name of the ^<product^>
  echo.
  echo    available switches are:
  echo    --help          to show usage information
  echo    --verbose       to turn echo on and see eberything that is happening
  echo    --noclean       to not delete lingering files from a previous installation
  echo    --nofetch       to not pull the tar files for measures and product
  echo    --noop          to run through what would be performed but without doing it
  echo    --fat-and-happy to generate a self-contained installer that packages all 
  echo                    requisite gems in the installer
  echo    --lean-and-mean to generate the bare minimum installer which relies on
  echo                    the client machine pulling gems at install time
  echo.
  echo The installergen command is a batch file that prepares the directory for either a 32
  echo or a 64 bit build of the installer for popHealth or cypress. The batch 
  echo file will also run the makensis command with the appropriate defines.  
  echo.
  echo If all goes well, this will create an executable called either
  echo ^<product^>-i386.exe (32 bit) or ^<product^>-x86_64.exe (64 bit) which is the
  echo installer for the popHealth project for the respective architecture.  The same is
  echo true for cypress installers.
  echo.

