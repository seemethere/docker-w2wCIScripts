#-----------------------
# InstallOSImages.ps1 (really download-only)
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 (really download-only) starting" >> $env:SystemDrive\packer\configure.log

    # As of 6/23 the 6D images aren't available. Use the 6B for now. Should only need the private net workaround.
    echo "$(date) InstallOSImages.ps1 LOCAL_CI_INSTALL copying base images..." >> $env:SystemDrive\packer\configure.log	

    echo "$(date) InstallOSImages.ps1 (really download-only) downloading 6B nanoserver image..." >> $env:SystemDrive\packer\configure.log
    Start-BitsTransfer -Source https://aka.ms/tp5/6b/docker/nanoserver -Destination C:\BaseImages\nanoserver.tar
    echo "$(date) InstallOSImages.ps1 (really download-only) downloading 6B windowsservercore image..." >> $env:SystemDrive\packer\configure.log
    Start-BitsTransfer -Source https://aka.ms/tp5/6b/docker/windowsservercore -Destination C:\BaseImages\windowsservercore.tar
}
Catch [Exception] {
    echo "$(date) InstallOSImages.ps1 (really download-only) complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) InstallOSImages.ps1 (really download-only) completed" >> $env:SystemDrive\packer\configure.log
}