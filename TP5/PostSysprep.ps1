#-----------------------
# PostSysprep.ps1
# This runs as the Jenkins user.
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) PostSysprep.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    echo "$(date) PostSysprep.ps1 starting" >> $env:SystemDrive\packer\configure.log    

    #--------------------------------------------------------------------------------------------
    # Set full crashdumps (don't fail if by any chance these fail - eg a different config Azure VM. Set for D3_V2)
    $ErrorActionPreference='SilentlyContinue'
    echo "$(date) PostSysprep.ps1 Enabling full crashdumps..." >> $env:SystemDrive\packer\configure.log    
    REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v AutoReboot /t REG_DWORD /d 1 /f | Out-Null
    REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v CrashDumpEnabled /t REG_DWORD /d 1 /f | Out-Null
    REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v DumpFile /t REG_EXPAND_SZ /d "d:\memory.dmp" /f | Out-Null
    echo "$(date) PostSysprep.ps1 Directing pagefile.sys to C:..." >> $env:SystemDrive\packer\configure.log    
    wmic pagefileset create name="C:\pagefile.sys" 
    echo "$(date) PostSysprep.ps1 Setting pagefile size to 15000..." >> $env:SystemDrive\packer\configure.log    
    wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=15000,MaximumSize=15000
    echo "$(date) PostSysprep.ps1 Removing pagefile from D:..." >> $env:SystemDrive\packer\configure.log    
    wmic pagefileset where name="D:\\pagefile.sys" delete
    $ErrorActionPreference='Stop'
    
    #--------------------------------------------------------------------------------------------
    # Configure the CI Environment
    echo "$(date) PostSysprep.ps1 Configuring the CI environment..." >> $env:SystemDrive\packer\configure.log    
    powershell -command "$env:SystemDrive\packer\ConfigureCIEnvironment.ps1"

    #--------------------------------------------------------------------------------------------
    # Install most things
    echo "$(date) PostSysprep.ps1 Installing most things..." >> $env:SystemDrive\packer\configure.log    
    powershell -command "$env:SystemDrive\packer\InstallMostThings.ps1"

    #--------------------------------------------------------------------------------------------

    # Download and install Cygwin for SSH capability  # BUGBUG Hope to get rid of using this....
    echo "$(date) PostSysprep.ps1 downloading cygwin..." >> $env:SystemDrive\packer\configure.log
    mkdir $env:SystemDrive\cygwin -erroraction silentlycontinue 2>&1 | Out-Null
    $wc=New-Object net.webclient;$wc.Downloadfile("https://cygwin.com/setup-x86_64.exe","$env:SystemDrive\cygwin\cygwinsetup.exe")
    echo "$(date) PostSysprep.ps1 installing cygwin..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait $env:SystemDrive\cygwin\cygwinsetup.exe -ArgumentList "-q -R $env:SystemDrive\cygwin --packages openssh openssl -l $env:SystemDrive\cygwin\packages -s http://mirrors.sonic.net/cygwin/ 2>&1 | Out-Null"
    
    #--------------------------------------------------------------------------------------------
    
    # Create directory for storing the nssm configuration
    mkdir $env:SystemDrive\docker -ErrorAction SilentlyContinue 2>&1 | Out-Null
    
    # Configure the docker NSSM service
    echo "$(date) PostSysprep.ps1 configuring NSSM..." >> $env:SystemDrive\packer\configure.log
    Start-Process -Wait "nssm" -ArgumentList "install docker $($env:SystemRoot)\System32\cmd.exe /s /c $env:SystemDrive\docker\nssmdocker.cmd < nul"
    Start-Process -Wait "nssm" -ArgumentList "set docker DisplayName Docker Daemon"
    Start-Process -Wait "nssm" -ArgumentList "set docker Description Docker control daemon for CI testing"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStderr d:\daemon\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStdout d:\daemon\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStopMethodConsole 30000"
    
    #--------------------------------------------------------------------------------------------
    
    echo "$(date) PostSysprep.ps1 configuring temp to D..." >> $env:SystemDrive\packer\configure.log
    $env:Temp="d:\temp"
    $env:Tmp=$env:Temp
    [Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "Machine")
    [Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "Machine")
    [Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "User")
    [Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "User")
    mkdir $env:Temp -erroraction silentlycontinue 2>&1 | Out-Null
    
    #--------------------------------------------------------------------------------------------

    # Start the nssm docker service
    nssm start docker
    
    #--------------------------------------------------------------------------------------------

    # Configure the logon shortcut to configure SSH. This must be done interactively.
    # Otherwise you will see cygwin configuration errors such as the following, and the daemon
    # will be running as system and not work.
    # *** Info: the 'jenkins-tp5-1+cyg_server' account.
    # *** Warning: Setting password expiry for user 'jenkins-tp5-1+cyg_server' failed!
    # *** Warning: Please check that password never expires or set it to your needs.
    # No user or group 'jenkins-tp5-1+cyg_server' known.
    # *** Warning: Assigning the appropriate privileges to user 'jenkins-tp5-1+cyg_server' failed!
    # *** ERROR: There was a serious problem creating a privileged user.
    # *** Query: Do you want to proceed anyway? (yes/no) yes    
    # I tried HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce, no joy. For example
    #   REG ADD "...\RunOnce" /v ConfigureSSH /t REG_SZ /f /d "powershell -command c:\packer\ConfigureSSH.ps1" | Out-Null
    # And fails as scheduled task as that isn't interactive.
    echo "$(date) PostSysprep.ps1 configuring runonce for SSH configuration..." >> $env:SystemDrive\packer\configure.log
    $pass = Get-Content c:\packer\password.txt -raw
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /t REG_DWORD /d 1 /f | Out-Null
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName /t REG_SZ /d jenkins /f | Out-Null
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword /t REG_SZ /d $pass /f | Out-Null
    
    # Create the shortcut (and the containing directory as we haven't logged on interactively yet)
    New-Item "C:\Users\jenkins\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Type Directory -ErrorAction SilentlyContinue    
    $TargetFile = "powershell" #-command c:\packer\ConfigureSSH.ps1"
    $ShortcutFile = "C:\Users\jenkins\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ConfigureSSH.lnk"
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.Arguments ="-command c:\packer\ConfigureSSH.ps1"
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.Save()

    # Create the TP5 workaround for killing a long-running docker process
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-command c:\scripts\Kill-LongRunningDocker.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00
    Register-ScheduledTask -TaskName "Kill-LongRunningDocker" -Action $action -Trigger $trigger -User jenkins -Password $pass -RunLevel Highest
}
Catch [Exception] {
    echo "$(date) PostSysprep.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {

    # Disable the scheduled task
    echo "$(date) PostSysprep.ps1 disabling scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'PostSysprep' | Disable-ScheduledTask

    echo "$(date) PostSysprep.ps1 rebooting..." >> $env:SystemDrive\packer\configure.log
    shutdown /t 0 /r /f /c "PostSysprep"


    echo "$(date) PostSysprep.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\configure.log
}    