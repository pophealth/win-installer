; main.nsi
;
; This script will install the system passed in as PRODUCT_NAME (with all 
; dependencies) and configure so that the application is available after
; the next system boot.  It also sets up an uninstaller so that the user 
; can remove the application completely if desired.

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

; Make sure the product name is defined
!ifndef PRODUCT_NAME
  !error "Must provide the name of the product. i.e. /DPRODUCT_NAME=[popHealth|Cypress]"
!endif

; Make sure the installer version number is defined
!ifndef INSTALLER_VER
  !error "Must provide installer version. i.e. /DINSTALLER_VER=<ver_num>"
!endif

; Make sure the size required for the product is defined
!ifndef PRODUCT_SIZE
  !error "Must provide the size of product. i.e. /DPRODUCT_SIZE=<num_kb>"
!endif

; The file to write
;OutFile "<PRODUCT_NAME>-i386.exe"
!ifndef BUILDARCH
  !define BUILDARCH 32
!endif
!if ${BUILDARCH} = 32
OutFile "${PRODUCT_NAME}-${INSTALLER_VER}-i386.exe"
!else
OutFile "${PRODUCT_NAME}-${INSTALLER_VER}-x86_64.exe"
!endif
!echo "BUILDARCH = ${BUILDARCH}"

; Registry key to check for directory (so if you install again, it will
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\${PRODUCT_NAME}" "Install_Dir"

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
!define env_allusers 'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
!if ${BUILDARCH} = 32
  !define ruby_key 'HKLM "software\RubyInstaller\MRI\1.9.2" "InstallLocation"'
!else
  !define ruby_key 'HKLM "software\Wow6432Node\RubyInstaller\MRI\1.9.2" "InstallLocation"'
!endif

; The name of the installer
Name "${PRODUCT_NAME}"

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
  ; Make sure Windows knows about the change
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
!macroend

; This macro adds an environment variable to the registry for all users, and
; adds it to the environment of the installer and sub-processes
!macro EnvVarEverywhere Name Value
  !insertmacro AddEnvVarToReg '${Name}' '${Value}'
  !insertmacro SetInstallerEnvVar '${Name}' '${Value}'
!macroend

!macro SetRubyDir
  StrCpy $rubydir "$systemdrive\Ruby192"
  push $0
  ReadRegStr $0 ${ruby_key}
  StrCmp $0 "" +2
  StrCpy $rubydir $0
  pop $0
!macroend

!macro CheckRubyInstalled Yes No
  !insertmacro SetRubyDir
  IfFileExists "$rubydir\bin\ruby.exe" ${Yes} ${No}
!macroend

; Usage:
; ${Trim} $trimmedString $originalString
!define Trim "!insertmacro Trim"
!macro Trim ResultVar String
  Push "${String}"
  Call Trim
  Pop "${ResultVar}"
!macroend

;--------------------------------
;Interface Settings

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP ${PRODUCT_NAME}MiniLogo.bmp
!define MUI_ABORTWARNING
XPStyle on

Var Dialog
var systemdrive ;Set the primary drive letter for the system
var rubydir    ; The root directory of the ruby install to use
var mongodir   ; The root directory of the mongodb install
var redisdir   ; The root directory of the redis install

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
  WriteRegStr HKLM SOFTWARE\${PRODUCT_NAME} "Install_Dir" "$INSTDIR"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoRepair" 1
  WriteUninstaller "uninstall.exe"
  
SectionEnd

;-----------------------------------------------------------------------------
; Start Menu Shortcuts
;
; Registers a Start Menu shortcut for the application uninstaller and another
; to launch a web browser into the web application.
;-----------------------------------------------------------------------------
Section "Start Menu Shortcuts" sec_startmenu

  SectionIn 1 2 3

  SetOutPath $INSTDIR

  ; Create an Internet shortcut for the web app
  WriteINIStr "$INSTDIR\${PRODUCT_NAME}.URL" "InternetShortcut" "URL" "http://localhost:3000/"

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_NAME}.URL" "" "" ""
  
