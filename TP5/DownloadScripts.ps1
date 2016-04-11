#-----------------------
# DownloadScripts.ps1
#-----------------------

# Stop on error
$ErrorActionPreference="stop"

echo "$(date) DownloadScripts.ps1 Starting..." >> $env:SystemDrive\packer\configure.log

try {

	# Create the scripts directory
	echo "$(date) DownloadScripts.ps1 Creating scripts directory..." >> $env:SystemDrive\packer\configure.log
	mkdir c:\\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Downloads scripts for performing local runs.
    echo "$(date) DownloadScripts.ps1 Scripts for local runs..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/executeCI.sh","$env:SystemDrive\scripts\executeCI.sh")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/cleanupCI.sh","$env:SystemDrive\scripts\cleanupCI.sh")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/RunOnCIServer.cmd","$env:SystemDrive\scripts\RunOnCIServer.cmd")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/Invoke-DockerCI/master/Invoke-DockerCI.ps1","$env:SystemDrive\scripts\Invoke-DockerCI.ps1")

	
                "Write-Host INFO: Downloading ConfigureCIEnvironment.ps1...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/ConfigureCIEnvironment.ps1\",\"c://packer//ConfigureCIEnvironment.ps1\")",
                "Write-Host INFO: Downloading InstallMostThings.ps1...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/InstallMostThings.ps1\",\"c://packer//InstallMostThings.ps1\")",
                "Write-Host INFO: Downloading authorized_keys...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/authorized_keys\",\"c://packer//authorized_keys\")",
                "Write-Host INFO: Downloading ConfigurePostSysprep.ps1...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/ConfigurePostSysprep.ps1\",\"c://packer//ConfigurePostSysprep.ps1\")",
                "Write-Host INFO: Downloading PostSysprep.ps1...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/PostSysprep.ps1\",\"c://packer//PostSysprep.ps1\")",
                "Write-Host INFO: Downloading ConfigureSSH.sh...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/ConfigureSSH.sh\",\"c://packer//ConfigureSSH.sh\")",
                "Write-Host INFO: Downloading ConfigureSSH.ps1...",
                "$wc=New-Object net.webclient;$wc.Downloadfile(\"https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/packer/ConfigureSSH.ps1\",\"c://packer//ConfigureSSH.ps1\")",
                "Write-Host INFO: Invoking ConfigureCIEnvironment.ps1...",
                "c:\\packer\\ConfigureCIEnvironment.ps1",
                "Write-Host INFO: Invoking InstallMostThings.ps1...",
                "c:\\packer\\InstallMostThings.ps1",

}
Catch [Exception] {
    echo "$(date) DownloadScripts.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) DownloadScripts.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

