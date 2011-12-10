; popHealth.nsi
;
; This script will install the popHealth system (with all dependencies) and
; configure so that the popHealth application is available after the next
; system boot.  It also sets up an uninstaller so that the user can remove the
; application completely if desired.

;--------------------------------

; Use the lzma compression algorithm for maximum compression
SetCompressor /solid lzma

;--------------------------------
; Include files

!include "LogicLib.nsh"
!include "MUI2.nsh"
!include "scheduletask.nsh"

;--------------------------------

; Only install on Windows XP or more recent (option not supported yet)
;TargetMinimalOS 5.1

; The name of the installer
Name "popHealth"

; The file to write
;OutFile "popHealth-i386.exe"
!ifndef BUILDARCH
  !define BUILDARCH 32
!endif
!if ${BUILDARCH} = 32
OutFile "popHealth-i386.exe"
!define jrubyinst "jruby_windowsjre_1_6_4.exe"
!else
OutFile "popHealth-x86_64.exe"
!define jrubyinst "jruby_windows_x64_jre_1_6_4.exe"
!endif

!echo "BUILDARCH = ${BUILDARCH}"
!echo "jrubyinst = ${jrubyinst}"

; The default installation directory
; TODO: change this to C:\projects for final version.
InstallDir C:\proj\popHealth

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\popHealth" "Install_Dir"

; Request application privileges for Windows Vista
RequestExecutionLevel admin

; Install types we support: full, minimal, custom (provided automatically)
InstType "Full"
InstType "Minimal"

; License settings
LicenseForceSelection checkbox "I accept"
;LicenseText
LicenseData license.txt

;--------------------------------
; Some useful defines
!define env_allusers 'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"';

;--------------------------------
; Some useful macros

; This macro sets an environment variable temporarily for the installer and sub-processes
!macro SetInstallerEnvVar Name Value
  System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("${Name}", "${Value}").r0'
  StrCmp $0 0 0 +2
    MessageBox MB_OK "Failed to set environment variable '${Name}'"
!macroend

; This macro adds an environment variable to the registry for all users
!macro AddEnvVarToReg Name Value
  WriteRegExpandStr ${env_allusers} '${Name}' '${Value}'
!macroend

; This macro adds an environment variable to the registry for all users, and
; adds it to the environment of the installer and sub-processes
!macro EnvVarEverywhere Name Value
  !insertmacro AddEnvVarToReg '${Name}' '${Value}'
  !insertmacro SetInstallerEnvVar '${Name}' '${Value}'
!macroend

;--------------------------------
;Interface Settings

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP popHealthMiniLogo.bmp
!define MUI_ABORTWARNING
XPStyle on

Var Dialog
var rubydir    ; The root directory of the ruby install to use
var mongodir   ; The root directory of the mongodb install
var redisdir   ; The root directory of the redis install
var gitdir     ; The root directory of the git install

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
;Page license
!insertmacro MUI_PAGE_LICENSE license.txt
;Page components
!insertmacro MUI_PAGE_COMPONENTS
;Page directory
!insertmacro MUI_PAGE_DIRECTORY

Page custom ProxySettingsPage ProxySettingsLeave

;Page instfiles
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
;UninstPage uninstConfirm
!insertmacro MUI_UNPAGE_CONFIRM
UnInstPage custom un.ProxySettingsPage
;UninstPage instfiles
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "English"

;=============================================================================
; INSTALLER SECTIONS
;
; The order of the sections determines the order that they will be listed in
; the Components page.
;=============================================================================

;-----------------------------------------------------------------------------
; Uninstaller
;
; Creates and registers an uninstaller for application removal.
;-----------------------------------------------------------------------------
Section "Create Uninstaller" sec_uninstall

  SectionIn RO
  
  SetOutPath $INSTDIR

  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\popHealth "Install_Dir" "$INSTDIR"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\popHealth" "DisplayName" "popHealth"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\popHealth" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\popHealth" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\popHealth" "NoRepair" 1
  WriteUninstaller "uninstall.exe"
  
SectionEnd

;-----------------------------------------------------------------------------
; Start Menu Shortcuts
;
; Registers a Start Menu shortcut for the application uninstaller and another
; to launch a web browser into the popHealth web application.
;-----------------------------------------------------------------------------
Section "Start Menu Shortcuts" sec_startmenu

  SectionIn 1 2 3

  SetOutPath $INSTDIR

  ; Create an Internet shortcut for popHealth web app
  WriteINIStr "$INSTDIR\popHealth.URL" "InternetShortcut" "URL" "http://localhost:3000/"

  CreateDirectory "$SMPROGRAMS\popHealth"
  CreateShortCut "$SMPROGRAMS\popHealth\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  CreateShortCut "$SMPROGRAMS\popHealth\popHealth.lnk" "$INSTDIR\popHealth.URL" "" "" ""
  
