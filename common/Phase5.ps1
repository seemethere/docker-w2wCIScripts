#-----------------------
# Phase5.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) Phase5.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    echo "$(date) Phase5.ps1 starting" >> $env:SystemDrive\packer\configure.log   
    echo $(date) > "c:\users\public\desktop\Phase5 Start.txt"

    echo "$(date) Phase5.ps1 Sleeping for 90 seconds to wait for phase4 to complete..." >> $env:SystemDrive\packer\configure.log    
    Start-Sleep 90

    echo "$(date) Phase5.ps1 turning off auto admin logon" >> $env:SystemDrive\packer\configure.log
    if ($env:LOCAL_CI_INSTALL -ne 1) {
        echo "$(date) Phase5.ps1 Removing AutoAdminLogon key" >> $env:SystemDrive\packer\configure.log
        #reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v "AutoAdminLogon" /f 2>&1 | Out-Null
        Remove-ItemProperty  -Name "AutoAdminLogon" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
        echo "$(date) Phase5.ps1 Removing DefaultUserName key" >> $env:SystemDrive\packer\configure.log
        Remove-ItemProperty  -Name "DefaultUserName" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
        #reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v "DefaultUserName" /f 2>&1 | Out-Null
        echo "$(date) Phase5.ps1 Removing DefaultPassword key" >> $env:SystemDrive\packer\configure.log
        Remove-ItemProperty  -Name "DefaultPassword" -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -ErrorAction SilentlyContinue -Force
        #reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v "DefaultPassword" /f 2>&1 | Out-Null
    }
    
    # Tidy up
    echo "$(date) Phase5.ps1 Removing password.txt" >> $env:SystemDrive\packer\configure.log
    Remove-Item c:\packer\password.txt -Force -ErrorAction SilentlyContinue
    echo "$(date) Phase5.ps1 Removing ConfigureSSH.log" >> $env:SystemDrive\packer\configure.log
    Remove-Item c:\packer\ConfigureSSH.log -Force -ErrorAction SilentlyContinue

}
Catch [Exception] {
    echo "$(date) Phase5.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\ERROR Phase5.txt"
    exit 1
}
Finally {
    # Disable the scheduled task
    echo "$(date) Phase5.ps1 disabling scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'Phase5' | Disable-ScheduledTask

    # Reboot
    echo "$(date) Phase5.ps1 completed. Rebooting" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Phase5 End.txt"
    shutdown /t 0 /r /f /c "Phase5"
    echo "$(date) Phase5.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
} 

