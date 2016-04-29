#-----------------------
# ConfigureSSH.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {

    echo "$(date) ConfigureSSH.ps1 starting" >> $env:SystemDrive\packer\configure.log

    # Hack by putting it here for now. Install the container OS images
    echo "$(date) ConfigureSSH.ps1 Hack - installing nanoserver image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\CBaseOs_rs1_release_svc_14300.1000.160324-1723_amd64fre_NanoServer_en-us.wim -Force
    echo "$(date) ConfigureSSH.ps1 Hack - installing windowsservercore image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\CBaseOs_rs1_release_svc_14300.1000.160324-1723_amd64fre_ServerDatacenterCore_en-us.wim -Force

    # Open the firewall
    echo "$(date) ConfigureSSH.ps1 opening firewall for SSH..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait -NoNewWindow netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"

    # Configure cygwin ssh daemon
    Start-Process -wait taskkill -ArgumentList "/F /IM sshd.exe" -ErrorAction SilentlyContinue
    Start-Process -wait -WorkingDirectory c:\packer -NoNewWindow c:\cygwin\bin\bash -ArgumentList "--login /cygdrive/c/packer/ConfigureSSH.sh >> /cygdrive/c/packer/configure.log 2>&1"
}
Catch [Exception] {
    echo "$(date) ConfigureSSH.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    $ErrorActionPreference='SilentlyContinue'
    echo "$(date) ConfigureSSH.ps1 turning off auto admin logon" >> $env:SystemDrive\packer\configure.log
    REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /f | Out-Null
    REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName  /f | Out-Null
    REG DELETE "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword  /f | Out-Null
    echo "$(date) ConfigureSSH.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
    
    # Tidy up
    Remove-Item "C:\Users\jenkins\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ConfigureSSH.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item c:\packer\password.txt -Force -ErrorAction SilentlyContinue
    Remove-Item c:\packer\ConfigureSSH.log -Force -ErrorAction SilentlyContinue
    echo "$(date) ConfigureSSH.ps1 is rebooting" >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "ConfigureSSH.ps1"
} 