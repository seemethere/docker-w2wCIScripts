<#
.NOTES
    Author:  John Howard, Microsoft Corporation. (Github @jhowardmsft)

    Created: February 2017

    Summary: Customises a VHD from the build share which can be used to upload
             to Azure for Jenkins use, or for dev use. Will only run on Microsoft
             corpnet.

    License: See https://github.com/jhowardmsft/docker-w2wCIScripts/blob/master/LICENSE

    Pre-requisites:

     - Must be elevated
     - Must have access to \\winbuilds\release on Microsoft corpnet.

.Parameter Path
   The path to the build eg \\winbuilds\release\RS1_RELEASE\14393.726.170112-1758

.Parameter Target
   The path on the local machine. eg e:\vms

.Parameter SkipCopyVHD
   Whether to copy the VHD

.Parameter SkipBaseImages
   Whether to skip the creation of the base layers

.Parameter Password
   The administrator password

.Parameter CreateVM
   Whether to create a VM

.Parameter DebugPort
   The debug port (only used with -CreateVM)

.Parameter ConfigSet
   The configuration set such as "rs1" (only used with -CreateVM)

.Parameter Switch
   Name of the virtual switch (only used with -CreateVM)
   
.EXAMPLE
    #TODO

#>

param(
    [Parameter(Mandatory=$false)][string]$Path="\\winbuilds\release\RS_ONECORE_CONTAINER\15146.1000.170227-1702",
    [Parameter(Mandatory=$false)][string]$Target="e:\vms",
    [Parameter(Mandatory=$false)][switch]$SkipCopyVHD=$False,
    [Parameter(Mandatory=$false)][switch]$SkipBaseImages=$False,
    [Parameter(Mandatory=$false)][string]$Password="p@ssw0rd",
    [Parameter(Mandatory=$false)][switch]$CreateVM=$True,
    [Parameter(Mandatory=$false)][string]$Switch="Wired",
    [Parameter(Mandatory=$false)][int]   $DebugPort=50011,
    [Parameter(Mandatory=$false)][string]$ConfigSet="rs1"

)

$ErrorActionPreference = 'Stop'
$mounted = $false
$targetSize = 127GB

# Download-File is a simple wrapper to get a file from somewhere (HTTP, SMB or local file path)
# If file is supplied, the source is assumed to be a base path. Returns -1 if does not exist, 
# 0 if success. Throws error on other errors.
Function Download-File([string] $source, [string] $file, [string] $target) {
    $ErrorActionPreference = 'SilentlyContinue'
    if (($source).ToLower().StartsWith("http")) {
        if ($file -ne "") {
            $source+="/$file"
        }
        # net.webclient is WAY faster than Invoke-WebRequest
        $wc = New-Object net.webclient
        try {
            Write-Host -ForegroundColor green "INFO: Downloading $source..."
            $wc.Downloadfile($source, $target)
        } 
        catch [System.Net.WebException]
        {
            $statusCode = [int]$_.Exception.Response.StatusCode
            if (($statusCode -eq 404) -or ($statusCode -eq 403)) { # master.dockerproject.org returns 403 for some reason!
                return -1
            }
            Throw ("Failed to download $source - $_")
        }
    } else {
        if ($file -ne "") {
            $source+="\$file"
        }
        if ((Test-Path $source) -eq $false) {
            return -1
        }
        $ErrorActionPreference='Stop'
        Copy-Item "$source" "$target"
    }
    $ErrorActionPreference='Stop'
    return 0
}


