;-----------------------------------------------------------------------------
; Post-install steps
;
; This section adds the Test Deck patient records to the mongo database so that
; there is data to work with as soon as the installer finishes.
; It also runs the quality measure engine on the test deck.
;-----------------------------------------------------------------------------
Section "Post-Install steps" sec_postinstall

  SectionIn 1 3                  ; enabled in Full and Custom installs

  SetOutPath "$redisdir\${BUILDARCH}bit"
  ; start up redis so that the initial evaluation of measures can be performed
  ExecShell "open" "redis-server.exe" "redis.conf" SW_HIDE

  ; Set output path to the product web app's script directory
  SetOutPath $INSTDIR\${PRODUCT_NAME}\script
  ; start up the resque workers so that the initial evaluation of measures 
  ; can be performed
  ExecShell "open" "run-resque.bat" "" SW_HIDE

  ; Set output path to the measures directory
  SetOutPath $INSTDIR\measures

  ; Define an environment variable for the database to use
  !insertmacro EnvVarEverywhere 'DB_NAME' 'cypress_development'

  ; Load the quality measure definitions
  ExecWait 'bundle.bat exec rake mongo:reload_bundle'

  ; seed with test deck
  ; Set output path to the ${PRODUCT_NAME} directory
  SetOutPath $INSTDIR\${PRODUCT_NAME}
  ;ExecWait 'bundle.bat exec rake mpl:initalize RAILS_ENV=${mode}'
  ExecWait 'bundle.bat exec rake mpl:load'
  ExecWait 'bundle.bat exec rake mpl:eval'
SectionEnd
