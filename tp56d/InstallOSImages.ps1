#-----------------------
# InstallOSImages.ps1 (really download-only)
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 (really download-only) starting" >> $env:SystemDrive\packer\configure.log

    # As of 6/23 the 6D images aren't available. Use the 6B for now. Should only need the private net workaround.
    echo "$(date) InstallOSImages.ps1 LOCAL_CI_INSTALL copying base images..." >> $env:SystemDrive\packer\configure.log	

    New-Item "C:\BaseImages" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    echo "$(date) InstallOSImages.ps1 (really download-only) downloading 6B nanoserver image..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://aka.ms/tp5/6b/docker/nanoserver","C:\BaseImages\nanoserver.tar")
    echo "$(date) InstallOSImages.ps1 (really download-only) downloading 6B windowsservercore image..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://aka.ms/tp5/6b/docker/windowsservercore","C:\BaseImages\windowsservercore.tar")
}
Catch [Exception] {
    echo "$(date) InstallOSImages.ps1 (really download-only) complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) InstallOSImages.ps1 (really download-only) completed" >> $env:SystemDrive\packer\configure.log
}