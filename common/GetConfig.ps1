#-----------------------
# GetConfig.ps1
#-----------------------

$ErrorActionPreference='stop'
try {

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch=""
        
        # Get config.txt
        echo "$(date) Bootstrap.ps1 Downloading config.txt..." >> $env:SystemDrive\packer\configure.log
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/config/config.txt","$env:SystemDrive\packer\config.txt")

        $hostname=$env:COMPUTERNAME.ToLower()
        echo "$(date) Bootstrap.ps1 Matching $hostname for a branch type..." >> $env:SystemDrive\packer\configure.log
        
        foreach ($line in Get-Content $env:SystemDrive\packer\config.txt) {
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
                Write-Host $hostname matches $elements[1]
                break
            }
        }
        if ($Branch.Length -eq 0) { Throw "Branch not supplied and $hostname regex match not found in configuration" }
     }

}
Catch [Exception] {
    ###Throw $_
	Write-Error "Error $_"
}
Finally {
    Write-Host "$(date) GetConfig.ps1 completed..." 
	type c:\packer\configure.log
}  
