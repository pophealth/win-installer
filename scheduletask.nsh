; Provides a collection of functions that will use the Task Scheduler 1.0 or
; 2.0 API to schedule or delete a boot task.

!include "WinVer.nsh"

;=============================================================================
;                    GENERIC CREATE AND DELETE FUNCTIONS
;
; These are the functions that should be called by other scripts.  They will
; call the appropriate functions based on the windows version.
;=============================================================================

;===============================================================================
; Delete a previously scheduled task.
;
; This is provided as a macro so that it can also be called from the uninstaller
; (where the name has to start with "un.").  If calling from the installer, use
;    Call DeleteTask ""
; From the uninstaller, use:
;    Call un.DeleteTask
;
; Arguments:
;   - The name of the task used when the task was originally registered.
; Return Value:
;   This function returns an integer on the stack that should be popped off
;   after calling this function.  This value will be the return value of the
;   ITaskFolder->DeleteTask() call (0 indicates success.  Otherwise it is a
;   HRESULT error code.
;===============================================================================
!macro wrapDeleteTask un
Function ${un}DeleteTask
  ${If} ${AtMostWinXP}
    Call ${un}DeleteTaskV1
  ${Else}
    Call ${un}DeleteTaskV2
  ${EndIf}
FunctionEnd
!macroend
!insertmacro wrapDeleteTask ""
!insertmacro wrapDeleteTask "un."

;===============================================================================
; Create a new scheduled task to start at system boot time.
;
; Arguments: This function takes 7 string arguments that must be pushed onto the
;   stack in the following order before calling this function:
;   - The name that the task will have in the Task Scheduler
;   - A description of what the task does.
;   - Start delay.  This determines the amount of time from when the system is
;     booted to when the task will start.  The format for this string is
;     PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of
;     months, nD is the number of days, 'T' is the date/time separator, nH is
;     the number of hours, nM is the munger of minutes, and nS is the number of
;     seconds (for example, PT5M specifies 5 minutes, and P1M4DT2H5M specifies
;     one month, four days, 2 hours and 5 minutes).
;   - The complete path to the executable to run.
;   - The arguments to pass to the executable (use an empty string "" for none).
;   - The working directory for the task.
;   - The account to run the service under (either "Local Service" or "System")
; Return Value:
;   This function returns a a value on the stack to indicate the results that
;   must be poped off after the function returns.  The value will be the string
;   "error" if there was a problem scheduling the task, or "ok" for success.
;===============================================================================
Function CreateTask
  ${If} ${AtMostWinXP}
    Call CreateTaskV1
  ${Else}
    Call CreateTaskV2
  ${EndIf}
FunctionEnd

;=============================================================================
;                     TASK SCHEDULER V1.0 API FUNCTIONS
;
; Everything in this section is for working with the Task Scheduler V1.0 API.
; This API must be used for versions of Windows up to XP.
;=============================================================================

!define CLSID_TaskSchedulerV1 "{148BD52A-A2AB-11CE-B11F-00AA00530503}"
!define IID_ITaskSchedulerV1 "{148BD527-A2AB-11CE-B11F-00AA00530503}"
!define CLSID_TaskV1 "{148BD520-A2AB-11CE-B11F-00AA00530503}"
!define IID_ITaskV1 "{148BD524-A2AB-11CE-B11F-00AA00530503}"
!define IID_IPersistFileV1 "{0000010B-0000-0000-C000-000000000046}"

;===============================================================================
; Delete a previously scheduled task.
;
; This is provided as a macro so that it can also be called from the uninstaller
; (where the name has to start with "un.").  If calling from the installer, use
;    Call DeleteTask ""
; From the uninstaller, use:
;    Call un.DeleteTask
;
; Arguments:
;   - The name of the task used when the task was originally registered.
; Return Value:
;   This function returns an integer on the stack that should be popped off
;   after calling this function.  This value will be the return value of the
;   ITaskFolder->DeleteTask() call (0 indicates success.  Otherwise it is a
;   HRESULT error code.
;===============================================================================
!macro wrapDeleteTaskV1 un
Function ${un}DeleteTaskV1
  ; Store registers and pop params
  System::Store "S r0"

  ; Create ITaskScheduler object
  System::Call "ole32::CoCreateInstance(g '${CLSID_TaskSchedulerV1}', i 0, i 1, g '${IID_ITaskSchedulerV1}', *i .R1) i.R9"
  IntCmp $R9 0 0 End

  ; ITaskScheduler->Delete()
  System::Call '$R1->7(w r0) i.R9'

End:
  ; IUnknown->Release
  System::Call '$R1->2() i'

  ; restore registers and push result
  System::Store "P9 l"
FunctionEnd
!macroend
!insertmacro wrapDeleteTaskV1 ""
!insertmacro wrapDeleteTaskV1 "un."

;===============================================================================
; Create a new scheduled task to start at system boot time.
;
; Arguments: This function takes 7 string arguments that must be pushed onto the
;   stack in the following order before calling this function:
;   - The name that the task will have in the Task Scheduler
;   - A description of what the task does.
;   - Start delay.  This determines the amount of time from when the system is
;     booted to when the task will start.  The format for this string is
;     PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of
;     months, nD is the number of days, 'T' is the date/time separator, nH is
;     the number of hours, nM is the munger of minutes, and nS is the number of
;     seconds (for example, PT5M specifies 5 minutes, and P1M4DT2H5M specifies
;     one month, four days, 2 hours and 5 minutes).
;   - The complete path to the executable to run.
;   - The arguments to pass to the executable (use an empty string "" for none).
;   - The working directory for the task.
;   - The account to run the service under (either "Local Service" or "System")
; Return Value:
;   This function returns a a value on the stack to indicate the results that
;   must be poped off after the function returns.  The value will be the string
;   "error" if there was a problem scheduling the task, or "ok" for success.
;===============================================================================
Function CreateTaskV1
  SetPluginUnload alwaysoff

  ; store registers and pop params
  System::Store "S r6r5r4r3r2r1r0"

  StrCpy $R0 "error" ; result

  ; Create ITaskScheduler object
  System::Call "ole32::CoCreateInstance(g '${CLSID_TaskSchedulerV1}', i 0, i 1, g '${IID_ITaskSchedulerV1}', *i .R1) i.R9"
  IntCmp $R9 0 0 End

  ; ITaskScheduler->NewWorkItem()
  System::Call '$R1->8(w r0, g "${CLSID_TaskV1}", g "${IID_ITaskV1}", *i .R2) i.R9'

  ; IUnknown->Release()
  System::Call '$R1->2() i'       ; release Task Scheduler object
  IntCmp $R9 0 0 End

  ; ITask->SetComment()
  System::Call '$R2->18(w r1)'

  ; ITask->SetApplicationName()
  System::Call '$R2->32(w r3)'

  ; ITask->SetWorkingDir()
  System::Call '$R2->36(w r5)'

  ; ITask->SetParameters()
  System::Call '$R2->34(w r4)'

  ; ITask->CreateTrigger(trindex, ITaskTrigger)
  System::Call '$R2->3(*i .R4, *i .R5)'

  ; allocate TASK_TRIGGER structure
  System::Call '*(&l2, &i2 0, \
                    &i2 2011, &i2 12, &i2 12, \
                    &i2 0, &i2 0, &i2 0, \
                    &i2 0, &i2 0, \
                    i 0, i 0, \
                    i 0, \
                    i 6, \
                    &i2 0, &i2 0, &i2 0, &i2 0, &i2 0) i.s'
  Pop $R6

  ; ITaskTrigger->SetTrigger
  System::Call '$R5->3(i R6)'
  ; ITaskTrigger->Release
  System::Call '$R5->2()'

  ; free TASK_TRIGGER structure
  System::Free $R6

  ; ITask->SetAccountInformation
  System::Call '$R2->30(w "", i 0)'

  ; IUnknown->QueryInterface
  System::Call '$R2->0(g "${IID_IPersistFileV1}", *i .R3) i.R9'

  ; IUnknown->Release()
  System::Call '$R2->2() i'              ; release Task object
  IntCmp $R9 0 0 End

  ; IPersistFile->Save
  System::Call '$R3->6(i 0, i 1) i.R9'

  ; IUnknown->Release()
  System::Call '$R3->2() i'

  IntCmp $R9 0 0 End
  StrCpy $R0 "ok"

End:
  ; restore registers and push result
  System::Store "P0 l"

  ; last plugin call must not have /NOUNLOAD so NSIS will be able to delete the temporary DLL
  SetPluginUnload manual
  ; do nothing
  System::Free 0
FunctionEnd

;=============================================================================
;                     TASK SCHEDULER V2.0 API FUNCTIONS
;
; Everything below this is for working with the Task scheduler V2.0 API.  This
; API must be used for Windows versions starting with Vista.
;=============================================================================

; The Class and Interface ID guid for the services that we will be using.
!define CLSID_TaskSchedulerV2 "{0F87369F-A4E5-4CFC-BD3E-73E6154572DD}"
!define IID_ITaskServiceV2 "{2FABA4C7-4DA9-4013-9697-20CC3FD40F85}"
!define IID_IBootTriggerV2 "{2A9C35DA-D357-41F4-BBC1-207AC1B1F3CB}"
!define IID_IExecActionV2 "{4C3D624D-FD6B-49A3-B9B7-09CB3CD3F047}"

;===============================================================================
; Delete a previously scheduled task.
;
; This is provided as a macro so that it can also be called from the uninstaller
; (where the name has to start with "un.").  If calling from the installer, use
;    Call DeleteTask ""
; From the uninstaller, use:
;    Call un.DeleteTask
;
; Arguments:
;   - The name of the task used when the task was originally registered.
; Return Value:
;   This function returns an integer on the stack that should be popped off
;   after calling this function.  This value will be the return value of the
;   ITaskFolder->DeleteTask() call (0 indicates success.  Otherwise it is a
;   HRESULT error code.
;===============================================================================
!macro wrapDeleteTaskV2 un
Function ${un}DeleteTaskV2
  ; Store registers and pop params
  System::Store "S r0"

  StrCpy $R0 "error" ; result

  Call ${un}_CreateITaskServiceAndConnect
  Pop $R1

  ; Get a pointer to the root task folder.
  System::Call "oleaut32::SysAllocString(w '\') i.R8"  ; Create a BSTR
  ; ITaskService->GetFolder()
  System::Call "$R1->7(iR8, *i.R2) i.R9"
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskService

  ; If the task exists, remove it.
  System::Call "oleaut32::SysAllocString(w r0) i.R8" ; Create a BSTR
  ; ITaskFolder->DeleteTask()
  System::Call "$R2->15(iR8, i 0) i.R9"
  System::Call "oleaut32::SysFreeString(iR8)"

  ; Release ITaskFolder: ITaskFolder->Release()
  System::Call "$R2->2()"

ReleaseITaskService:
  ; ITaskService->Release()
  System::Call "$R1->2()"

  ; restore registers and push result
  System::Store "P9 l"
FunctionEnd
!macroend
!insertmacro wrapDeleteTaskV2 ""
!insertmacro wrapDeleteTaskV2 "un."

;===============================================================================
; Create a new scheduled task to start at system boot time.
;
; Arguments: This function takes 7 string arguments that must be pushed onto the
;   stack in the following order before calling this function:
;   - The name that the task will have in the Task Scheduler
;   - A description of what the task does.
;   - Start delay.  This determines the amount of time from when the system is
;     booted to when the task will start.  The format for this string is
;     PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of
;     months, nD is the number of days, 'T' is the date/time separator, nH is
;     the number of hours, nM is the munger of minutes, and nS is the number of
;     seconds (for example, PT5M specifies 5 minutes, and P1M4DT2H5M specifies
;     one month, four days, 2 hours and 5 minutes).
;   - The complete path to the executable to run.
;   - The arguments to pass to the executable (use an empty string "" for none).
;   - The working directory for the task.
;   - The account to run the service under (either "Local Service" or "System")
; Return Value:
;   This function returns a a value on the stack to indicate the results that
;   must be poped off after the function returns.  The value will be the string
;   "error" if there was a problem scheduling the task, or "ok" for success.
;===============================================================================
Function CreateTaskV2
  SetPluginUnload alwaysoff

  ; store registers and pop params
  System::Store "S r6r5r4r3r2r1r0"

  StrCpy $R0 "error" ; result

  Call _CreateITaskServiceAndConnect
  Pop $R1

  ; Get a pointer to the root task folder.
  ; This folder will hold the new task that is registered.
;  System::Call "*(i 1, w '\') i.R8"          ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w '\') i.R8"  ; Create a BSTR
  ; ITaskService->GetFolder()
;  System::Call "$R1->7($R8 + 4, *i.R2) i.R9"
  System::Call "$R1->7(iR8, *i.R2) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskService

  ; Create the task folder if it doesn't exist
;  System::Call "*(i 10, w '\popHealth') i.R8"  ; Create a BSTR
;  System::Call "oleaut32:SysAllocString(w '\popHealth') i.R8"   ; Create a BSTR
  ; ITaskFolder->CreateFolder
;  System::Call "$R2->11($R8 + 4, \
;                        i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc, \
;                        *i.R3) i.R9"
;  System::Call "$R2->11(iR8, \
;                        i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc, \
;                        *i.R3) i.R9"
;  System::Free $R8
;  System::Call "oleaut32::SysFreeString(iR8)"
  ; IUnknown->Release() on the '\' ITaskFolder
;  System::Call "$R2->2()"
;MessageBox MB_OK "Return value of CreateFolder() was: $R9"
;  IntCmp $R9 0 0 Clean

  ; If the same task exists, remove it.
;  System::Call "*(i 22, w 'Boot Trigger Test Task', &i2 0) i.R8"        ; Crate a BSTR
  System::Call "oleaut32::SysAllocString(w r0) i.R8" ; Create a BSTR
  ; ITaskFolder->DeleteTask
;  System::Call "$R2->15($R8 + 4, i 0) i.R9"
  System::Call "$R2->15(iR8, i 0) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"

  ; Create the task builder object to create the task.
  ; ITaskService->NewTask()
  System::Call "$R1->9( i 0, *i.R3) i.R9"

  ; ITaskService->Release().  Not needed anymore
  System::Call "$R1->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; ---------------------------------------------------------------
  ; Get the registration info for setting the identification.
  ; ITaskDefinition->get_RegistrationInfo()
  System::Call "$R3->7(*i.R1) i.R9"
  IntCmp $R9 0 0 ReleaseITaskFolder

;  System::Call "*(i 18, w 'ph-windows\ttaylor') i.R8"   ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w 'ph-windows\ttaylor') i.R8"  ; Create a BSTR
  ; IRegistrationInfo->put_Author()
;  System::Call "$R1->10($R8 + 4) i.R9"
  System::Call "$R1->10(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"

;  System::Call "*(i 32, w 'Run the redis server at startup.') i.R8"  ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r1) i.R8"  ; Create a BSTR
  ; IRegistrationInfo->put_Description()
;  System::Call "$R1->8($R8 + 4) i.R9"
  System::Call "$R1->8(iR8) i.R9"
  ; IRegistrationInfo->Release()
  System::Call "$R1->2()"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; ---------------------------------------------------------------
  ; Create the settings for the task
  ; ITaskDefinition->get_Settings()
  System::Call "$R3->11(*i.R1) i.R9"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Set setting values for the task.
  ; ITaskSettings->put_StartWhenAvailable()
  System::Call "$R1->22(i 0xffff) i.R9"

  ; ITaskSettings->put_StopIfGoingOnBatteries()
  System::Call "$R1->16(i 0xffff) i.R9"

  ; ITaskSettings->put_AllowHardTerminate()
  System::Call "$R1->20(i 0xffff) i.R9"

;  System::Call "*(i 4, w 'PT0S') i.R8"  ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w 'PT0S') i.R8"  ; Create a BSTR
  ; ITaskSettings->put_ExecutionTimeLimit()
