#-----------------------
# InstallOSImages.ps1
#-----------------------

$ErrorActionPreference='Stop'

try {
    echo "$(date) InstallOSImages.ps1 starting" >> $env:SystemDrive\packer\configure.log

    if ($env:LOCAL_CI_INSTALL -eq 1) {
        echo "$(date) InstallOSImages.ps1 LOCAL_CI_INSTALL copying base images..." >> $env:SystemDrive\packer\configure.log	
        mkdir c:\BaseImages -ErrorAction SilentlyContinue

	# TP5Pre4D Copy the original version of the WIMs from the build which do not have any ZDP applied.
	$Branch="RS1_RELEASE_SVC"
	$Build="14300.1000.160324-1723"
	$Location="\\winbuilds\release\$Branch\$Build\amd64fre\ContainerBaseOsPkgs"
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
    Throw $_
}
Finally {
    echo "$(date) InstallOSImages.ps1 completed" >> $env:SystemDrive\packer\configure.log
} 