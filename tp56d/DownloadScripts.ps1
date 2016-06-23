#-----------------------
# DownloadScripts.ps1
#-----------------------

# Stop on error
$ErrorActionPreference="stop"

echo "$(date) DownloadScripts.ps1 Starting..." >> $env:SystemDrive\packer\configure.log

try {

    # Create the scripts directory
    echo "$(date) DownloadScripts.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Create the docker directory
    echo "$(date) DownloadScripts.ps1 Creating docker directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\docker -ErrorAction SilentlyContinue 2>&1 | Out-Null
    
    echo "$(date) DownloadScripts.ps1 Doing downloads..." >> $env:SystemDrive\packer\configure.log
        
    # Downloads scripts for performing local runs.
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/cleanupCI.sh","$env:SystemDrive\scripts\cleanupCI.sh")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/executeCI.sh","$env:SystemDrive\scripts\executeCI.sh")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/Invoke-DockerCI.ps1","$env:SystemDrive\scripts\Invoke-DockerCI.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/RunOnCIServer.cmd","$env:SystemDrive\scripts\RunOnCIServer.cmd")

    # Build agnostic files (alphabetical order)
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/authorized_keys","c:\packer\authorized_keys")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/ConfigureCIEnvironment.ps1","c:\packer\ConfigureCIEnvironment.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/ConfigureSSH.ps1","c:\packer\ConfigureSSH.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/ConfigureSSH.sh","c:\packer\ConfigureSSH.sh")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/InstallMostThings.ps1","c:\packer\InstallMostThings.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/Phase1.ps1","c:\packer\Phase1.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/Phase2.ps1","c:\packer\Phase2.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/Phase3.ps1","c:\packer\Phase3.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/common/Phase4.ps1","c:\packer\Phase4.ps1")

    # OS Version specific files (alphabetical order)
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/ConfigureControlDaemon.ps1","c:\packer\ConfigureControlDaemon.ps1")
	$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/DownloadPatches.ps1","c:\packer\DownloadPatches.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/nssmdocker.cmd","c:\docker\nssmdocker.cmd")
	
	# TP5 production version files
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp56d/DownloadScripts.ps1","c:\packer\DownloadScripts.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp56d/InstallOSImages.ps1","c:\packer\InstallOSImages.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp56d/InstallPrivates.ps1","c:\packer\InstallPrivates.ps1")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp56d/InstallZDP.ps1","c:\packer\InstallZDP.ps1")
    
}
Catch [Exception] {
    echo "$(date) DownloadScripts.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadScripts.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

