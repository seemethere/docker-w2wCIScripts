param(
    [Parameter(Mandatory=$false)][string]$Branch,
    [Parameter(Mandatory=$false)][int]$DebugPort
)
$ErrorActionPreference = 'Stop'
$DEV_MACHINE="jhoward-z420"
$DEV_MACHINE_DRIVE="e"

# TP5 Debugging
$env:DOCKER_DUT_DEBUG=1 
[Environment]::SetEnvironmentVariable("DOCKER_DUT_DEBUG","$env:DOCKER_DUT_DEBUG", "Machine")

# TP5 Base image workaround 
$env:DOCKER_TP5_BASEIMAGE_WORKAROUND=0
[Environment]::SetEnvironmentVariable("DOCKER_TP5_BASEIMAGE_WORKAROUND","$env:DOCKER_TP5_BASEIMAGE_WORKAROUND", "Machine")

Try {
    Write-Host -ForegroundColor Yellow "INFO: John's dev script for dev VM installation"

	if ([string]::IsNullOrWhiteSpace($Branch)) {
		Throw "Branch must be supplied (eg TP5, TP5Pre4D, RS1)"
	}

	# Setup Debugging
	if ($DebugPort -gt 0) {
		if (($DebugPort -lt 50000) -or ($DebugPort -gt 50030)) {
			Throw "Debug port must be 50000-50030"
		}
		$ip = (resolve-dnsname $DEV_MACHINE -type A).IPAddress
		Write-Host "INFO: KD to $DEV_MACHINE ($ip`:$DebugPort) cle.ar.te.xt"
		bcdedit /dbgsettings NET HOSTIP`:$ip PORT`:$DebugPort KEY`:cle.ar.te.xt
		bcdedit /debug on
		pause
	}
	
	
	REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v AutoAdminLogon /t REG_DWORD /d 1 /f
	REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultUserName /t REG_SZ /d administrator /f
	REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" /v DefaultPassword /t REG_SZ /d "p@ssw0rd" /f 

	net use "$DEV_MACHINE_DRIVE`:" "\\$DEV_MACHINE\$DEV_MACHINE_DRIVE`$"

	# Stop WU on TP5Pre4D to stop the final ZDP getting installed and breaking things
	if ($Branch.ToLower() -eq "tp5pre4d") {
		reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 1 /f
		cmd /s /c sc config wuauserv start= disabled
		net stop wuauserv
	}

	if (($Branch.ToLower() -ne "tp5") -and 
	    ($Branch.ToLower() -ne "tp5pre4d") -and
		($Branch.ToLower() -ne "rs1")) {
		Throw "Branch must be one of TP5, TP5Pre4D or RS1"
	}
	
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

