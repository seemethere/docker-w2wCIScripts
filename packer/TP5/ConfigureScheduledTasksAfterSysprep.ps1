#-----------------------
# ConfigureScheduledTasksAfterSysprep.ps1
#-----------------------

Write-Host "INFO: Executing ConfigureScheduleTasksAfterSysprep.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\SetupSSH.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "SetupSSH" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\ActivateVM.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ActivateVM" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\Kill-LongRunningDocker.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "Kill-LongRunningDocker" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\SetupNSSM.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "SetupNSSM" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\ResetNetworking.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ResetNetworking" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\ConfigureTempToD.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ConfigureTempToD" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\RebootOnce.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "RebootOnce" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest


Write-Host "INFO: ConfigureScheduledTasksAfterSysprep.ps1 completed"
