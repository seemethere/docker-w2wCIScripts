#-----------------------
# InstallOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 starting" >> $env:SystemDrive\packer\configure.log

    if ($env:LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) InstallOSImages.ps1 LOCAL_CI_INSTALL copying base images..." >> $env:SystemDrive\packer\configure.log	
        mkdir c:\BaseImages -ErrorAction SilentlyContinue
        copy "\\redmond\osg\Teams\CORE\BASE\HYP\Public\mebersol\temp\containers\TP5 images\V3\CBaseOs_rs1_release_svc_14300.1000.160324-1723_amd64fre_ServerDatacenterCore_en-us" c:\BaseImages\windowsservercore.wim
        copy "\\redmond\osg\Teams\CORE\BASE\HYP\Public\mebersol\temp\containers\TP5 images\V2\CBaseOs_rs1_release_svc_14300.1000.160324-1723_amd64fre_NanoServer_en-us.wim" c:\BaseImages\nanoserver.wim
    }

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