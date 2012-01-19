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

set myarch=32

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
		  echo Usage: %0 [32^|64]
		  exit /b 1
		)
	  )
	)
)

echo Preparing to build a %myarch%-bit installer...

REM We need unzip and makensis on the path.  Check for 'em
set unzipcmd=
set makensiscmd=
for %%e in (%PATHEXT%) do (
  for %%x in (unzip%%e) do (
    if not defined unzipcmd (set unzipcmd=%%~$PATH:x)
  )
)
if "%unzipcmd%"=="" (
  echo unzip command was not found on the path.  Please correct.
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

REM ==========================================================================
REM Let's get to work!
REM ==========================================================================

REM ------
REM These steps need to be done regardless of the architecture
REM ------

REM Unpack redis and prepare it accordingly.
echo Unpacking and preparing redis...
set redisdir=redis-2.4.0
if exist %redisdir% ( rd /s /q %redisdir% )
mkdir %redisdir%
"%unzipcmd%" .\redis-2.4.0-win32-win64.zip -d %redisdir%
REM Copy our slightly modified redis.conf file into place
copy redis.conf %redisdir%\32bit
copy redis.conf %redisdir%\64bit
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
  "%unzipcmd%" .\mongodb-win32-i386-2.0.1.zip
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
"%makensiscmd%" /DBUILDARCH=%myarch% popHealth.nsi
