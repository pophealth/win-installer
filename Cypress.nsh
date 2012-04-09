SectionGroup "Cypress"
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
  File /r Cypress

  ; Install required native gems
  SetOutPath $INSTDIR\depinstallers ; temporary directory
  File /r binary_gems
  ExecWait '"$rubydir\bin\gem.bat" install binary_gems\bson_ext-1.5.1-x86-mingw32.gem'
  ExecWait '"$rubydir\bin\gem.bat" install binary_gems\json-1.4.6-x86-mingw32.gem'
  RMDIR /r $INSTDIR\depinstallers\binary_gems

  SetOutPath "$INSTDIR\Cypress"
  ExecWait 'bundle.bat install'

  ; Install a scheduled task to start a web server on system boot
  push "Cypress Web Server"
  push "Run the web server that allows access to the Cypress application."
  push "PT1M30S"
  push "$rubydir\bin\ruby.exe"
  push "script/rails server -p 3000"
  push "$INSTDIR\Cypress"
  push "System"
  Call CreateTask
  pop $0
  DetailPrint "Result of scheduling Web Server task: $0"
  SetRebootFlag true
SectionEnd

;-----------------------------------------------------------------------------
; Patient Records
;
; This section adds the Test Deck patient records to the mongo database so that
; there is data to work with as soon as the installer finishes.
;-----------------------------------------------------------------------------
Section "Install patient records" sec_samplepatients

  SectionIn 1 3                  ; enabled in Full and Custom installs

  ; Set output path to the measures directory
  SetOutPath $INSTDIR\measures

  ; Define an environment variable for the database to use
  !insertmacro EnvVarEverywhere 'DB_NAME' 'cypress_development'

  ; Load the quality measure definitions
  ExecWait 'bundle.bat exec rake mongo:reload_bundle'

  ; seed with test deck
  ; Set output path to the Cypress directory
  SetOutPath $INSTDIR\Cypress
  ;ExecWait 'bundle.bat exec rake mpl:initalize RAILS_ENV=${mode}'
  ExecWait 'bundle.bat exec rake mpl:load'
  ExecWait 'bundle.bat exec rake mpl:eval'
SectionEnd

SectionGroupEnd
; end "Cypress"
