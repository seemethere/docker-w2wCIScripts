#-----------------------
# Phase0.ps1
# Do not run directly. Use bootstrap instead.
#-----------------------

param(
    [Parameter(Mandatory=$false)][string]$Branch
)

$ErrorActionPreference="stop"

echo "$(date) Phase0.ps1 starting..." >> $env:SystemDrive\packer\configure.log
echo $(date) > "c:\users\public\desktop\Phase0 Start.txt"

try {

Throw "Test"
exit 1

    if ([string]::IsNullOrWhiteSpace($Branch)) {
         Throw "Branch must be supplied (eg tp5dev, tp5pre4d, tp5prod, rs1,...)"
    }

    # Coming out of sysprep, we reboot twice, so do not do anything on the first reboot. This also has the nice
    # side effect that we are guaranteed after the reboot the $env:Branch is set so that any script subsequently can pick it up.
    if (-not (Test-Path c:\packer\Phase0.RebootedOnce.txt)) {

        # Re-register on account of local install on development machine (done in packer for production)
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\Phase0.ps1 $Branch"
        $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
        Register-ScheduledTask -TaskName "Phase0" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

        echo "$(date) Phase0.RebootedOnce.txt doesn't exist, so creating it and not doing anything..." >> $env:SystemDrive\packer\configure.log
        New-Item c:\packer\Phase0.RebootedOnce.txt
        shutdown /t 0 /r /f /c "First reboot in Phase0"
        exit 0
    } else {
        # We've rebooted once. On our way forward then...

        # Create the scripts directory
        echo "$(date) Phase0.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
        mkdir c:\\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

        # Download the script that downloads our files
        echo "$(date) Phase0.ps1 Downloading DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/$Branch/DownloadScripts.ps1","$env:SystemDrive\packer\DownloadScripts.ps1")

        # Invoke the downloads
        echo "$(date) Phase0.ps1 Invoking DownloadScripts.ps1..." >> $env:SystemDrive\packer\configure.log
        powershell -command "$env:SystemDrive\packer\DownloadScripts.ps1"

        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\Phase1.ps1"
        $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
        Register-ScheduledTask -TaskName "Phase1" -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest

        echo "$(date) Phase0.ps1 rebooting..." >> $env:SystemDrive\packer\configure.log
        shutdown /t 0 /r /f /c "Second reboot in Phase0"
    }
}
Catch [Exception] {
    echo "$(date) Phase0.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\ERROR Phase0.txt"
    exit 1
}
Finally {
    echo "$(date) Phase0.ps1 completed..." >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Phase0 End.txt"
}  
