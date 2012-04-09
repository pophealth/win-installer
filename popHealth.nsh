
SectionGroup "popHealth"
;-----------------------------------------------------------------------------
; Web Application
;
; This section copies the Web Application onto the system.  This
; also installs a scheduled task with a boot trigger that will start a web
; server so that the application can be accessed when the system is booted.
;-----------------------------------------------------------------------------
Section "${PRODUCT_NAME} Web Application" sec_webserver

  SectionIn RO
  AddSize ${PRODUCT_SIZE}        ; current size of cloned repo (in kB)

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  File /r ${PRODUCT_NAME}

  ; Install required native gems
  SetOutPath $INSTDIR\depinstallers ; temporary directory
  File /r binary_gems
  ExecWait '"$rubydir\bin\gem.bat" install binary_gems\bson_ext-1.5.1-x86-mingw32.gem'
  ExecWait '"$rubydir\bin\gem.bat" install binary_gems\json-1.4.6-x86-mingw32.gem'
  RMDIR /r $INSTDIR\depinstallers\binary_gems

  SetOutPath "$INSTDIR\${PRODUCT_NAME}"
  ExecWait 'bundle.bat install'

  ; Create admin user account
  ExecWait 'bundle.bat exec rake admin:create_admin_account'

  ; Install a scheduled task to start a web server on system boot
  push "${PRODUCT_NAME} Web Server"
  push "Run the web server that allows access to the ${PRODUCT_NAME} application."
  push "PT1M30S"
  push "$rubydir\bin\ruby.exe"
  push "script/rails server -p 3000"
  push "$INSTDIR\${PRODUCT_NAME}"
  push "System"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling Web Server task: $0"
  SetRebootFlag true
SectionEnd

SectionGroup "Patient Importer"
;-----------------------------------------------------------------------------
; Patient Importer
;
; This section copies the patient importer client onto the system
;   - the required components are 
;     a JRE 
;     the patient-importer code
;-----------------------------------------------------------------------------
Section "Patient Importer application" sec_patientimporter

  SectionIn RO

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  File /r patient-importer

  ; Install a Start Menu item for the client.
  SetOutPath $INSTDIR\patient-importer
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\importer.lnk" \
    "$INSTDIR\patient-importer\start_importer.bat" "" "" "" \
    SW_SHOWMINIMIZED ALT|CONTROL|SHIFT|F5 "Patient Importer Utility"
SectionEnd

;-----------------------------------------------------------------------------
; Java JRE
;
; Runs the Java JRE install program and waits for it to finish.
; TODO: Should detect if a jvm is already installed.
; TODO: Should record somehow if we actually install this so that the
;       uninstaller can remove it.
;-----------------------------------------------------------------------------
Section "Install Java JRE" sec_java

  SectionIn 1 3			; enabled in Full and Custom installs
  AddSize 75250			; additional size in kB above installer

  SetOutPath $INSTDIR\depinstallers	; temporary directory

  MessageBox MB_ICONINFORMATION|MB_OKCANCEL 'We will now install a Java interpreter.' \
    /SD IDOK IDCANCEL javadone

  Var /GLOBAL jre_installer_name
  !if ${BUILDARCH} = 32
    StrCpy $jre_installer_name "jre-7u3-windows-i586.exe"
    File "jre-7u3-windows-i586.exe"
  !else
    StrCpy $jre_installer_name "jre-7u3-windows-x64.exe"
    File "jre-7u3-windows-x64.exe"
  !endif
  ExecWait '"$INSTDIR\depinstallers\$jre_installer_name"'
  Delete "$INSTDIR\depinstallers\$jre_installer_name"

  javadone:
SectionEnd

SectionGroupEnd


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
  !insertmacro EnvVarEverywhere 'DB_NAME' 'pophealth-development'

  ; Load the quality measure definitions
  ExecWait 'bundle.bat exec rake mongo:reload_bundle'

  ; seed the patients
  ExecWait 'bundle.bat exec rake patient:random[500]'
SectionEnd

SectionGroupEnd
; End "popHealth" group


LangString DESC_sec_patientimporter ${LANG_ENGLISH} "Patient importer"
LangString DESC_sec_java	    ${LANG_ENGLISH} "Java runtime environment"
