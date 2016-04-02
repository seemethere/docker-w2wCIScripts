#-----------------------
# ConfigurePostSysprep.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.

echo "$(date) ConfigurePostSysprep.ps1 starting..." >> $env:SystemDrive\packer\PostSysprep.log

# But... coming out of sysprep, we reboot twice, so we need to not do anything on the first reboot.
if (-not (Test-Path c:\packer\ConfigurePostSysprep.GoneThroughOneReboot.txt)) {
    echo "$(date) ConfigurePostSysprep.GoneThroughOneReboot.txt doesn't exist, so creating it and not doing anything..." >> $env:SystemDrive\packer\PostSysprep.log
    New-Item c:\packer\ConfigurePostSysprep.GoneThroughOneReboot.txt
    # Force a reboot if we don't get one in the next 3 minutes
    sleep 180
    shutdown /t 0 /r /f /c "3 minutes in ConfigurePostSysprep"
    exit 0
}

$pass = Get-Content c:\packer\password.txt -raw

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\Kill-LongRunningDocker.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "Kill-LongRunningDocker" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\PostSysprep.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
Register-ScheduledTask -TaskName "PostSysprep" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest

# Disable the scheduled task
echo "$(date) ConfigurePostSysprep.ps1 disable scheduled task.." >> $env:SystemDrive\packer\PostSysprep.log
$ConfirmPreference='none'
Get-ScheduledTask 'ConfigurePostSysprep' | Disable-ScheduledTask

echo "$(date) ConfigurePostSysprep.ps1 sleeping for 2 minutes before reboot..." >> $env:SystemDrive\packer\PostSysprep.log
sleep 120
echo "$(date) ConfigurePostSysprep.ps1 rebooting..." >> $env:SystemDrive\packer\PostSysprep.log
shutdown /t 0 /r /f /c "ConfigurePostSysprep"