SectionEnd

;-----------------------------------------------------------------------------
; Git
;
; Runs the Git install program and waits for it to finish.
; TODO: Need to record somehow whether we actually install this so that the
;       uninstaller can remove it.
;-----------------------------------------------------------------------------
Section "Install Git" sec_git

  SectionIn 1 3                  ; enabled in Full and Custom installs
  AddSize 54682                  ; additional size in kB above installer

  SetOutPath $INSTDIR\depinstallers ; temporary directory

  MessageBox MB_ICONINFORMATION|MB_OKCANCEL 'We will now install Git.  On the sixth dialog, select \
      "Run Git from the Windows  Command Prompt". Just click "Next" on all other dialogs.' /SD IDOK IDCANCEL skipgit
    File "Git-1.7.7-preview20111014.exe"
    ExecWait '"$INSTDIR\depinstallers\Git-1.7.7-preview20111014.exe"'
    Delete "$INSTDIR\depinstallers\Git-1.7.7-preview20111014.exe"
  skipgit:

  ; We need a git install.  If we don't find git where we expect, ask user
  IfFileExists "$gitdir\cmd\git.cmd" gitdone 0
    ; TODO: Need to prompt the user to tell us where git is installed.
    MessageBox MB_ICONEXCLAMATION|MB_OK "Git not found!"
  gitdone:
  Push "$gitdir\cmd"
  Call AddToPath
SectionEnd

;-----------------------------------------------------------------------------
; Ruby
;
; Runs the Ruby install program and waits for it to finish.
; TODO: Need to record somehow whether we actually install this so that the
;       uninstaller can remove it.
;-----------------------------------------------------------------------------
Section "Install Ruby" sec_ruby

  SectionIn 1 3                  ; enabled in Full and Custom installs
  AddSize 18534                  ; additional size in kB above installer

  SetOutPath $INSTDIR\depinstallers ; temporary directory

  MessageBox MB_ICONINFORMATION|MB_OKCANCEL 'We will now install Ruby.  On the optional tasks dialog, select \
      "Add Ruby executables to your PATH"; and "Associate .rb files with this Ruby installation" boxes.' /SD IDOK \
      IDCANCEL skipruby
    File "rubyinstaller-1.9.2-p290.exe"
    ExecWait '"$INSTDIR\depinstallers\rubyinstaller-1.9.2-p290.exe"'
    Delete "$INSTDIR\depinstallers\rubyinstaller-1.9.2-p290.exe"
  skipruby:

  ; We need a ruby install.  If we don't find ruby where we expect, ask user
  IfFileExists "$rubydir\bin\ruby.exe" rubydone 0
    ; TODO Need to prompt the user to tell us where ruby is installed.
    MessageBox MB_ICONEXCLAMATION|MB_OK "Ruby not found!"
  rubydone:
  Push "$rubydir\bin"
  Call AddToPath
SectionEnd

;-----------------------------------------------------------------------------
; Bundler
;
; Installs the bundler gem for user later in the install.
;-----------------------------------------------------------------------------
Section "Install Bundler" sec_bundler

  SectionIn 1 3                  ; enabled in Full and Custom installs
  AddSize 3922                   ; additional size in kB above installer

  ClearErrors
  ExecWait '"$rubydir\bin\gem.bat" install bundler'
  IfErrors 0 +2
    MessageBox MB_ICONEXCLAMATION|MB_OK "Failed to install the bundler gem."
SectionEnd

