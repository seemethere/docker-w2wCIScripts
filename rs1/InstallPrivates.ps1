#-----------------------
# InstallPrivates.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallPrivates.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
}
Catch [Exception] {
    echo "$(date) InstallPrivates.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) InstallPrivates.ps1 completed. Reboot required" >> $env:SystemDrive\packer\configure.log
} 

