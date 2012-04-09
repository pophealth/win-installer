@echo off
setlocal
goto :PROLOGUE
REM ==========================================================================
REM preparefor.bat
REM
REM This batch file will prepare the NSIS build directory to build a specific
REM version of the windows installer for popHealth and/or Cypress.
REM
REM Some of the dependencies are available in both 32- and 64-bit
REM variants.  Also, some of the dependencies are distributed as .zip files
REM rather than executable installers.  For the .zip based dependencies, we
REM unpack them in this folder and then incorporate them into the 
REM installer.
REM
REM After all of the arguments and switches are processed and the development
REM environment is verified, there are four main steps to creating an 
REM installer:
REM   1. clean - remove any residue from earlier builds so we know we are 
REM              using all and only the latest and greatest
REM   2. fetch - pull source code from github for the projects needed
REM   3. build - this is where all the prep work happens -- packaging up the
REM              required gem files, compiling gems that have to be native,
REM              massaging configuration files
REM   4. generate - invoke the NSIS software to generate the installer from
REM              the software and config information prepared in the build 
REM              step
REM 
REM Original Author: Tim Taylor <ttaylor@mitre.org>
REM Secondary:	     Tim Brown  <timbrown@mitre.org>
REM ==========================================================================

:USAGE
echo.
echo Usage: %0 ^<architecture^> ^<product^> ^<version^> [switches]
echo.
echo   %1 the target architecture: 32^|64
echo   %2 the product:		  popHealth^|Cypress
echo   %3 the version tag:	  version of the product (e.g. v1.1)
echo.
echo Additionally you can pass the following switches on the command line
echo   --help          to show usage information
echo   --verbose       to turn echo on and see eberything that is happening
echo   --fat-and-happy to generate a self-contained installer that packages all 
echo                   requisite gems in the installer
echo   --lean-and-mean to generate the bare minimum installer which relies on
echo                   the client machine pulling gems at install time
echo.
echo   --noclean       to not delete any lingering files from a previous installation
echo   --nofetch       to not pull the tar files for measures and product
echo   --nobuild       to avoid unpacking and compiling requisite software
echo   --nogenerate    to avoid generating the installer with NSIS
echo.
goto :EOF

:PROLOGUE
REM ====================
REM mandatory params
REM ====================
set arch=%1
set product=%2
set installer_ver=%3

set installer_dir=%CD%

REM ====================
REM Tag or branch names of projects to bundle with the installer.  The machine
REM building the installer will need git, but clients won't any more.
REM
REM There currently are dependencies on the measures and patient-importer projects, 
REM redis, and mongodb, as well as a Java Runtime Environment
REM
REM When it comes time to build an installer for a new version of popHealth or
REM Cypress, just update these if necessary and rebuild.
REM ====================
set measures_tag=v1.4.1
set patient-importer_tag=v0.2
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
set clean=1
set fetch=1
set build=1
set generate=1
set verbose=0
if "%1"=="" (goto :USAGE)
for %%A in (%*) do (
  REM generate a "lean and mean" installer - one that has the bare 
  REM minimum in the package and requires the client machine to pull the
  REM rest from rubygems
  if "%%A"=="--lean-and-mean"  (set self_contained=0)

  REM generate a "fat and happy" installer - one that has all of the requisite
  REM gems bundled within it (except the bundler gem itself)
  if "%%A"=="--fat-and-happy"  (set self_contained=1)

  if "%%A"=="--help"           (set showhelp=1)
  if "%%A"=="--verbose"        (set verbose=1)
  if "%%A"=="--db-name"        (set verbose=1)

  if "%%A"=="--noclean"        (set clean=0)
  if "%%A"=="--nofetch"        (set fetch=0)
  if "%%A"=="--nobuild"        (set build=0)
  if "%%A"=="--nogenerate"     (set generate=0)
)

