#-----------------------
# Bootstrap.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.
#
# Don't put anything in here apart from things that are required for launching the post sysprep tasks.

param(
    [Parameter(Mandatory=$false)][string]$Branch
)

$ErrorActionPreference="stop"

echo "$(date) Bootstrap.ps1 starting..." >> $env:SystemDrive\packer\configure.log
echo $(date) > "c:\users\public\desktop\Bootstrap Start.txt"

try {

    # BUGBUG TODO - If branch isn't supplied, look it up from a file on GH

    if ([string]::IsNullOrWhiteSpace($Branch)) {
         Throw "Branch must be supplied (eg tp5dev, tp5pre4d, tp5prod, rs1,...)"
    }

    # Store the branch
    [Environment]::SetEnvironmentVariable("Branch",$Branch,"Machine")

    # Delete the scheduled task. May not exist on local install
    $ConfirmPreference='none'
    $t = Get-ScheduledTask 'Bootstrap' -ErrorAction SilentlyContinue
    if ($t -ne $null) {
        echo "$(date) Bootstrap.ps1 deleting scheduled task.." >> $env:SystemDrive\packer\configure.log
        Unregister-ScheduledTask 'Bootstrap' -Confirm:$False -ErrorAction SilentlyContinue
    }

    # Create the scripts and packer directories
    echo "$(date) Bootstrap.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null
    echo "$(date) Bootstrap.ps1 Creating packer directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\\packer -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Delete Phase0.ps1 if it already exists
    if (Test-Path "c:\packer\Phase0.ps1") {
        Remove-Item "c:\packer\Phase0.ps1" -ErrorAction SilentlyContinue 2>&1 | Out-Null
    }

    # Get Phase0.ps1
    echo "$(date) Bootstrap.ps1 Downloading Phase0.ps1..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/Phase0.ps1","$env:SystemDrive\packer\Phase0.ps1")

    # Execute Phase0 passing the branch as a parameter
    echo "$(date) Bootstrap.ps1 Executing Phase0.ps1..." >> $env:SystemDrive\packer\configure.log
    . "$env:SystemDrive\packer\Phase0.ps1" -Branch $Branch
}
Catch [Exception] {
    echo "$(date) Bootstrap.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\ERROR Bootstrap.txt"
    exit 1
}
Finally {
    echo "$(date) Bootstrap.ps1 completed..." >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Bootstrap End.txt"
}  
