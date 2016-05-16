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
    mkdir c:\ZDP\5B -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\4D -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\Pre4D -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\Pre4D\1.000 -ErrorAction SilentlyContinue 2>&1 | Out-Null
    mkdir c:\ZDP\Pre4D\1.003 -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # ZDP varieties
    echo "$(date) DownloadPatches.ps1 Downloading ZDP..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/ZDP/5B/Windows10.0-KB3158987-x64.msu","c:\ZDP\5B\Windows10.0-KB3158987-x64.msu")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/ZDP/4D/Windows10.0-KB3157663-x64.msu","c:\ZDP\4D\Windows10.0-KB3157663-x64.msu")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/ZDP/Pre4D/1.000/Windows10.0-KB3155191-x64.msu","c:\ZDP\Pre4D\1.000\Windows10.0-KB3155191-x64.msu")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/ZDP/Pre4D/1.003/Windows10.0-KB3155191-x64.msu","c:\ZDP\Pre4D\1.003\Windows10.0-KB3155191-x64.msu")

    # Privates - utilities
    echo "$(date) DownloadPatches.ps1 Downloading Utilities..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/certutil.exe","c:\privates\certutil.exe")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/testroot-sha2.cer","c:\privates\testroot-sha2.cer")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/sfpcopy.exe","c:\privates\sfpcopy.exe")

    # Privates - binaries
    echo "$(date) DownloadPatches.ps1 Downloading Privates..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/HostNetSvc.dll","c:\privates\HostNetSvc.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/NetMgmtIF.dll","c:\privates\NetMgmtIF.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/NetSetupApi.dll","c:\privates\NetSetupApi.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/NetSetupEngine.dll","c:\privates\NetSetupEngine.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/NetSetupSvc.dll","c:\privates\NetSetupSvc.dll")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/ntkrnlmp.exe","c:\privates\ntkrnlmp.exe")
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/Privates/wcifs.sys","c:\privates\wcifs.sys")

    }
Catch [Exception] {
    echo "$(date) DownloadPatches.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadPatches.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

