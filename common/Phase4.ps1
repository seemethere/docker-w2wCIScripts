#-----------------------
# Phase4.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {

    echo "$(date) Phase4.ps1 starting" >> $env:SystemDrive\packer\configure.log

    if ($LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) Phase4.ps1 quitting on local CI" >> $env:SystemDrive\packer\configure.log
        exit 0
    }

    # Configure cygwin ssh daemon
    echo "$(date) Phase4.ps1 killing sshd if running..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait taskkill -ArgumentList "/F /IM sshd.exe" -ErrorAction SilentlyContinue
    echo "$(date) Phase4.ps1 invoking ConfigureSSH.sh..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait -WorkingDirectory c:\packer -NoNewWindow c:\cygwin\bin\bash -ArgumentList "--login /cygdrive/c/packer/ConfigureSSH.sh >> /cygdrive/c/packer/configure.log 2>&1"
}
Catch [Exception] {
    echo "$(date) Phase4.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    if ($LOCAL_CI_INSTALL -ne 1) {
        $ErrorActionPreference='SilentlyContinue'
        echo "$(date) Phase4.ps1 turning off auto admin logon" >> $env:SystemDrive\packer\configure.log
        REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /f | Out-Null
        REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName  /f | Out-Null
        REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword  /f | Out-Null
        echo "$(date) Phase4.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
    
        # Tidy up
        Remove-Item "C:\Users\jenkins\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Phase4.lnk" -Force -ErrorAction SilentlyContinue
        Remove-Item c:\packer\password.txt -Force -ErrorAction SilentlyContinue
        Remove-Item c:\packer\ConfigureSSH.log -Force -ErrorAction SilentlyContinue
    }
    echo "$(date) Phase4.ps1 is rebooting" >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "Phase4.ps1"
} 