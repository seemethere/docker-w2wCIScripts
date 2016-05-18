#-----------------------
# Phase2.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) Phase2.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    echo "$(date) Phase2.ps1 starting" >> $env:SystemDrive\packer\configure.log    
    echo $(date) > "c:\users\public\desktop\Phase2 Start.txt"

    # Stop WU on TP5Pre4D and TP5 to stop the final ZDP getting installed and breaking things
    # Important - this is done in phase 2 AFTER the script-managed ZDP has been installed by phase 1
    # otherwise the install will fail
    if ($env:branch.StartsWith("tp5")) { 
        reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 1 /f
        cmd /s /c sc config wuauserv start= disabled
        net stop wuauserv
    }

    #--------------------------------------------------------------------------------------------
    # Install privates
    echo "$(date) Phase2.ps1 Installing privates..." >> $env:SystemDrive\packer\configure.log    
    . $("$env:SystemDrive\packer\InstallPrivates.ps1")

    #--------------------------------------------------------------------------------------------
    # Initiate Phase3
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\packer\Phase3.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
    if ($env:LOCAL_CI_INSTALL -ne 1) {
        $pass = Get-Content c:\packer\password.txt -raw
        Register-ScheduledTask -TaskName "Phase3" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest
    } else {
        Register-ScheduledTask -TaskName "Phase3" -Action $action -Trigger $trigger -User "administrator" -Password "p@ssw0rd" -RunLevel Highest
    }
}
Catch [Exception] {
    echo "$(date) Phase2.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\ERROR Phase2.txt"
    exit 1
}
Finally {
    # Disable the scheduled task
    echo "$(date) Phase2.ps1 disabling scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'Phase2' | Disable-ScheduledTask

    # Reboot
    echo "$(date) Phase2.ps1 completed. Rebooting" >> $env:SystemDrive\packer\configure.log
    echo $(date) > "c:\users\public\desktop\Phase2 End.txt"
    shutdown /t 0 /r /f /c "Phase2"
    echo "$(date) Phase2.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log

} 

