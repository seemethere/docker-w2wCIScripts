#-----------------------
# InstallOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 starting" >> $env:SystemDrive\packer\configure.log

    if ($LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) InstallOSImages.ps1 Copying base images..." >> $env:SystemDrive\packer\configure.log
        mkdir c:\BaseImages
        $bl=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion"  -Name BuildLabEx).BuildLabEx
        $a=$bl.ToString().Split(".")
        $Branch=$a[3]
        $Build=$a[0]+"."+$a[1]+"."+$a[4]
        $Location="\\winbuilds\release\$Branch\$Build\amd64fre\ContainerBaseOsPkgs"
        echo "$(date) InstallOSImages.ps1 Base location=$Location..." >> $env:SystemDrive\packer\configure.log
        copy $Location\cbaseospkg_nanoserver_en-us\CBaseOs_"$Branch"_"$Build"_amd64fre_NanoServer_en-us.wim c:\BaseImages\nanoserver.wim
        copy $Location\cbaseospkg_serverdatacentercore_en-us\CBaseOs_"$Branch"_"$Build"_amd64fre_ServerDatacenterCore_en-us.wim c:\BaseImages\windowsservercore.wim
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