# Start of the main script. In a try block to catch any exception
Try {
    Write-Host -ForegroundColor Cyan "INFO: Starting at $(date)`n"
    set-PSDebug -Trace 0  # 1 to turn on


    # Split the path into it's parts
    #\\winbuilds\release\RS_ONECORE_CONTAINER_HYP\15140.1001.170220-1700
    # $branch    --> RS_ONECORE_CONTAINER_HYP
    # $build     --> 15140.1001
    # $timestamp --> 170220-1700
    $parts =$path.Split("\")
    if ($parts.Length -ne 6) {
        Throw ("Path appears to be invalid. Should be something like \\winbuilds\release\RS_ONECORE_CONTAINER_HYP\15140.1001.170220-1700")
    }
    $branch=$parts[4]
    Write-Host "INFO: Branch is $branch"
    
    $parts=$parts[5].Split(".")
    
    if ($parts.Length -ne 3) {
        Throw ("Path appears to be invalid. Should be something like \\winbuilds\release\RS_ONECORE_CONTAINER_HYP\15140.1001.170220-1700. Could not parse build ID")
    }
    $build=$parts[0]+"."+$parts[1]
    $timestamp = $parts[2]
    Write-Host "INFO: Build is $build"
    Write-Host "INFO: Timestamp is $timestamp"
    
    # Verify the VHD exists
    $vhdFilename="$build"+".amd64fre."+$branch+".$timestamp"+"_server_ServerDataCenter_en-us_vl.vhd"
    $vhdSource="\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\vhd\vhd_server_serverdatacenter_en-us_vl\$vhdFilename"
    
    if (-not (Test-Path $vhdSource)) { Throw "$vhdSource could not be found" }
    Write-Host "INFO: VHD found"
    
    # Verify the container images exist
    $wscImageLocation="\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\ContainerBaseOsPkgs\cbaseospkg_serverdatacentercore_en-us\CBaseOs_$branch"+"_$build"+".$timestamp"+"_amd64fre_ServerDatacenterCore_en-us.tar.gz"
    if (-not (Test-Path $wscImageLocation)) { Throw "$wscImageLocation could not be found" }
    Write-Host "INFO: windowsservercore base image found"

    $nanoImageLocation="\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\ContainerBaseOsPkgs\cbaseospkg_nanoserver_en-us\CBaseOs_$branch"+"_$build"+".$timestamp"+"_amd64fre_NanoServer_en-us.tar.gz"
    if (-not (Test-Path $nanoImageLocation)) { Throw "$nanoImageLocation could not be found" }
    Write-Host "INFO: nanoserver base image found"

    # Make sure the target location exists
    if (-not (Test-Path $target)) { Throw "$target could not be found" }

    # Create a sub-directory under the target. OK if it already exists.
    $targetSubdir = Join-Path $Target -ChildPath ("$branch $build"+".$timestamp")
    
    # Copy the VHD to the target sub directory
    if ($SkipCopyVHD) { 
        Write-Host "INFO: Skipping copying the VHD"
    } else {
        # Stop the VM if it is running and we're re-creating it, otherwise the VHD is locked
        if ($CreateVM) {
            $vm = Get-VM (split-path $targetSubdir -leaf) -ErrorAction SilentlyContinue
            if ($vm.State -eq "Running") {
                Write-Host "WARN: Stopping the VM"
                Stop-VM $vm -Force
            }
            # Remove it
            if ($vm -ne $null) { Remove-VM $vm -force }

            # And splat the directory
            if (Test-Path $targetSubdir) { Remove-Item $targetSubdir -Force -Recurse -ErrorAction SilentlyContinue }
        }

        Write-Host "INFO: Copying the VHD to $targetSubdir. This may take some time..."
        if (Test-Path (Join-Path $targetSubdir -ChildPath $vhdFilename)) { Remove-Item (Join-Path $targetSubdir -ChildPath $vhdFilename) -force }
        if (-not (Test-Path $targetSubdir)) { New-Item $targetSubdir -ItemType Directory | Out-Null }
        Copy-Item $vhdSource $targetSubdir
    }

    # Get the VHD size in GB, and resize to the target if not already
    Write-Host "INFO: Examining the VHD"
    $disk=Get-VHD (Join-Path $targetSubdir -ChildPath $vhdFilename)
    $size=($disk.size)
    Write-Host "INFO: Size is $($size/1024/1024/1024) GB"
    if ($size -lt $targetSize) {
        Write-Host "INFO: Resizing to $($targetSize/1024/1024/1024) GB"
        Resize-VHD (Join-Path $targetSubdir -ChildPath $vhdFilename) -SizeBytes $targetSize
    }

    # Mount the VHD
    Write-Host "INFO: Mounting the VHD"
    Mount-DiskImage (Join-Path $targetSubdir -ChildPath $vhdFilename)
    $mounted = $true

    # Get the drive letter
    $driveLetter = (Get-DiskImage (Join-Path $targetSubdir -ChildPath $vhdFilename) | Get-Disk | Get-Partition | Get-Volume).DriveLetter
    Write-Host "INFO: Drive letter is $driveLetter"

    # Get the partition
    $partition = Get-DiskImage (Join-Path $targetSubdir -ChildPath $vhdFilename) | Get-Disk | Get-Partition

    # Resize the partition to its maximum size
    $maxSize = (Get-PartitionSupportedSize -DriveLetter $driveLetter).sizeMax
    if ($partition.size -lt $maxSize) {
        Write-Host "INFO: Resizing partition to maximum"
        Resize-Partition -DriveLetter $driveLetter -Size $maxSize
    } 

    # Create some directories
    if (-not (Test-Path "$driveLetter`:\packer"))     {New-Item -ItemType Directory "$driveLetter`:\packer" | Out-Null}
    if (-not (Test-Path "$driveLetter`:\privates"))   {New-Item -ItemType Directory "$driveLetter`:\privates" | Out-Null}
    if (-not (Test-Path "$driveLetter`:\baseimages")) {New-Item -ItemType Directory "$driveLetter`:\baseimages" | Out-Null}
    if (-not (Test-Path "$driveLetter`:\w2w"))        {New-Item -ItemType Directory "$driveLetter`:\w2w" | Out-Null}

    # The entire repo of w2w (we need this for a dev-vm scenario - bootstrap.ps1 makes that decision
    Copy-Item ..\* "$driveletter`:\w2w" -Recurse -Force

    # Put the bootstrap file additionally in \packer
    Copy-Item ..\common\Bootstrap.ps1 "$driveletter`:\packer\"

    # Files for test-signing and copying privates
    Copy-Item ("\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\bin\certutil.exe") "$driveLetter`:\privates\"
    Copy-Item ("\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\bin\testroot-sha2.cer") "$driveLetter`:\privates\"
    Copy-Item ("\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\bin\idw\sfpcopy.exe") "$driveLetter`:\privates\"

    # We need NuGet
    Write-Host "INFO: Installing NuGet package provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null


     if (-not $SkipBaseImages) {
        # https://github.com/microsoft/wim2img (Microsoft Internal)
        Register-PackageSource -Name HyperVDev -Provider PowerShellGet -Location \\redmond\1Windows\TestContent\CORE\Base\HYP\HAT\packages -Trusted -Force | Out-Null
        Write-Host "INFO: Installing Containers.Layers module..."
        Install-Module -Name Containers.Layers -Repository HyperVDev | Out-Null
        Write-Host "INFO: Importing Containers.Layers..."
        Import-Module Containers.Layers | Out-Null

        if (-not (Test-Path "$driveLetter`:\BaseImages\nanoserver.tar")) {
            Write-Host "INFO: Converting nanoserver base image"
            Export-ContainerLayer -SourceFilePath $nanoImageLocation -DestinationFilePath "$driveLetter`:\BaseImages\nanoserver.tar" -Repository "microsoft/nanoserver" -latest
        }
        if (-not (Test-Path "$driveLetter`:\BaseImages\windowsservercore.tar")) {
            Write-Host "INFO: Converting windowsservercore base image"
            Export-ContainerLayer -SourceFilePath $wscImageLocation -DestinationFilePath "$driveLetter`:\BaseImages\windowsservercore.tar" -Repository "microsoft/windowsservercore" -latest
        }
    }

    # Read the current unattend.xml, put in the password and save it to the root of the VHD
    Write-Host "INFO: Creating unattend.xml"
    $unattend = Get-Content ".\unattend.xml"
    $unattend = $unattend.Replace("!!REPLACEME!!", $Password)
    [System.IO.File]::WriteAllText("$driveLetter`:\unattend.xml", $unattend, (New-Object System.Text.UTF8Encoding($False)))

    # Create the password file
    [System.IO.File]::WriteAllText("$driveLetter`:\packer\password.txt", $Password, (New-Object System.Text.UTF8Encoding($False)))

    # Add the pre-bootstrapper that gets invoked by the unattend
    $prebootstrap = `
       "c:\privates\certutil -addstore root c:\privates\testroot-sha2.cer`n" + `
       "bcdedit /set `"{current}`" testsigning on`n" + `
       "set-executionpolicy bypass`n" + `
        "`$action = New-ScheduledTaskAction -Execute `"powershell.exe`" -Argument `"-command c:\w2w\common\Bootstrap.ps1`"`n " + `
        "`$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:01:00`n" + `
        "Register-ScheduledTask -TaskName `"Bootstrap`" -Action `$action -Trigger `$trigger -User SYSTEM -RunLevel Highest`n`n" + `
        "shutdown /t 0 /r"
    [System.IO.File]::WriteAllText("$driveLetter`:\packer\prebootstrap.ps1", $prebootstrap, (New-Object System.Text.UTF8Encoding($False)))

    # Write the config set out to disk
    [System.IO.File]::WriteAllText("$driveLetter`:\packer\configset.txt", $ConfigSet, (New-Object System.Text.UTF8Encoding($False)))

    # Write the debug port out to disk
    [System.IO.File]::WriteAllText("$driveLetter`:\packer\debugport.txt", $DebugPort, (New-Object System.Text.UTF8Encoding($False)))

    # Flush the disk
    Write-Host "INFO: Flushing drive $driveLetter"
    Write-VolumeCache -DriveLetter $driveLetter

    # Dismount - we're done preparing it.
    Write-Host "INFO: Dismounting VHD"
    Dismount-DiskImage (Join-Path $targetSubdir -ChildPath $vhdFilename)
    $mounted = $false
    

    # Create a VM from that VHD
    if ($CreateVM) {
        $vm = Get-VM (split-path $targetSubdir -leaf) -ErrorAction SilentlyContinue
        if ($vm -ne $null) {
            Write-Host "WARN: VM already exists - deleting"
            Remove-VM $vm -Force
        }
        Write-Host "INFO: Creating a VM"
        $vm = New-VM -generation 1 -Path $Target -Name (split-path $targetSubdir -leaf) -NoVHD
        Set-VMProcessor $vm -ExposeVirtualizationExtensions $true -Count 8
        Add-VMHardDiskDrive $vm -ControllerNumber 0 -ControllerLocation 0 -Path (Join-Path $targetSubdir -ChildPath $vhdFilename)
        if ($switch -ne "") {
            Connect-VMNetworkAdapter -VMName (split-path $targetSubdir -leaf) -SwitchName $switch
        }
        Checkpoint-VM $vm

        # BUGBUG - At some point, we need to copy the VHD to the Azure version for upload
        Start-VM $vm
        vmconnect localhost (split-path $targetSubdir -leaf)
    }
    

    # The Azure upload piece

}
Catch [Exception] {
    Throw $_
}
Finally {
    if ($mounted) { 
        Write-Host "INFO: Dismounting VHD"
        Dismount-DiskImage (Join-Path $targetSubdir -ChildPath $vhdFilename)
    }
    Write-Host "INFO: Exiting at $(date)"
}
