#-----------------------
# Install-DevVM.ps1
#-----------------------

# Wrapper for installing a development VM on Microsoft corpnet.
# Currently has a few hard-coded things for me (@jhowardmsft)
# Invokes the same processing for setting up a production CI
# server, but also turns on KD, net uses to the machine where
# the development sources are, installs VSCode & LiteIDE, 
# creates a shortcut for a development prompt, plus sets auto-logon.
# Also assumes that this is running from \\redmond\osg\teams\....\team\jhoward\docker\ci\w2w\Install-DevVM

param(
    [Parameter(Mandatory=$false)][string]$Branch,
    [Parameter(Mandatory=$false)][int]$DebugPort
)
$ErrorActionPreference = 'Stop'

$env:DOCKER_DUT_DEBUG=0                      # TP5 Debugging
$env:DOCKER_TP5_BASEIMAGE_WORKAROUND=0       # TP5 Base image workaround 

$DEV_MACHINE="jhoward-z420"
$DEV_MACHINE_DRIVE="e"

Try {
    Write-Host -ForegroundColor Yellow "INFO: John's dev script for dev VM installation"

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch=""
        
        $hostname=$env:COMPUTERNAME.ToLower()
        Write-Host "Matching $hostname for a branch type..."
        
        foreach ($line in Get-Content ..\config\config.txt) {
            $line=$line.Trim()
            if (($line[0] -eq "#") -or ($line -eq "")) {
                continue
            }
            $elements=$line.Split(",")
            if ($elements.Length -ne 2) {
                continue
            }
            if (($elements[0].Length -eq 0) -or ($elements[1].Length -eq 0)) {
                continue
            }
            if ($hostname -match $elements[0]) {
                $Branch=$elements[1]
                Write-Host $hostname matches $elements[0]
                break
            }
        }
        if ($Branch.Length -eq 0) { Throw "Branch not supplied and $hostname regex match not found in configuration" }
        Write-Host "Branch matches $Branch through "$elements[0]
    }
    $Branch = $Branch.ToLower()

    # Check if branch is valid by looking if directory exists
    if ($False -eq $(Test-Path -PathType Container ..\$Branch)) {
        Throw "Branch doesn't appear to be valid"
    }

    # Setup Debugging
    if ($DebugPort -eq 0) {
        Write-Host -Fore"If you're sure you want named pipe debugging, press enter."
        Write-Host "Otherwise, control-C now and add -DebugPort 500nn for network debugging"
        pause
        if ($(Test-Path "HKLM:software\microsoft\virtual machine\guest") -eq $True) {
            Write-Host "INFO: KD to COM1. Configure COM1 to \\.\pipe\<VMName>"
            bcdedit /debug on
            bcdedit /dbgsettings serial debugport:1 baudrate:115200
        }
    }
    if ($DebugPort -gt 0) {
        if (($DebugPort -lt 50000) -or ($DebugPort -gt 50030)) {
            Throw "Debug port must be 50000-50030"
        }
        $ip = (resolve-dnsname $DEV_MACHINE -type A -NoHostsFile -LlmnrNetbiosOnly).IPAddress
        Write-Host "INFO: KD to $DEV_MACHINE ($ip`:$DebugPort) cle.ar.te.xt"
        bcdedit /dbgsettings NET HOSTIP`:$ip PORT`:$DebugPort KEY`:cle.ar.te.xt
        bcdedit /debug on
    }

    [Environment]::SetEnvironmentVariable("DOCKER_DUT_DEBUG","$env:DOCKER_DUT_DEBUG", "Machine")
    [Environment]::SetEnvironmentVariable("DOCKER_TP5_BASEIMAGE_WORKAROUND","$env:DOCKER_TP5_BASEIMAGE_WORKAROUND", "Machine")
    
    if ($null -eq $(Get-Command code -erroraction silentlycontinue)) {
        # VSCode (useful for markdown editing). But really annoying as I can't find a way to
        # not make it launch after setup completes, so blocks. Workaround isn't nice but works
        $ErrorActionPreference = 'Stop'
        if (-not (Test-Path $env:Temp\vscodeinstaller.exe)) {
            Write-Host "INFO: Downloading VSCode installer"
            Invoke-WebRequest "https://go.microsoft.com/fwlink/?LinkID=623230" -OutFile "$env:Temp\vscodeinstaller.exe"
        }
        Write-Host "INFO: Installing VSCode"
        $j = Start-Job -ScriptBlock {Start-Process -wait "$env:Temp\vscodeinstaller.exe" -ArgumentList "/silent /dir:c:\vscode"}
        Write-Host "INFO: Waiting for installer to complete"
        Start-Sleep 60
        Write-Host "INFO: Force stopping vscode, iexplore and edge (annoying workaround...)"
        Get-Process *code* -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
        Get-Process *iexplore* -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
        Get-Process *MicrosoftEdge* -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
        Write-Host "INFO: Waiting on job"
        wait-Job $j.id | Out-Null
    }

    Write-Host "INFO: Configuring automatic logon"
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /t REG_DWORD /d 1 /f
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName /t REG_SZ /d administrator /f
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword /t REG_SZ /d "p@ssw0rd" /f 

    Write-Host "INFO: Net using to $DEV_MACHINE"
    net use "$DEV_MACHINE_DRIVE`:" "\\$DEV_MACHINE\$DEV_MACHINE_DRIVE`$"

    Write-Host "INFO: Disabling real time monitoring"
    set-mppreference -disablerealtimemonitoring $true
    Write-Host "INFO: Setting execution policy"
    Set-ExecutionPolicy bypass
    Write-Host "INFO: Unblocking the shortcut file"
    Unblock-File .\docker-docker-shortcut.ps1
    # Commented out as hangs sometimes. No idea why.
    #Write-Host "INFO: Running the shortcut file"
    #powershell -command .\docker-docker-shortcut.ps1

    Write-Host "INFO: Creating c:\liteide"
    mkdir c:\liteide -ErrorAction SilentlyContinue
    Write-Host "INFO: Copying liteide..."
    xcopy \\redmond\osg\Teams\CORE\BASE\HYP\Team\jhoward\Docker\Install\liteide\liteidex28.windows-qt4\liteide\* c:\liteide /s /Y
    Write-Host "INFO: Removing docker.exe if it exists"
    Remove-Item c:\windows\system32\docker.exe -ErrorAction SilentlyContinue
    Write-Host "INFO: Removing dockerd.exe if it exists"
    Remove-Item c:\windows\system32\dockerd.exe -ErrorAction SilentlyContinue

    Write-Host "INFO: Enabling remote desktop in registry"
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
    Write-Host "INFO: Enabling remote desktop in firewall"
    enable-netfirewallrule -displaygroup 'Remote Desktop'

    Write-Host "INFO: Turning off the firewall"
    NetSh Advfirewall set allprofiles state off

    Write-Host "INFO: Copying some utilities (pipelist, sfpcopy, windiff)"
    Copy-Item pipelist.exe c:\windows\system32  -ErrorAction SilentlyContinue
    Copy-Item sfpcopy.exe c:\windows\system32 -ErrorAction SilentlyContinue
    Copy-Item windiff.exe c:\windows\system32 -ErrorAction SilentlyContinue

    Write-Host "INFO: Setting environment variables"
    #[Environment]::SetEnvironmentVariable("GOARCH","amd64", "Machine")
    #[Environment]::SetEnvironmentVariable("GOOS","windows", "Machine")
    #[Environment]::SetEnvironmentVariable("GOEXE",".exe", "Machine")
    [Environment]::SetEnvironmentVariable("GOPATH",$DEV_MACHINE_DRIVE+":\go\src\github.com\docker\docker\vendor;"+$DEV_MACHINE_DRIVE+":\go", "Machine")
    [Environment]::SetEnvironmentVariable("Path","$env:Path;c:\gopath\bin;"+$DEV_MACHINE_DRIVE+":\docker\utils", "Machine")
    [Environment]::SetEnvironmentVariable("LOCAL_CI_INSTALL","1","Machine")
    [Environment]::SetEnvironmentVariable("Branch",$Branch,"Machine")
    $env:LOCAL_CI_INSTALL="1"

    mkdir c:\packer -ErrorAction SilentlyContinue
    Copy-Item "..\common\Bootstrap.ps1" c:\packer\ -ErrorAction SilentlyContinue
    Unblock-File c:\packer\Bootstrap.ps1 
    . "$env:SystemDrive\packer\Bootstrap.ps1" -Branch $Branch

    echo $(date) > "c:\users\public\desktop\$Branch.txt"

    # TP5 Debugging
    if ($env:DOCKER_DUT_DEBUG -eq 1) {
        echo $(date) > "c:\users\public\desktop\DOCKER_DUT_DEBUG"
    }

    # TP5 Base image workaround 
    if ($env:DOCKER_TP5_BASEIMAGE_WORKAROUND -eq 1) {
        echo $(date) > "c:\users\public\desktop\DOCKER_TP5_BASEIMAGE_WORKAROUND"
    }
} Catch [Exception] {
    Write-Host -ForegroundColor Red ("`r`n`r`nERROR: Failed '$_'")
    exit 1
}
Finally {
    Write-Host -ForegroundColor Yellow "INFO: Install completed at $(date)"
}

