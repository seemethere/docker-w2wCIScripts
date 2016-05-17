param(
    [Parameter(Mandatory=$false)][string]$Branch,
    [Parameter(Mandatory=$true)][int]$DebugPort
)
$ErrorActionPreference = 'Stop'

$env:DOCKER_DUT_DEBUG=1                      # TP5 Debugging
$env:DOCKER_TP5_BASEIMAGE_WORKAROUND=0       # TP5 Base image workaround 

$DEV_MACHINE="jhoward-z420"
$DEV_MACHINE_DRIVE="e"

Try {
    Write-Host -ForegroundColor Yellow "INFO: John's dev script for dev VM installation"

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        Throw "Branch must be supplied (eg tp5, tp5pre4d], rs1)"
    }
    $Branch = $Branch.ToLower()

    # BUGBUG Could check if branch is valid by looking if directory exists
    if ($False -eq $(Test-Path -PathType Container ..\$Branch)) {
        Throw "Branch doesn't appear to be valid"
    }

    [Environment]::SetEnvironmentVariable("DOCKER_DUT_DEBUG","$env:DOCKER_DUT_DEBUG", "Machine")
    [Environment]::SetEnvironmentVariable("DOCKER_TP5_BASEIMAGE_WORKAROUND","$env:DOCKER_TP5_BASEIMAGE_WORKAROUND", "Machine")

    # Setup Debugging
    if ($DebugPort -eq 0) {
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
        $ip = (resolve-dnsname $DEV_MACHINE -type A).IPAddress
        Write-Host "INFO: KD to $DEV_MACHINE ($ip`:$DebugPort) cle.ar.te.xt"
        bcdedit /dbgsettings NET HOSTIP`:$ip PORT`:$DebugPort KEY`:cle.ar.te.xt
        bcdedit /debug on
    }
    
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
    Write-Host "INFO: Force stopping vscode (annoying workaround...)"
    Get-Process *code* -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
    Write-Host "INFO: Waiting on job"
    wait-Job $j.id | Out-Null
    
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /t REG_DWORD /d 1 /f
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName /t REG_SZ /d administrator /f
    REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword /t REG_SZ /d "p@ssw0rd" /f 

    net use "$DEV_MACHINE_DRIVE`:" "\\$DEV_MACHINE\$DEV_MACHINE_DRIVE`$"

    set-mppreference -disablerealtimemonitoring $true
    Set-ExecutionPolicy bypass
    Unblock-File .\docker-docker-shortcut.ps1
    powershell -command .\docker-docker-shortcut.ps1

    mkdir c:\liteide -ErrorAction SilentlyContinue
    xcopy ..\..\..\install\liteide\liteidex28.windows-qt4\liteide\* c:\liteide /s /Y
    Remove-Item c:\windows\system32\docker.exe -ErrorAction SilentlyContinue

    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
    enable-netfirewallrule -displaygroup 'Remote Desktop'

    NetSh Advfirewall set allprofiles state off

    Copy-Item pipelist.exe c:\windows\system32  -ErrorAction SilentlyContinue
    Copy-Item sfpcopy.exe c:\windows\system32 -ErrorAction SilentlyContinue
    Copy-Item windiff.exe c:\windows\system32 -ErrorAction SilentlyContinue

    [Environment]::SetEnvironmentVariable("GOARCH","amd64", "Machine")
    [Environment]::SetEnvironmentVariable("GOOS","windows", "Machine")
    [Environment]::SetEnvironmentVariable("GOEXE",".exe", "Machine")
    [Environment]::SetEnvironmentVariable("GOPATH",$DEV_MACHINE_DRIVE+":\go\src\github.com\docker\docker\vendor;"+$DEV_MACHINE_DRIVE+":\go", "Machine")
    [Environment]::SetEnvironmentVariable("Path","$env:Path;c:\gopath\bin;"+$DEV_MACHINE_DRIVE+":\docker\utils", "Machine")
    [Environment]::SetEnvironmentVariable("LOCAL_CI_INSTALL","1","Machine")
    [Environment]::SetEnvironmentVariable("Branch",$Branch,"Machine")
    $env:LOCAL_CI_INSTALL="1"

    mkdir c:\packer -ErrorAction SilentlyContinue
    Copy-Item "..\common\BootstrapAutomatedInstall.ps1" c:\packer\ -ErrorAction SilentlyContinue
    Unblock-File c:\packer\BootstrapAutomatedInstall.ps1 
    c:\packer\BootstrapAutomatedInstall.ps1 -Branch $Branch

    echo $(date) > "c:\users\public\desktop\$Branch.txt"

    # TP5 Debugging
    if ($env:DOCKER_DUT_DEBUG -eq 1) {
        echo $(date) > "c:\users\public\desktop\DOCKER_DUT_DEBUG"
    }

    # TP5 Base image workaround 
    if ($env:DOCKER_TP5_BASEIMAGE_WORKAROUND -eq 1) {
        echo $(date) > "c:\users\public\desktop\DOCKER_TP5_BASEIMAGE_WORKAROUND"

        }
    
    }
Catch [Exception] {
    Write-Host -ForegroundColor Red ("`r`n`r`nERROR: Failed '$_'")
    exit 1
}
Finally {
    Write-Host -ForegroundColor Yellow "INFO: Install completed at $(date)"
}

