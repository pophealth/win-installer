
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
; End Patient Importer" group

;-----------------------------------------------------------------------------
; Post-install steps
;
; This section adds 500 random patient records to the mongo database so that
; there is data to play around with as soon as the installer finishes.
; An admin account is also set up in the database.
;-----------------------------------------------------------------------------
Section "Post-install steps" sec_postinstall

  SectionIn 1 3                  ; enabled in Full and Custom installs

  ; Set output path to the measures directory
  SetOutPath $INSTDIR\measures

  ; Define an environment variable for the database to use
  !insertmacro EnvVarEverywhere 'DB_NAME' 'pophealth-development'

  ; Load the quality measure definitions
  ExecWait 'bundle.bat exec rake mongo:reload_bundle'

  ; seed the patients
  ExecWait 'bundle.bat exec rake patient:random[500]'

  ; Create admin user account
  SetOutPath $INSTDIR\popHealth
  ExecWait 'bundle.bat exec rake admin:create_admin_account'

SectionEnd


LangString DESC_sec_patientimporter ${LANG_ENGLISH} "Patient importer"
LangString DESC_sec_java	    ${LANG_ENGLISH} "Java runtime environment"
