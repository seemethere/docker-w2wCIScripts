#-----------------------
# InstallZDP.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallZDP.ps1 started (tp56d)" >> $env:SystemDrive\packer\configure.log

try {
    
    # 6D 
    echo "$(date) InstallZDP.ps1 Installing 6D ZDP silently (needs reboot)..." >> $env:SystemDrive\packer\configure.log
    Start-Process -Wait "c:\zdp\6D\Windows10.0-KB3162982-x64.msu" -ArgumentList "/quiet /norestart"
}
Catch [Exception] {
    echo "$(date) InstallZDP.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) InstallZDP.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
}    