;-----------------------------------------------------------------------------
; Ruby DevKit
;
; Unpacks the ruby development kit.  This component is required in order to
; build native ruby gems on Windows.
; TODO: If the required native gems are prebuilt and included in the installer
;       than this component could be removed.
;-----------------------------------------------------------------------------
Section "Install Ruby DevKit" sec_rdevkit

  SectionIn 1 3                  ; enabled in Full and Custom installs
  AddSize 145079                 ; additional size in kB above installer

  SetOutPath $INSTDIR\depinstallers ; temporary directory
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL 'We will now install the Ruby DevKit. Please accept all defaults \
      presented.' /SD IDOK IDCANCEL skiprdevkit
    File "DevKit-tdm-32-4.5.2-20110712-1620-sfx.exe"
    ClearErrors
    ExecWait '"$INSTDIR\depinstallers\DevKit-tdm-32-4.5.2-20110712-1620-sfx.exe" -oC:\DevKit'
    ; Change output directory to the DevKit directory
    SetOutPath C:\DevKit
    ; TODO: This presumes the user accepted the default when installing ruby.  The NSIS SearchPath command will not
    ;       help because it searches the path the installer inherited.
    ;       Even if ruby was added to the path during the earlier install, the popHealth installer is running with
    ;       the old path.  Another option might be to add a RunOnce script to do this devkit config step
    IfFileExists C:\Ruby192\bin\ruby.exe 0 rubynotfound
      ExecWait "C:\Ruby192\bin\ruby dk.rb init"
      IfErrors 0 +3
        DetailPrint 'Failed to setup devkit.  Will install RunOnce task.'
        Goto rubynotfound
      ExecWait "C:\Ruby192\bin\ruby dk.rb install"
      Goto donerdevkit
    rubynotfound:
      MessageBox MB_ICONEXCLAMATION|MB_OK 'Failed to find where ruby was installed'
      ; TODO: Add RunOnce task here.
      ; Fall through to clean up
    donerdevkit:
      Delete "$INSTDIR\depinstallers\DevKit-tdm-32-4.5.2-20110712-1620-sfx.exe"
  skiprdevkit:
    ClearErrors
SectionEnd

;-----------------------------------------------------------------------------
; JRuby
;
; Runs the JRuby install program and waits for it to finish.
;-----------------------------------------------------------------------------
Section "Install JRuby" sec_jruby

  SectionIn 1 3                  ; enabled in Full and Custom installs
  AddSize 67531                  ; additional size in kB above installer

  SetOutPath $INSTDIR\depinstallers ; temporary directory

  MessageBox MB_ICONINFORMATION|MB_OKCANCEL 'We will now install JRuby.  You may accept the defaults on all the \
      dialogs and click Next.  Click Finish on the last one.' /SD IDOK IDCANCEL skipjruby
    File "${jrubyinst}"
    ExecWait '"$INSTDIR\depinstallers\${jrubyinst}"'
    Delete "$INSTDIR\depinstallers\${jrubyinst}"
  skipjruby:
SectionEnd

;-----------------------------------------------------------------------------
; MongoDB
;
; Installs and registers mongodb to runs as a native Windows service.  Since
; this program is distributed as a zip file, it is unpackaged and included
; directly in the popHealth installer. The service is also started so that we
; can use MongoDB later in the installer.
;-----------------------------------------------------------------------------
Section "Install MongoDB" sec_mongodb

  SectionIn 1 3                  ; enabled in Full and Custom installs

  SetOutPath "C:\mongodb-2.0.1"

  File /r mongodb-2.0.1\*.*

  ; Create a data directory for mongodb
  SetOutPath c:\data\db

  ; Install the mongodb service
  ExecWait '"$mongodir\bin\mongod" --logpath C:\data\logs --logappend --dbpath C:\data\db --directoryperdb --install'

  ; Start the mongodb service
  ExecWait 'net.exe start "Mongo DB"'
SectionEnd

;-----------------------------------------------------------------------------
; Redis
;
; Installs the redis server.  This program is distributed as a zip file, so
; it is unpackage and included directly in the popHealth installer.  Once
; installed, a scheduled task with a boot trigger is registered.  This will
; result in the redis server being started every time the machine is rebooted.
;-----------------------------------------------------------------------------
Section "Install Redis" sec_redis

  SectionIn 1 3                  ; enabled in Full and Custom installs

  SetOutPath "$redisdir"

  File /r redis-2.4.0\*.*

  ; Install a scheduled task to start redis on system boot
  push "popHealth Redis Server"
  push "Run the redis server at startup."
  push "PT15S"
  push "$redisdir\${BUILDARCH}bit\redis-server.exe"
  push "redis.conf"
  push "$redisdir\${BUILDARCH}bit"
  push "Local Service"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling Redis Server task: $0"
  SetRebootFlag true
SectionEnd