;  System::Call "$R1->28($R8 + 4) i.R9"
  System::Call "$R1->28(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"

  ; ITaskSettings->Release()
  System::Call "$R1->2()";
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; ---------------------------------------------------------------
  ; Get the trigger collection to insert the boot trigger.
  ; ITaskDefinition->get_Triggers()
  System::Call "$R3->9(*i.R1) i.R9"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Add the boot trigger to the task
  ; ITriggerCollection->Create()
  System::Call "$R1->10(i 8, *i.R4) i.R9"
  ; ITriggerCollection->Release()
  System::Call "$R1->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; ITrigger->QueryInterface()
  System::Call "$R4->0(g '${IID_IBootTriggerV2}', *i.R1) i.R9"
  ; ITrigger->Release()
  System::Call "$R4->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

;  System::Call "*(i 8, w 'Trigger1') i.R8"   ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w 'Trigger1') i.R8"   ; Create a BSTR
  ; ITrigger->put_Id()
;  System::Call "$R1->9($R8 + 4) i.R9"
  System::Call "$R1->9(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"

  ; Set the task to start at a certain time.  The time
  ; format should be YYYY-MM-DDTHH:MM:SS(+-)(timezone).
  ; For example, the start boundary below
  ; is January 1st 2011 at 12:05
;;  System::Call "*(i 19, w '2011-01-01T12:05:00') i.R8"   ; Create a BSTR
;  System::Call "oleaut32::SysAllocString(w '2011-01-01T12:05:00') i.R8"   ; Create a BSTR
  ; ITrigger->put_StartBoundary()