SectionEnd

SectionGroup "Required 3rd party software"
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

  ;Check if ruby exists
  !insertmacro CheckRubyInstalled 0 installruby
  
  ;Ruby was found
  MessageBox MB_ICONQUESTION|MB_YESNO "A current ruby installation was found.  Do you want to install it again?$\n$\n\
      Current install location: $0" /SD IDNO IDNO rubydone
  
  ;Ruby not found
  installruby:	
  SetOutPath $INSTDIR\depinstallers ; temporary directory

  File "rubyinstaller-1.9.2-p290.exe"
  ExecWait '"$INSTDIR\depinstallers\rubyinstaller-1.9.2-p290.exe" /verysilent /tasks="assocfiles,modpath"'
  Delete "$INSTDIR\depinstallers\rubyinstaller-1.9.2-p290.exe"

  ;Make sure ruby was installed
  !insertmacro CheckRubyInstalled rubydone 0
  MessageBox MB_ICONEXCLAMATION|MB_RETRYCANCEL 'We could not verify that ruby was properly installed' \
  IDRETRY installruby

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
; MongoDB
;
; Installs and registers mongodb to runs as a native Windows service.  Since
; this program is distributed as a zip file, it is unpackaged and included
; directly in the installer. The service is also started so that we
; can use MongoDB later in the installer.
;-----------------------------------------------------------------------------
Section "Install MongoDB" sec_mongodb

  SectionIn 1 3                  ; enabled in Full and Custom installs

  SetOutPath "$systemdrive\mongodb-2.0.1"

  File /r mongodb-2.0.1\*.*

  ; Create a data directory for mongodb
  SetOutPath $systemdrive\data\db

  ; Install the mongodb service
  ExecWait '"$mongodir\bin\mongod" --logpath $systemdrive\data\logs --logappend --dbpath $systemdrive\data\db --directoryperdb --install'

  ; Start the mongodb service
  ExecWait 'net.exe start "Mongo DB"'
SectionEnd

;-----------------------------------------------------------------------------
; Redis
;
; Installs the redis server.  This program is distributed as a zip file, so
; it is unpackage and included directly in the installer.  Once
; installed, a scheduled task with a boot trigger is registered.  This will
; result in the redis server being started every time the machine is rebooted.
;-----------------------------------------------------------------------------
Section "Install Redis" sec_redis

  SectionIn 1 3                  ; enabled in Full and Custom installs

  SetOutPath "$redisdir"

  File /r redis-2.4.0\*.*

  SetOutPath "$redisdir\${BUILDARCH}bit"
  ; start up redis so that the initial evaluation of measures can be performed
  ExecShell "open" "redis-server.exe" "redis.conf" SW_HIDE

  ; Install a scheduled task to start redis on system boot
  push "${PRODUCT_NAME} Redis Server"
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

SectionGroupEnd
; end "Third party software"

;-----------------------------------------------------------------------------
; Include the product-specific Section definitions
;-----------------------------------------------------------------------------
!include ${PRODUCT_NAME}.nsh

;-----------------------------------------------------------------------------
; Resque Workers
;
; This section installs a batch file that will start the resque workers and
; schedules a task with a boot trigger so that the workers are always started
; when the system boots up.
;
; It should appear after the main web application's Section so that the script
; directory is available
;-----------------------------------------------------------------------------
Section "Install resque workers" sec_resque

  SectionIn 1 3                  ; enabled in Full and Custom installs

  ; Set output path to the product web app's script directory
  SetOutPath $INSTDIR\${PRODUCT_NAME}\script

  ; Install the batch file that starts the workers.
  File "run-resque.bat"

  ; start up the resque workers so that the initial evaluation of measures 
  ; can be performed
  ExecShell "open" "run-resque.bat" "" SW_HIDE

  ; Install the scheduled service to run the resque workers on startup.
  push "${PRODUCT_NAME} Resque Workers"
  push "Run the resque workers for the ${PRODUCT_NAME} application."
  push "PT45S"
  push "$INSTDIR\${PRODUCT_NAME}\script\run-resque.bat"
  push ""
  push "$INSTDIR\${PRODUCT_NAME}"
  push "Local Service"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling resque workers task: $0"
  SetRebootFlag true
