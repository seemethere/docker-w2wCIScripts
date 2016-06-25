#-----------------------
# DownloadOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'



try {
    echo "$(date) DownloadOSImages.ps1 starting." >> $env:SystemDrive\packer\configure.log
    New-Item "C:\BaseImages" -ItemType Directory -ErrorAction SilentlyContinue

    if (Test-Path "c:\baseimages\windowsservercore.tar") {
        echo "$(date) DownloadOSImages.ps1 c:\baseimages\windowsservercore.tar exists - nothing to do" >> $env:SystemDrive\packer\configure.log    
        return
    }

    # Copy from internal share
    $bl=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion"  -Name BuildLabEx).BuildLabEx
    $a=$bl.ToString().Split(".")
    $Branch=$a[3]
    $Build=$a[0]+"."+$a[1]+"."+$a[4]
    $Location="\\winbuilds\release\$Branch\$Build\amd64fre\ContainerBaseOsPkgs"

    if ($(Test-Path $Location) -eq $False) {
        Throw "$Location inaccessible. If not on Microsoft corpnet, copy $type.tar manually to c:\baseimages"
    }

    # https://github.com/microsoft/wim2img (Microsoft Internal)
    echo "$(date) DownloadOSImages.ps1 Installing containers module for image conversion" >> $env:SystemDrive\packer\configure.log    
    Register-PackageSource -Name HyperVDev -Provider PowerShellGet -Location \\redmond\1Windows\TestContent\CORE\Base\HYP\HAT\packages -Trusted -Force | Out-Null
    Install-Module -Name Containers.Layers -Repository HyperVDev | Out-Null
    Import-Module Containers.Layers | Out-Null

    $type="windowsservercore"
    $BuildName="serverdatacentercore"  # Internal build name for windowsservercore
    $SourceTar="$Location\cbaseospkg_"+$BuildName+"_en-us\CBaseOS_"+$Branch+"_"+$Build+"_amd64fre_"+$BuildName+"_en-us.tar.gz"
    echo "$(date) DownloadOSImages.ps1 Converting $SourceTar. This may take a few minutes...." >> $env:SystemDrive\packer\configure.log    
    Export-ContainerLayer -SourceFilePath $SourceTar -DestinationFilePath c:\BaseImages\$type.tar

    $type="nanoserver"
    $BuildName="nanoserver"
    $SourceTar="$Location\cbaseospkg_"+$BuildName+"_en-us\CBaseOS_"+$Branch+"_"+$Build+"_amd64fre_"+$BuildName+"_en-us.tar.gz"
    echo "$(date) DownloadOSImages.ps1 Converting $SourceTar. This may take a few minutes...." >> $env:SystemDrive\packer\configure.log    
    Export-ContainerLayer -SourceFilePath $SourceTar -DestinationFilePath c:\BaseImages\$type.tar

}
Catch [Exception] {
    echo "$(date) DownloadOSImages.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    Throw $_
}
Finally {
    echo "$(date) DownloadOSImages.ps1 completed" >> $env:SystemDrive\packer\configure.log
} 