#-----------------------
# ConfigureScheduledTasksAfterSysprep.ps1
#-----------------------

Write-Host "INFO: Executing ConfigureScheduleTasksAfterSysprep.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\ConfigurePostSysprep.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ConfigurePostSysprep" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

Write-Host "INFO: ConfigureScheduledTasksAfterSysprep.ps1 completed"
