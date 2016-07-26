#-----------------------
# Phase4.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {

    echo "$(date) Phase4.ps1 starting" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Phase4 Start.txt"

    # Add the registry keys to stop reporting as it skew stats
    echo "$(date) Phase4 Adding SQM keys" >> $env:SystemDrive\packer\configure.log
    if (-not (Test-Path "HKCU:Software\Microsoft\SQMClient")) {
        New-Item -Path "HKCU:Software\Microsoft\SQMClient" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    New-ItemProperty -Path "HKCU:Software\Microsoft\SQMClient" -Name "isTest" -Value 1 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path "HKCU:Software\Microsoft\SQMClient" -Name "MSFTInternal" -Value 1 -PropertyType DWORD -Force -ErrorAction SilentlyContinue | Out-Null
    echo "$(date) Phase4 SQM Keys added" >> $env:SystemDrive\packer\configure.log

    if ($env:LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) Phase4.ps1 quitting on local CI" >> $env:SystemDrive\packer\configure.log
        exit 0
    }

    # Configure cygwin ssh daemon
    echo "$(date) Phase4.ps1 killing sshd if running..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait taskkill -ArgumentList "/F /IM sshd.exe" -ErrorAction SilentlyContinue
    echo "$(date) Phase4.ps1 invoking ConfigureSSH.ps1..." >> $env:SystemDrive\packer\configure.log
    . $("$env:SystemDrive\packer\ConfigureSSH.ps1")
}
Catch [Exception] {
    echo "$(date) Phase4.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\ERROR Phase4.txt"
    exit 1
}
Finally {
    $ErrorActionPreference='SilentlyContinue'
    echo "$(date) Phase4.ps1 turning off auto admin logon" >> $env:SystemDrive\packer\configure.log
    if ($env:LOCAL_CI_INSTALL -ne 1) {
        echo "$(date) Phase4.ps1 Removing AutoAdminLogon key" >> $env:SystemDrive\packer\configure.log
        Remove-ItemProperty  -Name "AutoAdminLogon" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
        echo "$(date) Phase4.ps1 Removing DefaultUserName key" >> $env:SystemDrive\packer\configure.log
        Remove-ItemProperty  -Name "DefaultUserName" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
        echo "$(date) Phase4.ps1 Removing DefaultPassword key" >> $env:SystemDrive\packer\configure.log
        Remove-ItemProperty  -Name "DefaultPassword" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
    }
    
    # Tidy up
    echo "$(date) Phase4.ps1 Calculating user" >> $env:SystemDrive\packer\configure.log
    $user="administrator"
    if ($env:LOCAL_CI_INSTALL -ne 1) {
        echo "$(date) Phase4.ps1 user is 'jenkins'" >> $env:SystemDrive\packer\configure.log
        $user="jenkins"
    }
    echo "$(date) Phase4.ps1 Removing Phase4.lnk" >> $env:SystemDrive\packer\configure.log
    Remove-Item "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Phase4.lnk" -Force -ErrorAction SilentlyContinue
    echo "$(date) Phase4.ps1 Removing password.txt" >> $env:SystemDrive\packer\configure.log
    Remove-Item c:\packer\password.txt -Force -ErrorAction SilentlyContinue
    echo "$(date) Phase4.ps1 Removing ConfigureSSH.log" >> $env:SystemDrive\packer\configure.log
    Remove-Item c:\packer\ConfigureSSH.log -Force -ErrorAction SilentlyContinue

    echo "$(date) Phase4.ps1 is rebooting" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Phase4 End.txt"
    shutdown /t 0 /r /f /c "Phase4.ps1"
} 