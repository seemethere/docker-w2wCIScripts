#-----------------------
# DownloadPatches.ps1
#-----------------------

# Stop on error
$ErrorActionPreference="stop"

echo "$(date) DownloadPatches.ps1 Starting..." >> $env:SystemDrive\packer\configure.log

try {

    # Create the privates directory
    echo "$(date) DownloadPatches.ps1 Creating privates directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\privates -ErrorAction SilentlyContinue 2>&1 | Out-Null

    echo "$(date) DownloadPatches.ps1 Creating c:\ZDP directory..." >> $env:SystemDrive\packer\configure.log
    mkdir c:\ZDP -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\6D -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\5B -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\4D -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # ZDP varieties (MSUs are on Large File Storage in github)
    echo "$(date) DownloadPatches.ps1 Downloading ZDP..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://github.com/jhowardmsft/docker-w2wCIScripts/blob/master/tp5common/ZDP/4D/Windows10.0-KB3157663-x64.msu","c:\ZDP\4D\Windows10.0-KB3157663-x64.msu")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://github.com/jhowardmsft/docker-w2wCIScripts/blob/master/tp5common/ZDP/5B/Windows10.0-KB3158987-x64.msu","c:\ZDP\5B\Windows10.0-KB3158987-x64.msu")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://github.com/jhowardmsft/docker-w2wCIScripts/blob/master/tp5common/ZDP/6D/Windows10.0-KB3172982-x64.msu","c:\ZDP\6D\Windows10.0-KB3172982-x64.msu")

    # Privates - utilities
    echo "$(date) DownloadPatches.ps1 Downloading Utilities..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/certutil.exe","c:\privates\certutil.exe")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/testroot-sha2.cer","c:\privates\testroot-sha2.cer")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/sfpcopy.exe","c:\privates\sfpcopy.exe")

    # Privates - binaries
    echo "$(date) DownloadPatches.ps1 Downloading Privates..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/HostNetSvc.dll","c:\privates\HostNetSvc.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/http.sys","c:\privates\http.sys")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/NetMgmtIF.dll","c:\privates\NetMgmtIF.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/NetSetupApi.dll","c:\privates\NetSetupApi.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/NetSetupEngine.dll","c:\privates\NetSetupEngine.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/NetSetupSvc.dll","c:\privates\NetSetupSvc.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/ntkrnlmp.exe","c:\privates\ntkrnlmp.exe")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/tp5common/Privates/wcifs.sys","c:\privates\wcifs.sys")

    }
Catch [Exception] {
    echo "$(date) DownloadPatches.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadPatches.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

