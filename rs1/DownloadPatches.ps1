#-----------------------
# DownloadPatches.ps1
#-----------------------

# Stop on error
$ErrorActionPreference="stop"

echo "$(date) DownloadPatches.ps1 Starting..." >> $env:SystemDrive\packer\configure.log

try {

    # Create the privates directory
    echo "$(date) DownloadPatches.ps1 Creating privates directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\privates -ErrorAction SilentlyContinue 2>&1 | Out-Null

}
Catch [Exception] {
    echo "$(date) DownloadPatches.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadPatches.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

