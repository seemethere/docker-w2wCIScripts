#-----------------------
# InitPostSysprep.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.

$ErrorActionPreference="stop"

echo "$(date) InitPostSysprep.ps1 starting..." >> $env:SystemDrive\packer\configure.log

try {

    # Coming out of sysprep, we reboot twice, so do not do anything on the first reboot.
    if (-not (Test-Path c:\packer\InitPostSysprep.GoneThroughOneReboot.txt)) {
        echo "$(date) InitPostSysprep.GoneThroughOneReboot.txt doesn't exist, so creating it and not doing anything..." >> $env:SystemDrive\packer\configure.log
        New-Item c:\packer\InitPostSysprep.GoneThroughOneReboot.txt
        # Force a reboot if we don't get one in the next 2 minutes
        sleep 120
        shutdown /t 0 /r /f /c "First reboot in InitPostSysprep"
        exit 0
    }

    # Create the scripts directory
    echo "$(date) InitPostSysprep.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Download the script that downloads our files
    echo "$(date) InitPostSysprep.ps1 Downloading DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/DownloadScripts.ps1","$env:SystemDrive\packer\DownloadScripts.ps1")

    # Invoke the downloads
    echo "$(date) InitPostSysprep.ps1 Invoking DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
    $env:SystemDrive\packer\DownloadScripts.ps1

    $pass = Get-Content c:\packer\password.txt -raw

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\PostSysprep.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
    Register-ScheduledTask -TaskName "PostSysprep" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest

    # Disable the scheduled task
    echo "$(date) InitPostSysprep.ps1 disable scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'InitPostSysprep' | Disable-ScheduledTask

    echo "$(date) InitPostSysprep.ps1 sleeping for 1 minute before reboot..." >> $env:SystemDrive\packer\configure.log
    sleep 60
    echo "$(date) InitPostSysprep.ps1 rebooting..." >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "InitPostSysprep"
}
Catch [Exception] {
    echo "$(date) InitPostSysprep.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InitPostSysprep.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  
