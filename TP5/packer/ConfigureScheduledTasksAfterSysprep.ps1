#-----------------------
# ConfigureScheduledTasksAfterSysprep.ps1
#-----------------------

# This runs pre-sysprep to ensure when coming out of sysprep, we configure the tasks for post sysprep.
# Note we can't schedule as the jenkins user as that account doesn't yet exit. Hence we schedule it as
# user SYSTEM. The ConfigurePostSysprep then schedules other tasks to do the configuration which do runs
# as the Jenkins user.

Write-Host "INFO: Executing ConfigureScheduleTasksAfterSysprep.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\ConfigurePostSysprep.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "ConfigurePostSysprep" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

Write-Host "INFO: ConfigureScheduledTasksAfterSysprep.ps1 completed"
