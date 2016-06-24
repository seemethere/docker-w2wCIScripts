#-----------------------
# DownloadOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) DownloadOSImages.ps1 starting" >> $env:SystemDrive\packer\configure.log

    if ($env:LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) DownloadOSImages.ps1 LOCAL_CI_INSTALL copying base images..." >> $env:SystemDrive\packer\configure.log	
        mkdir c:\BaseImages -ErrorAction SilentlyContinue
        # v5 fixes the 30/60 second delays due to TI, and contains the 5B ZDP
        copy "\\redmond\osg\Teams\CORE\BASE\HYP\Public\mebersol\temp\containers\TP5 images\V5\ServerDatacenterCore.wim" c:\BaseImages\windowsservercore.wim
        copy "\\redmond\osg\Teams\CORE\BASE\HYP\Public\mebersol\temp\containers\TP5 images\V5\ServerDatacenterNano.wim" c:\BaseImages\nanoserver.wim
    }

    echo "$(date) DownloadOSImages.ps1 installing nanoserver image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\nanoserver.wim -Force
    echo "$(date) DownloadOSImages.ps1 installing windowsservercore image..." >> $env:SystemDrive\packer\configure.log
    Install-ContainerOSImage c:\BaseImages\windowsservercore.wim -Force
}
Catch [Exception] {
    echo "$(date) DownloadOSImages.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadOSImages.ps1 completed" >> $env:SystemDrive\packer\configure.log
} 