;-----------------------------------------------------------------------------
; popHealth Quality Measures
;
; This section clones the github repository.  This approach requires us to
; install git on the system.
; TODO: When building the installer, pull the repo from github as a tar or zip
;       file and distribute that.
;-----------------------------------------------------------------------------
Section "popHealth Quality Measures" sec_qualitymeasures

  SectionIn RO
  AddSize 5887        ; current size of cloned repo (in kB)
  
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR

  ; clone the quality measures repository
  ExecWait 'git.cmd clone https://github.com/pophealth/measures.git'

  ; Install required gems
  SetOutPath $INSTDIR\measures
  ExecWait 'bundle.bat install'
SectionEnd

;-----------------------------------------------------------------------------
; popHealth Web Application
;
; This section clones the github repository.  This approach requires us to
; install git on the system. This also installs a scheduled task with a boot
; trigger that will start a web server so that the application can be accessed
; when the system is booted.
; TODO: When building the installer, pull the repo from github as a tar or zip
;       file and distribute that.
;-----------------------------------------------------------------------------
Section "popHealth Web Application" sec_popHealth

  SectionIn RO
  AddSize 37802        ; current size of cloned repo (in kB)

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR

  ; clone popHealth web application repository
  ExecWait 'git.cmd clone https://github.com/pophealth/popHealth.git'

  ; Install required gems
  SetOutPath $INSTDIR\popHealth
  ExecWait 'bundle.bat install --without="test develop"'
  ExecWait 'gem.bat install bson_ext -v 1.3.1'

  ; Create Environment variables needed for popHealth production env
  !insertmacro EnvVarEverywhere 'RAILS_ENV' 'production'
  !insertmacro EnvVarEverywhere 'MONGOID_DATABASE' 'pophealth-windows'

  ; Create admin user account
  ExecWait 'bundle.bat exec rake admin:create_admin_account'

  ; Install a scheduled task to start a web server on system boot
  push "popHealth Web Server"
  push "Run the web server that allows access to the popHealth application."
  push "PT1M30S"
  push "$rubydir\bin\bundle.bat"
  push "exec rails server"
  push "$INSTDIR\popHealth"
  push "System"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling Web Server task: $0"
  SetRebootFlag true
SectionEnd

;-----------------------------------------------------------------------------
; Resque Workers
;
; This section installs a batch file that will start the resque workers and
; schedules a task with a boot trigger so that the workers are always started
; when the system boots up.
;-----------------------------------------------------------------------------
Section "Install resque workers" sec_resque

  SectionIn 1 3                  ; enabled in Full and Custom installs

  ; Set output path to the popHealth web app's script directory
  SetOutPath $INSTDIR\popHealth\script

  ; Install the batch file that starts the workers.
  File "run-resque.bat"

  ; Install the scheduled service to run the resque workers on startup.
  push "popHealth Resque Workers"
  push "Run the resque workers for the popHealth application."
  push "PT45S"
  push "$INSTDIR\popHealth\script\run-resque.bat"
  push ""
  push "$INSTDIR\popHealth"
  push "Local Service"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling resque workers task: $0"
  SetRebootFlag true
SectionEnd

;-----------------------------------------------------------------------------
; Patient Records
;
; This section adds 500 random patient records to the mongo database so that
; there is data to play around with as soon as the installer finishes.
;-----------------------------------------------------------------------------
Section "Install patient records" sec_samplepatients

  SectionIn 1 3                  ; enabled in Full and Custom installs

  ; Set output path to the measures directory
  SetOutPath $INSTDIR\measures

  ; Define an environment variable for the database to use
  !insertmacro SetInstallerEnvVar 'DB_NAME' 'pophealth-windows'

  ; Generate records
  ExecWait 'bundle.bat exec rake mongo:reload_bundle'
  ExecWait 'bundle.bat exec rake patient:random[500]'
SectionEnd