SectionEnd

;--------------------------------
; Descriptions

  ;Language strings
  LangString DESC_sec_uninstall       ${LANG_ENGLISH} "Provides ability to uninstall ${PRODUCT_NAME}"
  LangString DESC_sec_startmenu       ${LANG_ENGLISH} "Start Menu shortcuts"
  LangString DESC_sec_ruby            ${LANG_ENGLISH} "Ruby scripting language"
  LangString DESC_sec_bundler         ${LANG_ENGLISH} "Ruby Bundler gem"
  LangString DESC_sec_mongodb         ${Lang_ENGLISH} "MongoDB database server"
  LangString DESC_sec_redis           ${LANG_ENGLISH} "Redis server"
  LangString DESC_sec_resque          ${LANG_ENGLISH} "${PRODUCT_NAME} resque workers"
  LangString DESC_sec_webserver       ${LANG_ENGLISH} "${PRODUCT_NAME} web application"
  LangString DESC_sec_samplepatients  ${LANG_ENGLISH} "Generates sample patient records"

  LangString ProxyPage_Title          ${LANG_ENGLISH} "Proxy Server Settings"
  LangString ProxyPage_SUBTITLE       ${LANG_ENGLISH} "Specify the name of the proxy server used to access the Internet"

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_uninstall}       $(DESC_sec_uninstall)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_startmenu}       $(DESC_sec_startmenu)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_ruby}            $(DESC_sec_ruby)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_bundler}         $(DESC_sec_bundler)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_mongodb}         $(DESC_sec_mongodb)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_redis}           $(DESC_sec_redis)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_resque}          $(DESC_sec_resque)

    ; each product defines its own section for teh webserver and samplepatients
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_webserver}        $(DESC_sec_webserver)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_samplepatients}  $(DESC_sec_samplepatients)

    ; additional sections for patient importer
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_java}            $(DESC_sec_java)
    !insertmacro MUI_DESCRIPTION_TEXT ${sec_patientimporter} $(DESC_sec_patientimporter)
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
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
  DeleteRegKey HKLM SOFTWARE\${PRODUCT_NAME}

  ; Uninstall the resque worker scheduled task
  ExecWait 'schtasks.exe /end /tn "${PRODUCT_NAME} Resque Workers"'
  push "${PRODUCT_NAME} Resque Workers"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Resque Workers task: $0"

  ; Uninstall web application
  ExecWait 'schtasks.exe /end /tn "${PRODUCT_NAME} Web Server"'
  push "${PRODUCT_NAME} Web Server"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Web Server task: $0"
  RMDIR /r $INSTDIR\${PRODUCT_NAME}

  ; Uninstall quality measures
  RMDIR /r $INSTDIR\measures

  ; Uninstall redis
  ; Stop task and remove scheduled task.
  ExecWait 'schtasks.exe /end /tn "${PRODUCT_NAME} Redis Server"'
  push "${PRODUCT_NAME} Redis Server"
  Call un.DeleteTask
  pop $0
  DetailPrint "Results of deleting Redis Server task: $0"
  RMDIR /r "$redisdir"

  ; Uninstall mongodb
  ExecWait '"$mongodir\bin\mongod" --remove'
  RMDIR /r "$mongodir"

  ; Uninstall the Bundler gem
  ExecWait "gem.bat uninstall -x bundler"

  ; Uninstall Java JRE
  ; TODO: Did we really installer it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed Java.  Do you want us to uninstall it?' \
      /SD IDYES IDNO skipjavauninst
    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{26A24AE4-039D-4CA4-87B4-2F83217003FF}" \
      "UninstallString"
    ExecWait '$0'
  skipjavauninst:

  ; Uninstall ruby -- Should we do a silent uninstall
  ; TODO: Did we really install it?
  MessageBox MB_ICONINFORMATION|MB_YESNO 'We installed Ruby.  Do you want us to uninstall it?' \
      /SD IDYES IDNO skiprubyuninst
    ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{BD5F3A9C-22D5-4C1D-AEA0-ED1BE83A1E67}_is1" \
        "UninstallString"
    ExecWait '$0 /silent'
  skiprubyuninst:

  ; Remove files and uninstaller
  Delete $INSTDIR\uninstall.exe
  Delete $INSTDIR\${PRODUCT_NAME}.URL

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  RMDir "$INSTDIR\depinstallers"
  RMDIR "$INSTDIR\${PRODUCT_NAME}"
  RMDir "$INSTDIR"

