#-----------------------
# ConfigurePostSysprep.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.

Write-Host "INFO: Executing ConfigurePostSysprep.ps1"

$pass = Get-Content c:\packer\password.txt -raw

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\Kill-LongRunningDocker.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "Kill-LongRunningDocker" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\PostSysprep.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "PostSysprep" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest

# Delete the scheduled task
echo "ConfigurePostSysprep.ps1 deleting scheduled task.." >> $env:SystemDrive\packer\postSysprep.txt
$ConfirmPreference='none'
Get-ScheduledTask 'ConfigurePostSysprep' | Disable-ScheduledTask
echo "ConfigurePostSysprep.ps1 complete, rebooting..." >> $env:SystemDrive\packer\postSysprep.txt

shutdown /t 0 /r /f /c "ConfigurePostSysprep"