;--------------------------------
; Descriptions

  ;Language strings
  LangString DESC_sec_uninstall ${LANG_ENGLISH} "Provides ability to uninstall popHealth"
  LangString DESC_sec_startmenu ${LANG_ENGLISH} "Start Menu shortcuts"
  LangString DESC_sec_git       ${LANG_ENGLISH} "Git revision control system"
  LangString DESC_sec_ruby      ${LANG_ENGLISH} "Ruby scripting language"
  LangString DESC_sec_bundler   ${LANG_ENGLISH} "Ruby Bundler gem"
  LangString DESC_sec_rdevkit   ${LANG_ENGLISH} "Ruby Development Kit"
  LangString DESC_sec_jruby     ${LANG_ENGLISH} "JRuby script interpreter"
  LangString DESC_sec_mongodb   ${Lang_ENGLISH} "MongoDB database server"
  LangString DESC_sec_redis     ${LANG_ENGLISH} "Redis server"
  LangString DESC_sec_qualitymeasures ${LANG_ENGLISH} "popHealth quality measure definitions"
  LangString DESC_sec_popHealth ${LANG_ENGLISH} "popHealth web application"
  LangString DESC_sec_resque    ${LANG_ENGLISH} "popHealth resque workers"
  LangString DESC_sec_samplepatients ${LANG_ENGLISH} "Generates 500 sample patient records"

  LangString ProxyPage_Title    ${LANG_ENGLISH} "Proxy Server Settings"
  LangString ProxyPage_SUBTITLE ${LANG_ENGLISH} "Specify the name of the proxy server used to access the Internet"

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_uninstall} $(DESC_sec_uninstall)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_startmenu} $(DESC_sec_startmenu)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_git} $(DESC_sec_git)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_ruby} $(DESC_sec_ruby)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_bundler} $(DESC_sec_bundler)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_rdevkit} $(DESC_sec_rdevkit)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_jruby} $(DESC_sec_jruby)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_mongodb} $(DESC_sec_mongodb)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_redis} $(DESC_sec_redis)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_qualitymeasures} $(DESC_sec_qualitymeasures)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_popHealth} $(DESC_sec_popHealth)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_resque} $(DESC_sec_resque)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_samplepatients} $(DESC_sec_samplepatients)
  !insertmacro MUI_FUNCTION_DESCRIPTION_END

;=============================================================================
; UNINSTALLER SECTION
;
; This should undo everyting done by the installer.
; TODO: Need to record exactly which components were installed so that we only
;       uninstall those same components.
;=============================================================================

Section "Uninstall"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\popHealth"
  DeleteRegKey HKLM SOFTWARE\popHealth

  ; Uninstall the resque worker scheduled task
  ExecWait 'schtasks.exe /end /tn "popHealth Resque Workers"'
  push "popHealth Resque Workers"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Resque Workers task: $0"

  ; Uninstall popHealth web application
  ExecWait 'schtasks.exe /end /tn "popHealth Web Server"'
  push "popHealth Web Server"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Web Server task: $0"
  RMDIR /r $INSTDIR\popHealth

  ; Uninstall popHealth quality measures
  RMDIR /r $INSTDIR\measures

  ; Uninstall redis
  ; Stop task and remove scheduled task.
  ExecWait 'schtasks.exe /end /tn "popHealth Redis Server"'
  push "popHealth Redis Server"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Redis Server task: $0"
  RMDIR /r "$redisdir"

  ; Uninstall mongodb
  ExecWait '"$mongodir\bin\mongod" --remove'
  RMDIR /r "$mongodir"

  ; Uninstall jruby -- Should we do a silent uninstall
  ; TODO: Did we really install it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed JRuby.  Do you want us to uninstall it?' \
      /SD IDYES IDNO skipjrubyuninst
    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\4535-5096-5383-5182" "UninstallString"
    ExecWait '$0'
  skipjrubyuninst:

  ; Uninstall ruby devkit -- Should we do a silent uninstall?
  ; TODO: Did we really install it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed the Ruby DevKit.  Do you want us to uninstall it?' \
    /SD IDYES IDNO skiprdevkituninst
    RMDIR /r "C:\DevKit"
  skiprdevkituninst:

  ; Uninstall the Bundler gem
  ExecWait "gem.bat uninstall -x bundler"

  ; Uninstall ruby -- Should we do a silent uninstall
  ; TODO: Did we really install it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed Ruby.  Do you want us to uninstall it?' \
      /SD IDYES IDNO skiprubyuninst
    ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{BD5F3A9C-22D5-4C1D-AEA0-ED1BE83A1E67}_is1" \
        "UninstallString"
    ExecWait '$0'
  skiprubyuninst:

  ; Uninstall git -- Should we do a silent uninstall
  ; TODO: Did we really install it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed Git.  Do you want us to uninstall it?' \
      /SD IDYES IDNO skipgituninst
    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Git_is1" "UninstallString"
    ExecWait '$0'
  skipgituninst:

  ; Remove files and uninstaller
  Delete $INSTDIR\uninstall.exe
  Delete $INSTDIR\popHealth.URL

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\popHealth\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\popHealth"
  RMDIR "$INSTDIR\popHealth"
  RMDir "$INSTDIR"

SectionEnd

;=============================================================================
; UTILITY FUNCTIONS
;=============================================================================

