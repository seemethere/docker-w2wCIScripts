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
    echo "$(date) PostSysprep.ps1 opening firewall..." >> $env:SystemDrive\packer\PostSysprep.log
    Start-Process -wait -NoNewWindow netsh -ArgumentList "advfirewall firewall add rule name=SSH dir=in action=allow protocol=TCP localport=22"
    
    # Configure cygwin. Run ConfigureSSH.sh twice. 
    # HACK:https://social.technet.microsoft.com/Forums/windowsserver/en-US/aede572b-4c1f-4729-bc9d-899fed5fad02/run-powershell-script-as-scheduled-task-that-uses-excel-com-object?forum=winserverpowershell
    # Otherwise will fail.
    if (-Not (Test-Path C:\Windows\System32\config\systemprofile\Desktop)) {
        New-Item C:\Windows\System32\config\systemprofile\Desktop -type Directory
    }
    echo "$(date) PostSysprep.ps1 configuring cygwin..." >> $env:SystemDrive\packer\PostSysprep.log
    echo "$(whoami /all)" >> $env:SystemDrive\packer\PostSysprep.log
    Start-Process -wait taskkill -ArgumentList "/F /IM sshd.exe" -ErrorAction SilentlyContinue
    Start-Process -wait -WorkingDirectory c:\packer -NoNewWindow c:\cygwin\bin\bash -ArgumentList "--login /cygdrive/c/packer/ConfigureSSH.sh >> /cygdrive/c/packer/PostSysprep.log 2>&1"

    #--------------------------------------------------------------------------------------------
    
    # Activate the VM
    #echo "$(date) PostSysprep.ps1 activating..." >> $env:SystemDrive\packer\PostSysprep.log
    #cscript $env:SystemDrive\windows\system32\slmgr.vbs /ipk 6XBNX-4JQGW-QX6QG-74P76-72V67
    #cscript $env:SystemDrive\windows\system32\slmgr.vbs /ato
    
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
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStderr $env:Programdata\docker\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStdout $env:Programdata\docker\nssmdaemon.log"
    Start-Process -Wait "nssm" -ArgumentList "set docker AppStopMethodConsole 30000"
    
    #--------------------------------------------------------------------------------------------
    
    # This is a TP5 hack. #6925609. Should not be necessary in TP5 RTM.
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
    
}
Catch [Exception] {
    echo "$(date) PostSysprep.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\PostSysprep.log
    exit 1
}
Finally {

    # Disable the scheduled task
    echo "$(date) PostSysprep.ps1 deleting scheduled task.." >> $env:SystemDrive\packer\PostSysprep.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'PostSysprep' | Disable-ScheduledTask

    echo "$(date) PostSysprep.ps1 rebooting..." >> $env:SystemDrive\packer\PostSysprep.log
    shutdown /t 0 /r /f /c "PostSysprep"
    sleep 5
    shutdown /t 0 /r /f /c "PostSysprep"
    sleep 5
    shutdown /t 0 /r /f /c "PostSysprep"
    sleep 5
    shutdown /t 0 /r /f /c "PostSysprep"
    sleep 5
    shutdown /t 0 /r /f /c "PostSysprep"
    sleep 5

    echo "$(date) PostSysprep.ps1 complete successfully at $(date)" >> $env:SystemDrive\packer\PostSysprep.log
}    