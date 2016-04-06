#-----------------------
# PostSysprep.ps1
#-----------------------

$ErrorActionPreference='Stop'

Write-Host "PostSysprep..."

try {

    echo "$(date) PostSysprep.ps1 starting" > $env:SystemDrive\packer\PostSysprep.log

    #--------------------------------------------------------------------------------------------

    # Download and install Cygwin for SSH capability
    echo "$(date) PostSysprep.ps1 downloading cygwin..." > $env:SystemDrive\packer\PostSysprep.log
    mkdir $env:SystemDrive\cygwin -erroraction silentlycontinue 2>&1 | Out-Null
    $wc=New-Object net.webclient;$wc.Downloadfile("https://cygwin.com/setup-x86_64.exe","$env:SystemDrive\cygwin\cygwinsetup.exe")
    echo "$(date) PostSysprep.ps1 installing cygwin..." >> $env:SystemDrive\packer\PostSysprep.log
    Start-Process -wait $env:SystemDrive\cygwin\cygwinsetup.exe -ArgumentList "-q -R $env:SystemDrive\cygwin --packages openssh openssl -l $env:SystemDrive\cygwin\packages -s http://mirrors.sonic.net/cygwin/ 2>&1 | Out-Null"
    
    # Open the firewall
    echo "$(date) PostSysprep.ps1 opening firewall for SSH..." >> $env:SystemDrive\packer\PostSysprep.log
    Start-Process -wait -NoNewWindow netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"

    #--------------------------------------------------------------------------------------------
    
    # Create directory for storing the nssm configuration
    mkdir $env:ProgramData\docker -ErrorAction SilentlyContinue 2>&1 | Out-Null
    
    # Install NSSM by extracting archive and placing in system32
    echo "$(date) PostSysprep.ps1 downloading NSSM configuration file..." >> $env:SystemDrive\packer\PostSysprep.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/nssmdocker.W2WCIServers.cmd","$env:ProgramData\docker\nssmdocker.cmd")
    echo "$(date) PostSysprep.ps1 downloading NSSM..." >> $env:SystemDrive\packer\PostSysprep.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://nssm.cc/release/nssm-2.24.zip","$env:Temp\nssm.zip")
    echo "$(date) PostSysprep.ps1 extracting NSSM..." >> $env:SystemDrive\packer\PostSysprep.log
    Expand-Archive -Path $env:Temp\nssm.zip -DestinationPath $env:Temp
    echo "$(date) PostSysprep.ps1 installing NSSM..." >> $env:SystemDrive\packer\PostSysprep.log
    Copy-Item $env:Temp\nssm-2.24\win64\nssm.exe $env:SystemRoot\System32
    
    
    # Configure the docker NSSM service
    echo "$(date) PostSysprep.ps1 configuring NSSM..." >> $env:SystemDrive\packer\PostSysprep.log
    Start-Process -Wait "nssm" -ArgumentList "install docker $($env:SystemRoot)\System32\cmd.exe /s /c $env:Programdata\docker\nssmdocker.cmd < nul"
    Start-Process -Wait "nssm" -ArgumentList "set docker DisplayName Docker Daemon"
    Start-Process -Wait "nssm" -ArgumentList "set docker Description Docker control daemon for CI testing"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStderr d:\daemon\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStdout d:\daemon\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStopMethodConsole 30000"
    
    #--------------------------------------------------------------------------------------------
    
    # BUGBUG This is a TP5 hack. #6925609. Should not be necessary in TP5 + ZDP
    echo "$(date) PostSysprep.ps1 resetting networking (hack)..." >> $env:SystemDrive\packer\PostSysprep.log
    netsh int ipv4 reset
    
    #--------------------------------------------------------------------------------------------
    
    echo "$(date) PostSysprep.ps1 configuring temp to D..." >> $env:SystemDrive\packer\PostSysprep.log
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
    echo "$(date) PostSysprep.ps1 configuring runonce for SSH configuration..." >> $env:SystemDrive\packer\PostSysprep.log
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

}
Catch [Exception] {
    echo "$(date) PostSysprep.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\PostSysprep.log
    exit 1
}
Finally {

    # Disable the scheduled task
    echo "$(date) PostSysprep.ps1 disabling scheduled task.." >> $env:SystemDrive\packer\PostSysprep.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'PostSysprep' | Disable-ScheduledTask

    echo "$(date) PostSysprep.ps1 rebooting..." >> $env:SystemDrive\packer\PostSysprep.log
    shutdown /t 0 /r /f /c "PostSysprep"


    echo "$(date) PostSysprep.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\PostSysprep.log
}    