REM Check mandatory arguments provided to the script
if not "%arch%"=="32" (
  if not "%arch%"=="64" (
    echo.
    echo *** %arch% is not a known archictecture, please use 32 or 64
    echo.
    goto :USAGE
  )
)
if not "%product%"=="Cypress" (
  if not "%product%"=="popHealth" (
    echo.
    echo *** %product% is not a known product, please use Cypress or popHealth
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
if %showhelp%==1 (goto :USAGE)

echo --------------------------------------------------------------------------------
echo Preparing to build a %arch%-bit %product% installer...
  if %self_contained%==1 ( 
    echo *    - as a self-contained package 
  ) else (
    echo *    - as a minimal-size package 
  )
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
REM CLEAN
REM ==========================================================================
if %clean% == 1 (
  echo ------
  echo Step 1 Clean out whatever was leftover from previous builds
  echo ------

  echo ...cleaning up from previous builds
  if exist binary_gems  (rd /s /q binary_gems)
  if exist Cypress      (rd /s /q Cypress)
  if exist popHealth    (rd /s /q popHealth)
  if exist patient-importer     (rd /s /q patient-importer)
  if exist measures     (rd /s /q measures)
  if exist %mongodbdir% (rd /s /q %mongodbdir%)
  if exist %redisdir%   (rd /s /q %redisdir%)
  if exist Cypress*.tgz (del Cypress*.tgz)
  if exist popHealth*.tgz (del popHealth*.tgz)
  if exist measures*.tgz (del measures*.tgz)
  if exist patient-importer*.tgz (del patient-importer*.tgz)
)

REM ==========================================================================
REM FETCH
REM ==========================================================================
if %fetch% == 1 (
  echo ------
  echo Step 2 Fetch tarballs of the various repos we need.
  echo ------
  echo ...fetching tarball from github for %product%-%installer_ver% 
  if "%product%"=="Cypress"   (
    if not exist %product%-%installer_ver%.tgz (
      "%curlcmd%" -s -k -L https://github.com/projectcypress/cypress/tarball/%installer_ver% > %product%-%installer_ver%.tgz
    )
  )
  if "%product%"=="popHealth" (
    if not exist %product%-%installer_ver%.tgz (
      "%curlcmd%" -s -k -L https://github.com/pophealth/popHealth/tarball/%installer_ver% > %product%-%installer_ver%.tgz
    )
  )

  REM measures is used by both products
  if not exist measures-%measures_tag%.tgz (
    echo ...fetching tarball from github for measures-%measures_tag%
    "%curlcmd%" -s -k -L https://github.com/pophealth/measures/tarball/%measures_tag% > measures-%measures_tag%.tgz
  )

  REM patient importer can be bundled in
  if not exist patient-importer-%patient-importer_tag%.tgz (
    echo ...fetching tarball from github for patient-importer-%patient-importer_tag%
    "%curlcmd%" -s -k -L https://github.com/pophealth/patient-importer/tarball/%patient-importer_tag% > patient-importer-%patient-importer_tag%.tgz
  )
  echo.
)

REM ==========================================================================
REM BUILD
REM ==========================================================================
if %build% == 1 (
  echo ------
  echo Step 3 Build native gems, package requisite software
  echo ------

  REM Unpack the product and prepare it accordingly.
  mkdir %product%
  "%tarcmd%" --strip-components=1 -C %product% -xf .\%product%-%installer_ver%.tgz > nul 2> nul
  if ERRORLEVEL 1 (
    echo.
    echo *** There is a problem with the tar file %product%-%installer_ver%.tgz
    echo Please verify %installer_ver% is a valid tag for %product%
    echo.
    exit /b 1
  )
  if %self_contained% == 1 (
    pushd %product%
    echo ...packaging up all of the requisite gems into %product%/vendors/cache
    if not exist Gemfile.lock ( call bundle.bat install --without="test build" )
    call bundle.bat install --deployment
    call bundle.bat package
    popd
  )

  REM Unpack the measures project and prepare it accordingly.
  mkdir measures
  "%tarcmd%" --strip-components=1 -C measures -xf .\measures-%measures_tag%.tgz > nul 2> nul
  if ERRORLEVEL 1 (
    echo.
    echo *** There is a problem with the tar file measures-%measures_tag%.tgz
    echo Please verify %measures_tag% is a valid tag for measures
    echo.
    exit /b 1
  )
  if %self_contained% == 1 (
    pushd measures
    echo ...packaging up all of the requisite gems into measures/vendors/cache
    if not exist Gemfile.lock ( call bundle.bat install --without="test build" )
    call bundle.bat install --deployment
    call bundle.bat package
    popd
  )

  REM Unpack patient-importer and prepare it accordingly.
  echo ...unpacking and preparing patient-importer
  mkdir patient-importer
  "%tarcmd%" --strip-components=1 -C patient-importer -xf .\patient-importer-%patient-importer_tag%.tgz > nul 2> nul
  if ERRORLEVEL 1 (
    echo.
    echo *** There is a problem with the tar file patient-importer-%patient-importer_tag%.tgz
    echo Please verify %patient-importer_tag% is a valid tag for the patient importer
    echo.
    exit /b 1
  )

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

  REM Build all the native gems we need to include.
  if exist binary_gems ( 
    echo ...removing existing binary_gems directory 
    rd /s /q binary_gems
  )
  echo ...building all the native gems required
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
)

REM ==========================================================================
REM GENERATE
REM ==========================================================================
if %generate% == 1 (
  echo ------
  echo Step 4 Generate the windows installer using NSIS
  echo ------

  echo ...determining how much space will be needed for %product%
  set size=
  du --summarize --total %product% measures patient-importer | findstr total > foo.tmp
  set /p tempsize= < foo.tmp
  REM trim off the size portion
  for /f "tokens=1,2 delims=/	" %%a in ("%tempsize%") do set size=%%a
  del foo.tmp
  
  REM Run makensis to build product installer
  echo ...constructing the commandline to invoke NSIS
  "%makensiscmd%" /DBUILDARCH=%arch% /DINSTALLER_VER=%installer_ver% /DPRODUCT_NAME=%product% /DPRODUCT_SIZE=%size%  main.nsi
  echo.
  echo --------------------------------------------------------------------------------
  if %arch%==32 (
    echo Installer is available for testing: %product%-%installer_ver%-i386.exe
  ) else (
    echo Installer is available for testing: %product%-%installer_ver%-x86_64.exe
  )
  echo --------------------------------------------------------------------------------
  echo.
)