;--------------------------------
; Functions for Custom pages

; These are window handles of the controls in the Proxy Settings page
Var proxyTitleLabel
Var proxyServerLabel
Var proxyServerText
Var proxyPortLabel
var proxyPortText
var proxyUseProxyCheckbox

; Window handle of window a callback was invoked for
var hwnd

; Values the user entered in the Proxy Settings page
var useProxy
var proxyServer
var proxyPort

;-------------------
; Collect proxy info
Function ProxySettingsPage
  !insertmacro MUI_HEADER_TEXT $(ProxyPage_TITLE) $(ProxyPage_SUBTITLE)
  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 12u "Configure Proxy to Access the Internet:"
    pop $proxyTitleLabel

  ${NSD_CreateCheckBox} 0 13u 80u 12u "Use Proxy Server"
    pop $proxyUseProxyCheckbox
    ${NSD_OnClick} $proxyUseProxyCheckbox ProxySettingsUseProxyClick
    ${NSD_SetState} $proxyUseProxyCheckbox $useProxy

  ${NSD_CreateLabel} 0 28u 80u 12u "Http Proxy Server:"
    pop $proxyServerLabel
  ${NSD_CreateText} 90u 28u 100u 12u $proxyServer
    pop $proxyServerText
    EnableWindow $proxyServerText 0 # start out disabled

  ${NSD_CreateLabel} 0 43u 80u 12u "Port:"
    pop $proxyPortLabel
  ${NSD_CreateNumber} 90u 43u 100u 12u $proxyPort
    pop $proxyPortText
    EnableWindow $proxyPortText 0 # start out disabled

  nsDialogs::Show
FunctionEnd

Function ProxySettingsLeave
  ${NSD_GetState} $proxyUseProxyCheckbox $useProxy
  ${NSD_GetText} $proxyServerText $proxyServer
  ${NSD_GetText} $proxyPortText $proxyPort
  ;MessageBox MB_OK "You Entered:$\n  Use Proxy: $useProxy$\n  Server: $proxyServer$\n  Port: $proxyPort"
  ${If} $useProxy == 1
    ; This will permanently set the environment variable for future use of popHealth
    !insertmacro AddEnvVarToReg 'http_proxy' 'http://$proxyServer:$proxyPort/'
    !insertmacro AddEnvVarToReg 'https_proxy' 'http://$proxyServer:$proxyPort/'
    ; Make sure Windows knows about the change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

    ; We will also need these environment variables defined for later install tasks
    !insertmacro SetInstallerEnvVar 'http_proxy' 'http://$proxyServer:$proxyPort/'
    !insertmacro SetInstallerEnvVar 'https_proxy' 'http://$proxyServer:$proxyPort/'
  ${EndIf}
  ;Abort
FunctionEnd

Function ProxySettingsUseProxyClick
  pop $hwnd
  ${NSD_GetState} $hwnd $0
  ${If} $0 == 1
    EnableWindow $proxyServerText 1
    EnableWindow $proxyPortText 1
  ${Else}
    EnableWindow $proxyServerText 0
    EnableWindow $proxyPortText 0
  ${EndIf}
FunctionEnd

; This function removes the environment variable we might have installed
Function un.ProxySettingsPage
  DeleteRegValue ${env_allusers} 'http_proxy'
  DeleteRegValue ${env_allusers} 'https_proxy'
  ClearErrors
FunctionEnd

; This function is called when the installer starts.  It is used to initialize some
; needed variables
Function .onInit
  StrCpy $rubydir "C:\Ruby192"
  StrCpy $gitdir  "C:\Program Files\Git"
  StrCpy $mongodir "C:\mongodb-2.0.1"
  StrCpy $redisdir "C:\redis-2.4.0"
FunctionEnd
Function un.onInit
  StrCpy $mongodir "C:\mongodb-2.0.1"
  StrCpy $redisdir "C:\redis-2.4.0"
FunctionEnd

; This function adds the passed directory to the path (only for installer and subprocesses)
Function AddToPath
  ; Store registers and pop params
  System::Store "S r0"

  ; Get the current path
  ReadEnvStr $R1 PATH

  ; Add the new directory to the end of the path
  StrCpy $R1 "$0;$R1"

  ; Set the new path in the environment
;  System::Call "kernel32::SetEnvironmentVariable(t 'PATH', t R1) i.R9"
  !insertmacro SetInstallerEnvVar 'PATH' $R1

  ; restore registers
  System::Store "l"
FunctionEnd