;;  System::Call "$R1->15($R8 + 4) i.R9"
;  System::Call "$R1->15(iR8) i.R9"
;;  System::Free $R8
;  System::Call "oleaut32::SysFreeString(iR8)"
;MessageBox MB_OK "Return value of put_StartBoundary() was: $R9"

;;  System::Call "*(i 19, w '2021-05-02T08:00:00') i.R8"   ; Create a BSTR
;  System::Call "oleaut32::SysAllocString(w '2021-05-02T08:00:00') i.R8"   ; Create a BSTR
  ; ITrigger->put_EndBoundary()
;;  System::Call "$R1->17($R8 + 4) i.R9"
;  System::Call "$R1->17(iR8) i.R9"
;;  System::Free $R8
;  System::Call "oleaut32::SysFreeString(iR8)"
;MessageBox MB_OK "Return value of put_EndBoundary() was: $R9"

  ; Delay the task to start some time after system start.
;  System::Call "*(i 5, w 'PT30S') i.R8"         ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r2) i.R8"         ; Create a BSTR
  ; IBootTrigger->put_Delay()
;  System::Call "$R1->21($R8 + 4) i.R9"
  System::Call "$R1->21(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  ; IBootTrigger->Release()
  System::Call "$R1->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; ---------------------------------------------------------------
  ; Add an Action to the task.

  ; Get the task action collection pointer
  ; ITaskDefinition->get_Actions()
  System::Call "$R3->17(*i.R1) i.R9"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Create the action, specifying it as an executable action.
  ; IActionCollection->Create()
  System::Call "$R1->12(i 0, *i.R4) i.R9"
  ; IActionCollection->Release()
  System::Call "$R1->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; QI for the executable task pointer
  ; IAction->QueryInterface()
  System::Call "$R4->0(g '${IID_IExecActionV2}', *i.R1) i.R9"
  ; IAction->Release()
  System::Call "$R4->2()"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Set the path of the executable
