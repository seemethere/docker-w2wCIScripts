#-----------------------
# BootstrapAutomatedInstall.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.
#
# Don't put anything in here apart from things that are required for launching the post sysprep tasks.
# This file is the only thing put in the Azure image when built using packer.

$ErrorActionPreference="stop"

echo "$(date) BootstrapAutomatedInstall.ps1 starting..." >> $env:SystemDrive\packer\configure.log

try {

    # Coming out of sysprep, we reboot twice, so do not do anything on the first reboot except install the patches.
    if (-not (Test-Path c:\packer\BootstrapAutomatedInstall.GoneThroughOneReboot.txt)) {
        echo "$(date) BootstrapAutomatedInstall.GoneThroughOneReboot.txt doesn't exist, so creating it and not doing anything..." >> $env:SystemDrive\packer\configure.log
        New-Item c:\packer\BootstrapAutomatedInstall.GoneThroughOneReboot.txt
        shutdown /t 0 /r /f /c "First reboot in BootstrapAutomatedInstall"
        exit 0
    }

    # Create the scripts directory
    echo "$(date) BootstrapAutomatedInstall.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Download the script that downloads our files
    echo "$(date) BootstrapAutomatedInstall.ps1 Downloading DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/DownloadScripts.ps1","$env:SystemDrive\packer\DownloadScripts.ps1")

    # Invoke the downloads
    echo "$(date) BootstrapAutomatedInstall.ps1 Invoking DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
    powershell -command "$env:SystemDrive\packer\DownloadScripts.ps1"


    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\Phase1.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
    Register-ScheduledTask -TaskName "Phase1" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

    # Disable the scheduled task
    echo "$(date) BootstrapAutomatedInstall.ps1 disable scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'BootstrapAutomatedInstall' | Disable-ScheduledTask

    echo "$(date) BootstrapAutomatedInstall.ps1 rebooting..." >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "BootstrapAutomatedInstall"
}
Catch [Exception] {
    echo "$(date) BootstrapAutomatedInstall.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) BootstrapAutomatedInstall.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  
