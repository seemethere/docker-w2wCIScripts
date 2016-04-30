#-----------------------
# InstallZDP.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallZDP.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    echo "$(date) InstallZDP.ps1 Installing Pre4D v1.000 ZDP silently (needs reboot)..." >> $env:SystemDrive\packer\configure.log
    Start-Process -Wait "c:\zdp\Pre4D\1.000\Windows10.0-KB3155191-x64.msu" -ArgumentList "/quiet /norestart"
}
Catch [Exception] {
    echo "$(date) InstallZDP.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InstallZDP.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
}    