;  System::Call "*(i 37, w 'C:\redis-2.4.0\32bit\redis-server.exe') i.R8"   ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r3) i.R8"   ; Create a BSTR
  ; IExecAction->put_Path()
;  System::Call "$R1->11($R8 + 4) i.R9"
  System::Call "$R1->11(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Set the arguments for the executable
;  System::Call "*(i 10, w 'redis.conf') i.R8"   ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r4) i.R8"   ; Create a BSTR
  ; IExecAction->put_Arguments()
;  System::Call "$R1->13($R8 + 4) i.R9"
  System::Call "$R1->13(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; Set the working directory for the executable
;  System::Call "*(i 20, w 'c:\redis-2.4.0\32bit') i.R8"   ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r5) i.R8"   ; Create a BSTR
  ; IExecAction->put_WorkingDirectory()
;  System::Call "$R1->15($R8 + 4) i.R9"
  System::Call "$R1->15(iR8) i.R9"
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR8)"
  IntCmp $R9 0 0 ReleaseITaskFolder

  ; IExecAction->Release()
  System::Call "$R1->2()"

  ; ---------------------------------------------------------------
  ; Save the task in the root folder
;  System::Call "*(i22, w r0) i.R8"                                 ; Crate a BSTR
;  System::Call "*(i 13, w 'Local Service') i.R7"                   ; Create a BSTR
;  System::Call "*(i 0, w '') i.R6"                                 ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w r0) i.R8"                ; Crate a BSTR
  System::Call "oleaut32::SysAllocString(w r6) i.R7"                ; Create a BSTR
  System::Call "oleaut32::SysAllocString(w '') i.R6"                ; Create a BSTR
  ; ITaskFolder->RegisterTaskDefinition()
