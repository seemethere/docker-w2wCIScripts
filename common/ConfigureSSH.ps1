#-----------------------
# ConfigureSSH.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {

    echo "$(date) ConfigureSSH.ps1 starting" >> $env:SystemDrive\packer\configure.log

    # Configure cygwin ssh daemon
    echo "$(date) ConfigureSSH.ps1 killing sshd if running..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait taskkill -ArgumentList "/F /IM sshd.exe" -ErrorAction SilentlyContinue
    echo "$(date) ConfigureSSH.ps1 invoking ConfigureSSH.sh..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait -WorkingDirectory c:\packer -NoNewWindow c:\cygwin\bin\bash -ArgumentList "--login /cygdrive/c/packer/ConfigureSSH.sh >> /cygdrive/c/packer/configure.log 2>&1"

    # Open the firewall
    echo "$(date) ConfigureSSH.ps1 opening firewall for SSH..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait -NoNewWindow netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"
}
Catch [Exception] {
    echo "$(date) ConfigureSSH.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) ConfigureSSH.ps1 completed" >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "ConfigureSSH.ps1"
} 