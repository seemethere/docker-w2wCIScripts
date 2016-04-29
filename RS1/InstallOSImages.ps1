#-----------------------
# InstallOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 starting" >> $env:SystemDrive\packer\configure.log

    echo "$(date) InstallOSImages.ps1 installing nanoserver image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\nanoserver.wim -Force
    echo "$(date) InstallOSImages.ps1 installing windowsservercore image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\windowsservercore.wim -Force
}
Catch [Exception] {
    echo "$(date) InstallOSImages.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InstallOSImages.ps1 completed" >> $env:SystemDrive\packer\configure.log
} 