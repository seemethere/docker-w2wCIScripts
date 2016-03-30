#-----------------------
# ConfigureScheduledTasksAfterSysprep.ps1
#-----------------------

Write-Host "INFO: Executing ConfigureScheduleTasksAfterSysprep.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\SetupSSH.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "SetupSSH" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\ActivateVM.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ActivateVM" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\Kill-LongRunningDocker.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "Kill-LongRunningDocker" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\SetupNSSM.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "SetupNSSM" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\ResetNetworking.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ResetNetworking" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\UserTempToD.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "UserTempToD" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\RebootOnce.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "RebootOnce" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest


Write-Host "INFO: ConfigureScheduledTasksAfterSysprep.ps1 completed"
