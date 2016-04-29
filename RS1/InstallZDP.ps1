#-----------------------
# InstallZDP.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallZDP.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
}
Catch [Exception] {
    echo "$(date) InstallZDP.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InstallZDP.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
}    