;  System::Call "$R2->17($R8 + 4, \
;                        i $R3, \
;                        i 6, \
;                        i 0xCCCC0008, i 0xCCCCCCCC, $R7 + 4, i 0xCCCCCCCC, \
;                        i 0xCCCC0000, i 0xCCCCCCCC, i 0xCCCCCCCC, i 0XCCCCCCCC, \
;                        i 5, \
;                        i 0xCCCC0008, i 0xCCCCCCCC, $R6 + 4, i 0xCCCCCCCC, \
;                        *i.R1) i.R9"
  System::Call "$R2->17(iR8, \
                        i $R3, \
                        i 6, \
                        i 0xCCCC0008, i 0xCCCCCCCC, iR7, i 0xCCCCCCCC, \
                        i 0xCCCC0000, i 0xCCCCCCCC, i 0xCCCCCCCC, i 0XCCCCCCCC, \
                        i 5, \
                        i 0xCCCC0008, i 0xCCCCCCCC, R6, i 0xCCCCCCCC, \
                        *i.R1) i.R9"
;  System::Free $R6
;  System::Free $R7
;  System::Free $R8
  System::Call "oleaut32::SysFreeString(iR6)"
  System::Call "oleaut32::SysFreeString(iR7)"
  System::Call "oleaut32::SysFreeString(iR8)"
  ; IRegisteredTask->Release()
  System::Call "$R1->2()"

  StrCpy $R0 "ok"