SectionEnd

;=============================================================================
; UTILITY FUNCTIONS
;=============================================================================

; Trim
;   Removes leading & trailing whitespace from a string
; Usave:
;   Push
;   Call Trim
;   Pop
Function Trim
  Exch $R1 ; Original string
  Push $R2

Loop:
  StrCpy $R2 "$R1" 1
  StrCmp "$R2" " " TrimLeft
  StrCmp "$R2" "$\r" TrimLeft
  StrCmp "$R2" "$\n" TrimLeft
  StrCmp "$R2" "$\t" TrimLeft
  Goto Loop2
TrimLeft:
  StrCpy $R1 "$R1" "" 1
  Goto Loop

Loop2:
  StrCpy $R2 "$R1" 1 -1
  StrCmp "$R2" " " TrimRight
  StrCmp "$R2" "$\r" TrimRight
  StrCmp "$R2" "$\n" TrimRight
  StrCmp "$R2" "$\t" TrimRight
  Goto Done
TrimRight:
  StrCpy $R1 "$R1" -1
  Goto Loop2

Done:
  Pop $R2
  Exch $R1
FunctionEnd

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
var tmp

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
  ${If} $useProxy == 1
    ${NSD_GetText} $proxyServerText $tmp
    ${Trim} $proxyServer $tmp
    ${NSD_GetText} $proxyPortText $tmp
    ${Trim} $proxyPort $tmp
    
    ; Ensure that the proxy server is set
    StrCmp $proxyServer '' 0 +3
      MessageBox MB_OK|MB_ICONEXCLAMATION "Proxy server cannot be blank!"
      Abort
    push $0
    StrCpy $0 'http://$proxyServer'
    
    ; Append :port only if port is set
    StrCmp $proxyPort '' +2
      StrCpy $0 '$0:$proxyPort'

    ; This will permanently set the environment variable for future use
    !insertmacro AddEnvVarToReg 'http_proxy' $0
    !insertmacro AddEnvVarToReg 'https_proxy' $0

    ; We will also need these environment variables defined for later install tasks
    !insertmacro SetInstallerEnvVar 'http_proxy' $0
    !insertmacro SetInstallerEnvVar 'https_proxy' $0
    pop $0
  ${EndIf}
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
  StrCpy $systemdrive $WINDIR 2
  StrCpy $INSTDIR "$systemdrive\MITRE\${PRODUCT_NAME}"

  !insertmacro SetRubyDir
  StrCpy $mongodir "$systemdrive\mongodb-2.0.1"
  StrCpy $redisdir "$systemdrive\redis-2.4.0"
FunctionEnd

Function un.onInit
  StrCpy $systemdrive $WINDIR 2
  StrCpy $mongodir "$systemdrive\mongodb-2.0.1"
  StrCpy $redisdir "$systemdrive\redis-2.4.0"
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
