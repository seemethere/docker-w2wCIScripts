#-----------------------
# Bootstrap.ps1
#-----------------------

# This runs as a scheduled tasks after coming out of sysprep. At this point, we have the jenkins user
# so can schedule tasks as that user to do the post-sysprep configuration. This script itself though
# is running as Local System.
#
# Don't put anything in here apart from things that are required for launching the post sysprep tasks.

param(
    [Parameter(Mandatory=$false)][string]$Branch,
    [Parameter(Mandatory=$false)][switch]$Doitanyway=$False
)

$ErrorActionPreference="stop"

echo "$(date) Bootstrap.ps1 starting..." >> $env:SystemDrive\packer\configure.log
echo $(date) > "c:\users\public\desktop\Bootstrap Start.txt"

try {

    # Delete the scheduled task. May not exist on local install
    $ConfirmPreference='none'
    $t = Get-ScheduledTask 'Bootstrap' -ErrorAction SilentlyContinue
    if ($t -ne $null) {
        echo "$(date) Bootstrap.ps1 deleting scheduled task.." >> $env:SystemDrive\packer\configure.log
        Unregister-ScheduledTask 'Bootstrap' -Confirm:$False -ErrorAction SilentlyContinue
    }

    # This is a semi-hack to avoid using packer and having two images in Azure which is just a time drain prepping/uploading etc.
    # We assume production machines are called jenkins*. If not, we just get out after the task has been deleted. Unless we are
    # told to do it anyway
    if ($Doitanyway -eq $False) {
        if (-not ($env:COMPUTERNAME.ToLower() -like "jenkins*")) { 
            echo "$(date) Bootstrap.ps1 exiting as computername doesn't start with jenkins.." >> $env:SystemDrive\packer\configure.log
            echo $(date) > "c:\users\public\desktop\Bootstrap not jenkins.txt"
            exit 0
        }
    }

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch=""
        
        # Get config.txt
        echo "$(date) Bootstrap.ps1 Downloading config.txt..." >> $env:SystemDrive\packer\configure.log
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/config/config.txt","$env:SystemDrive\packer\config.txt")

        $hostname=$env:COMPUTERNAME.ToLower()
        echo "$(date) Bootstrap.ps1 Matching $hostname for a branch type..." >> $env:SystemDrive\packer\configure.log
        
        foreach ($line in Get-Content $env:SystemDrive\packer\config.txt) {
            $line=$line.Trim()
            if (($line[0] -eq "#") -or ($line -eq "")) {
                continue
            }
            $elements=$line.Split(",")
            if ($elements.Length -ne 2) {
                continue
            }
            if (($elements[0].Length -eq 0) -or ($elements[1].Length -eq 0)) {
                continue
            }
            if ($hostname -match $elements[0]) {
                $Branch=$elements[1]
                Write-Host $hostname matches $elements[0]
                break
            }
        }
        if ($Branch.Length -eq 0) { Throw "Branch not supplied and $hostname regex match not found in configuration" }
        echo "$(date) Bootstrap.ps1 Branch matches $Branch through "$elements[0] >> $env:SystemDrive\packer\configure.log
    }

    # Store the branch
    [Environment]::SetEnvironmentVariable("Branch",$Branch,"Machine")

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
