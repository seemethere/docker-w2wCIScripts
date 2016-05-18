#-----------------------
# GetConfig.ps1
#-----------------------

try {

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        
        # Get config.txt
        echo "$(date) GetConfig.ps1 Downloading config.txt..." >> $env:SystemDrive\packer\configure.log
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/config/config.txt","$env:SystemDrive\packer\config.txt")


     }

    # Store the branch
    [Environment]::SetEnvironmentVariable("Branch",$Branch,"Machine")
}
Catch [Exception] {
    Throw $_
}
Finally {
    Write-Host "$(date) GetConfig.ps1 completed..." 
}  