ReleaseITaskFolder:
  ; ITaskFolder->Release()
  System::Call "$R2->2()"
  ; ITaskDefinition->Release()
  System::Call "$R3->2()"

  Goto End

ReleaseITaskService:
  ; ITaskService->Release()
  System::Call "$R1->2()"

End:
  ; restore registers and push result
  System::Store "P0 l"

  ; last plugin call must not have /NOUNLOAD so NSIS will be able to delete the temporary DLL
  SetPluginUnload manual
  ; do nothing
  System::Free 0
FunctionEnd

;===============================================================================
;               THE FOLLOWING FUNCTIONS ARE FOR INTERNAL USE ONLY.
;===============================================================================


;===============================================================================
; Create an ITaskService interface and call the Connect() method.
;
; Arguments:
;   None
; Return Value:
;   This function returns a pointer to the ITaskService interface on the stack
;   that must be popped off after calling this function.  This value should be
;   used for all further ITaskService operations.
;
;   The caller is expected to call IUnknown->Release() on this pointer when it
;   is no longer needed.
;===============================================================================
!macro wrap_CreateITaskServiceAndConnect un
Function ${un}_CreateITaskServiceAndConnect
  ; store registers
  System::Store "S"

  ; Create ITaskService object
  System::Call "ole32::CoCreateInstance(g '${CLSID_TaskSchedulerV2}', i 0, i 1, g '${IID_ITaskServiceV2}', *i .R1) i.R9"
  IntCmp $R9 0 0 End

  ; Connect to the task service: ITaskService->Connect()
  ; Since we are connecting to the local TaskScheduler, and need to pass a VT_EMPTY variant for all 4 parameters.
  ; NOTE: The Connect() function expects the VARIANT structures to be passed BY VALUE, not by reference, and the
  ; System::Call function doesn't have an easy way of doing that, so we have to do it old school, by passing a series
  ; of ints that make up the whole structure.
  System::Call "$R1->10(i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc, \
                        i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc, \
                        i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc, \
                        i 0xcccc0000, i 0xcccccccc, i 0xcccccccc, i 0xcccccccc) i.R9"
  IntCmp $R9 0 0 ReleaseITaskService
  Goto End

ReleaseITaskService:
  ; ITaskService->Release()
  System::Call "$R1->2()"

End:
  ; restore registers and push result
  System::Store "P1 l"
FunctionEnd
!macroend
!insertmacro wrap_CreateITaskServiceAndConnect ""
!insertmacro wrap_CreateITaskServiceAndConnect "un."
