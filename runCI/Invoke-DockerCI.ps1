<#
.NOTES
    Author:  John Howard, Microsoft Corporation. (Github @jhowardmsft)

    Created: February 2016

    Summary: Invokes Windows to Windows Docker CI testing on an arbitrary
             build of Windows configured for running containers.

    License: See https://github.com/jhowardmsft/Invoke-DockerCI

    Pre-requisites:

     - Must be elevated
     - Hyper-V role is installed
     - Containers role is installed
     - NAT (and a switch is created for TP4). ie Everything set by InstallFeatures.cmd
     - Container image for windowsservercore is installed. Nanoserver is
       optional at time of writing as no CI tests use it.

    If no parameters are supplied, the system drive will be used for
    everything; the latest binary from master.dockerproject.org will be
    used as the control daemon, and the sources will be the current master
    available at https://github.com/docker/docker.

    THIS TAKES AGES TO RUN!!!
      Expect this entire script to take (as at time of writing based on around
      400 integration tests and TP5) ~45 mins on a Z420 in a VM running with
      8 cores, 4GB RAM and backed by a fast (Samsung Evo 850 Pro) SSD.
      I would expect HDD to take significantly longer (not recommended...). 

.PARAMETER SourcesDrive
     For example "c". Drive where the sources will be cloned.
     If not set, it will default to the system drive. If you have a
     secondary fast drive such as SSD/NVME PCIe adapter, using
     its drive would make this whole script run a lot faster

.PARAMETER SourcesSubdir
     For example "gopath". Subdir on SourcesDrive where the sources
     are cloned to such as c:\gopath\src\github.com\docker\docker. 
     If not set, defaults to 'gopath'

.PARAMETER TestrunDrive
     For example "c". Drive where the daemon under test is run.
     If not set, it will default to the system drive. If you have a
     secondary fast drive such as SSD/NVME PCIe adapter, using
     its drive would make this whole script run a lot faster

.PARAMETER TestrunSubdir
    For example "CI". Subdir on TestrunDrive where logs for the daemon under
    test are placed. The logs will be under TestrunDrive:\TestrunSubdir\CI-nnnnnn,
    where nnnnn is the commit ID of the git repo and branch being tested.
    If not set, defaults to 'CI'.

.PARAMETER GitRemote
    Allows a git repo to be tested. If set, it does the following
    steps:  git remote add remote $GitRemote
            git fetch $GitRemote (to get the branches for GitCheckout)

.PARAMETER GitCheckout
    Used in conjunction with GitRemote. If not specified, no
    `git checkout` after cloning the sources is done. This parameter
    allows a few things. 

    -  Want version 1.11.0 on master?  Use `v1.11.0` with no GitRemote

    -  Want to test a feature branch `jjh/buildpathhack`? Use the
       name of the feature branch. This is generally only useful if
       you also specify a GitRemote as that's where feature branches
       are expected to be committed and pushed to.

    -  Want to test a specific commit? Just put it in. For reference
       the TP4 docker is on docker/docker master, commit 18c9fe0,
       build date Nov 23 2015 22:32:50 UTC. In this example, you wouldn't
       set GitRemote as it's on master.

.PARAMETER DestroyCache
    When $True will remove the control daemons cache. This makes a second 
    run a lot slower. Defaults to $False.

.PARAMETER DockerBasePath
    The base path of the binary to use for the control binaries.
    Can be an http: path, or a file-path (local or UNC). If not supplied,
    the latest 64-bit Windows binary (binaries) from master.dockerproject.org
    will be used. Note that this is a path. The script will automatically
    add /docker.exe and optionally /dockerd.exe as needed. Don't include
    the trailing / or \ on this parameter!

.PARAMETER GitLocation
    The location of the git installer binary. Can be an http: path, or a
    file path (local or UNC). 

.PARAMETER CIScriptLocation
    The location of the bash CI script to actually do the CI work. This
    is a temporary parameter and will eventually be redundant once the
    Jenkins script is in the docker sources. Can be an http: path, or a
    file path (local or UNC).

.PARAMETER Protocol
    The wire protocol to use for the control daemon and daemon under
    test to use. Can be npipe (default) or tcp.

.PARAMETER DUTDebugMode
    Whether to run the daemon under test in debug mode. Default is false.

.PARAMETER ControlDebugMode
    Whether to run the control daemon in debug mode. Default is false.

.PARAMETER SkipValidationTests
    Whether to skip the validation tests (fmt, lint etc). They are run by default

.PARAMETER SkipUnitTests
    Whether to skip the unit tests. They are run by default.

.PARAMETER SkipIntegrationTests
    Whether to skip the integration tests. They are run by default.

.PARAMETER HyperVControl
    Whether to run the control daemon configured to run containers as
    Hyper-V containers. By default it is not

.PARAMETER HyperVDUT
    Whether to run the daemon under test configured to run containers as
    a Hyper-V container. By default it is not

.EXAMPLE
    Example To Be Completed #TODO

#>

# Note: The first four parameters are the ones which drive the bash script
#   for CI, and are in capitals for bash conventions in docker bash scripts.
#   Subsequent variables are used just by this script to configure
#   the machine to be able to run the bash CI script, install stuff, 
#   checkout the sources and so on. These are set in the environment as
#   that is where the bash script expects to pick them up from.


param(
    [Parameter(Mandatory=$false)][string]$SourcesDrive,
    [Parameter(Mandatory=$false)][string]$SourceSubdir, 
    [Parameter(Mandatory=$false)][string]$TestrunDrive,
    [Parameter(Mandatory=$false)][string]$TestrunSubdir,
    [Parameter(Mandatory=$false)][string]$GitRemote,
    [Parameter(Mandatory=$false)][string]$GitCheckout,
    [Parameter(Mandatory=$false)][switch]$DestroyCache=$False,
    [Parameter(Mandatory=$false)][string]$DockerBasePath = $DOCKER_DEFAULT_BASEPATH,
    [Parameter(Mandatory=$false)][string]$GitLocation = $GIT_DEFAULT_LOCATION,
    [Parameter(Mandatory=$false)][string]$CIScriptLocation = $CISCRIPT_DEFAULT_LOCATION,
    [Parameter(Mandatory=$false)][string]$Protocol = $DEFAULT_PROTOCOL,
    [Parameter(Mandatory=$false)][switch]$DUTDebugMode=$False,
    [Parameter(Mandatory=$false)][switch]$ControlDebugMode=$False,
    [Parameter(Mandatory=$false)][switch]$SkipValidationTests=$False,
    [Parameter(Mandatory=$false)][switch]$SkipUnitTests=$False,
    [Parameter(Mandatory=$false)][switch]$SkipIntegrationTests=$False,
    [Parameter(Mandatory=$false)][switch]$HyperVControl=$False,
    [Parameter(Mandatory=$false)][switch]$HyperVDUT=$False
)

$ErrorActionPreference = 'Stop'
$DOCKER_DEFAULT_BASEPATH="https://master.dockerproject.org/windows/amd64"
$GIT_DEFAULT_LOCATION="https://github.com/git-for-windows/git/releases/download/v2.8.1.windows.1/Git-2.8.1-64-bit.exe"
$DEFAULT_PROTOCOL="npipe"

# THIS IS TEMPORARY - WILL EVENTUALLY BE CHECKED INTO DOCKER SOURCES
$CISCRIPT_DEFAULT_LOCATION = "https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/executeCI.sh"

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

# Test-CommandExists returns $true if a command exists/is installed on the system
Function Test-CommandExists
{
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {if(Get-Command $command){RETURN $true}}
    Catch {RETURN $false}
    Finally {$ErrorActionPreference=$oldPreference}
} 

# Stop-NSSMDocker stops the NSSM controlled docker daemon service
Function Stop-NSSMDocker {
    $ErrorActionPreference = 'Stop'
    try {
        $service=get-service docker -ErrorAction SilentlyContinue
        if ($service -ne $null) {
        	if ($service.status -eq "running") {
                Write-Host -ForegroundColor green "INFO: Stopping NSSM controlled docker service..."
                stop-service $service -ErrorAction Stop
    	    }
        }
    }
    catch {
        throw $_
    }
}

# Dismount-MountedVHDs unmounts any VHDs which may be still mounted from a previous run
Function Dismount-MountedVHDs {
    $ErrorActionPreference = 'Stop'
    try {
        Write-Host -ForegroundColor green "INFO: Detaching lingering VHDs..."
        gwmi msvm_mountedstorageimage -namespace root\virtualization\v2 -ErrorAction SilentlyContinue | foreach-object {$_.DetachVirtualHardDisk() }
    } catch {
        Throw $_
    }
}

# Get-GoVersionFromDockerfile extracts the version of go from dockerfile.Windows
Function Get-GoVersionFromDockerfile {
    $ErrorActionPreference = 'Stop'
    try {
        $pattern=select-string $workspace\dockerfile.windows -pattern "GO_VERSION="
        if ($pattern.Count -lt 1) {
            Throw "Could not find GO_VERSION= in dockerfile.Windows!"
        }
        $line=$pattern[0]
        $line=$line -replace "\\",""
        $line=$line.TrimEnd()
        $index=$line.indexof("=")
        if ($index -eq -1) {
            Throw "Could not find '=' in the GO_VERSION line of dockerfile.Windows"
        }
        $GoVersionInDockerfile=$line.Substring($index+1)
        Write-Host -ForegroundColor green "INFO: Need go version $GoVersionInDockerfile"
        return $GoVersionInDockerfile
    } catch {
        Throw $_
    }
}



# Kill-Processes kills any processes which might be locking files.
Function Kill-Processes
{
    Write-Host -ForegroundColor green "INFO: Killing processes..."
    Get-Process -Name tail, docker, dockerd, dockercontrol, dockerdcontrol, cc1, link, compile, ld, go, git, git-remote-https, integration-cli.test -ErrorAction SilentlyContinue | `
        Stop-Process -Force -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue
}

# Get-Sources does the git work to get the sources being tested
Function Get-Sources
{
    Param([string]$Workspace,
          [string]$GitRemote,
          [string]$GitCheckout)

    Set-PSDebug -Trace 0
    $ErrorActionPreference = 'Stop'

    try {

        # Wipe the workspace where the sources exist
        if ( Test-Path $Workspace -ErrorAction SilentlyContinue ) {
            Write-Host -ForegroundColor green "INFO: Wiping $Workspace..."
            Remove-Item -Recurse -Force $Workspace
        }
           
        # Clone the sources into the workspace.
        Write-Host -ForegroundColor green "INFO: Cloning docker sources into $Workspace..."
        #$env:GIT_TERMINAL_PROMPT=0 # Make git not prompt
        $proc = Start-Process git.exe -ArgumentList "clone https://github.com/docker/docker $Workspace" -NoNewWindow -PassThru 
        try
        {
            $proc | Wait-Process -Timeout 180 -ErrorAction Stop
            if ($proc.ExitCode -ne 0) {
                Throw "Clone failed"
            }
            Write-Host -ForegroundColor green "INFO: Cloned successfully"
        } catch {
            # No point using Stop-Process as git launches several sub-processes
            Kill-Processes
            Throw "Timeout cloning the docker sources"
        }

        # Change to our workspace directory
        Set-Location "$Workspace" -ErrorAction stop

        # Add a remote if supplied
        if (-not [string]::IsNullOrWhiteSpace($GitRemote)) {
            Write-Host -ForegroundColor green "INFO: Adding a remote to $GitRemote"
            $proc = Start-Process git.exe -ArgumentList "remote add remote $GitRemote" -NoNewWindow -PassThru 
            try
            {
                $proc | Wait-Process -Timeout 180 -ErrorAction Stop
                if ($proc.ExitCode -ne 0) {
                    Throw "Adding remote failed"
                }
                Write-Host -ForegroundColor green "INFO: Remote added successfully"
            } catch {
                # No point using Stop-Process as git launches several sub-processes
                Kill-Processes
                Throw "Timeout adding a remote to $GitRemote"
            }
        }

        # Fetch from the remote
        if (-not [string]::IsNullOrWhiteSpace($GitRemote)) {
            Write-Host -ForegroundColor green "INFO: Fetching from remote $GitRemote"
            $proc = Start-Process git.exe -ArgumentList "fetch remote" -NoNewWindow -PassThru 
            try
            {
                $proc | Wait-Process -Timeout 180 -ErrorAction Stop
                if ($proc.ExitCode -ne 0) {
                    Throw "Fetching from remote failed"
                }
                Write-Host -ForegroundColor green "INFO: Fetched from remote"
            } catch {
                # No point using Stop-Process as git launches several sub-processes
                Kill-Processes
                Throw "Timeout fetching from $GitRemote"
            }
        }
    
        # Perform a checkout if requested
        if (-not [string]::IsNullOrWhiteSpace($GitCheckout)) {
            if (-not [string]::IsNullOrWhiteSpace($GitRemote)) { $GitCheckout = "remote/$GitCheckout" }
            Write-Host -ForegroundColor green "INFO: Checking out $GitCheckout"
            $proc = Start-Process git.exe -ArgumentList "checkout $GitCheckout" -NoNewWindow -PassThru 
            try
            {
                $proc | Wait-Process -Timeout 180 -ErrorAction Stop
                if ($proc.ExitCode -ne 0) {
                    Throw "Failed to checkout $GitCheckout"
                }
                Write-Host -ForegroundColor green "INFO: Checked out $GitCheckout"
            } catch {
                # No point using Stop-Process as git launches several sub-processes
                Kill-Processes
                Throw "Timeout checking out $GitCheckout"
            }
        }
    
        # Useful to show the last couple of commits in the overall log
        Write-Host "`r`n"
        git log -2
        Write-Host "`r`n"
    }
    catch {
        Throw $_
    }
}

# Start of the main script. In a try block to catch any exception
Try {
    Write-Host -ForegroundColor Yellow "INFO: Started at $(date)..."
    set-PSDebug -Trace 0  # 1 to turn on

    $controlDaemonStarted=$false

    # Start in the root of the system drive
    cd "$env:SystemDrive\"

    # Set some defaults if they are not defined in the environment
    if ([string]::IsNullOrWhiteSpace($SourcesDrive)) {
        if (-not [string]::IsNullOrWhiteSpace($env:SOURCES_DRIVE)) {
            $SourcesDrive = $env:SOURCES_DRIVE
        } else {
            $SourcesDrive =$Env:SystemDrive.Substring(0,1)
            $env:SOURCES_DRIVE = $SourcesDrive
            Write-Host -ForegroundColor green "INFO: Defaulted SourcesDrive to $SourcesDrive"
        }
    } 

    if ([string]::IsNullOrWhiteSpace($SourcesSubdir)) {
        if (-not [string]::IsNullOrWhiteSpace($env:SOURCES_SUBDIR)) {
            $SourcesSubdir = $env:SOURCES_SUBDIR
        } else {
            $SourcesSubdir= "gopath"
            $env:SOURCES_SUBDIR = $SourcesSubdir
            Write-Host -ForegroundColor green "INFO: Defaulted SourcesSubdir to $SourcesSubdir"
        }
    }

    if ([string]::IsNullOrWhiteSpace($TestrunDrive)) {
        if (-not [string]::IsNullOrWhiteSpace($env:TESTRUN_DRIVE)) {
            $TestrunDrive = $env:TESTRUN_DRIVE
        } else {
            $TestrunDrive = $Env:SystemDrive.Substring(0,1)
            $env:TESTRUN_DRIVE = $TestrunDrive
            Write-Host -ForegroundColor green "INFO: Defaulted TestrunDrive to $TestrunDrive"
        }
    }

    if ([string]::IsNullOrWhiteSpace($TestrunSubdir)) {
        if (-not [string]::IsNullOrWhiteSpace($env:TESTRUN_SUBDIR)) {
            $TestrunSubdir = $env:TESTRUN_SUBDIR
        } else {
            $TestrunSubdir="CI"
            $env:TESTRUN_SUBDIR = $TestrunSubdir
            Write-Host -ForegroundColor green "INFO: Defaulted TestrunSubdir to $TestrunSubdir"
        }
    }

    if ($DUTDebugMode) {
        $env:DOCKER_DUT_DEBUG = "Yes, debug daemon under test"
    }
    if ($SkipValidationTests) {
        $env:SKIP_VALIDATION_TESTS = "Skip these"
    }
    if ($SkipUnitTests) {
        $env:SKIP_UNIT_TESTS = "Skip these"
    }
    if ($SkipIntegrationTests) {
        $env:SKIP_INTEGRATION_TESTS = "Skip these"
    }
    if ($HyperVDUT) {
        $env:DOCKER_DUT_HYPERV = "Yes"
    }


    # Set some default values
    if ([string]::IsNullOrWhiteSpace($DockerBasePath)) {
        # Default to master.dockerproject.org
        $DockerBasePath=$DOCKER_DEFAULT_BASEPATH
    }
    if ([string]::IsNullOrWhiteSpace($GitLocation)) {
        $GitLocation = $GIT_DEFAULT_LOCATION
    }
    if ([string]::IsNullOrWhiteSpace($CIScriptLocation)) {
        $CIScriptLocation = $CISCRIPT_DEFAULT_LOCATION
    }
    if ([string]::IsNullOrWhiteSpace($Protocol)) {
        $Protocol = $DEFAULT_PROTOCOL
    }
    if ($Protocol -ne "npipe" -and $Protocol -ne "tcp") {
        Write-Error "Invalid protocol. Must be npipe or tcp"
        exit 1
    }

    # Where we run the control daemon from
    $ControlRoot="$($TestrunDrive):\control"

    Write-Host -ForegroundColor green "INFO: Configuration:"
    Write-Host -ForegroundColor yellow "Paths"
    Write-Host " - Sources:           $SourcesDrive`:\$SourcesSubdir"
    Write-Host " - Test run:          $TestrunDrive`:\$TestrunSubdir"
    Write-Host " - Control daemon:    $ControlRoot"
    Write-Host  -ForegroundColor yellow "Git"
    if (-not [string]::IsNullOrWhiteSpace($GitRemote)) { Write-Host "  - Remote:            $GitRemote" }
    if (-not [string]::IsNullOrWhiteSpace($GitCheckout)) { Write-Host "  - Checkout:          $GitCheckout" }
    Write-Host " - Installer:         $GitLocation"
    Write-Host  -ForegroundColor yellow "Debug"
    Write-Host " - Daemon under test: $DUTDebugMode"
    Write-Host " - Control daemon:    $ControlDebugMode"
    Write-Host  -ForegroundColor yellow "Skip tests"
    Write-Host " - Validation:        $SkipValidationTests"
    Write-Host " - Unit:              $SkipUnitTests"
    Write-Host " - Integration:       $SkipIntegrationTests"
    Write-Host  -ForegroundColor yellow "Hyper-V Containers"
    Write-Host " - Control daemon:    $HyperVControl"
    Write-Host " - Daemon under test: $HyperVDUT"
    Write-Host  -ForegroundColor yellow "Miscellaneous"
    Write-Host " - Destroy Cache:     $DestroyCache"
    Write-Host " - Control binaries:  $DockerBasePath"
    Write-Host " - CI Script:         $CIScriptLocation"
    Write-Host " - Protocol:          $Protocol"

    # Where we clone the docker sources
    $WorkspaceRoot="$($SourcesDrive):\$($SourcesSubdir)"
    $Workspace="$WorkspaceRoot\src\github.com\docker\docker"

    # Make sure we have the git posix utilities at the front of our path (overwrites find etc), and
    # also the GO bin directories. We also deliberately put $env:Temp there early so that the
    # docker.exe we are using is the one we downloaded above. Also configure GO environment variables
    #BUGBUG Not c, use system drive in next two, and where git/go installed.
    $env:Path="c:\git\cmd;c:\git\bin;c:\git\usr\bin;c:\go\bin;c:\gopath\bin;$env:Temp;$env:Path"
    $env:GOROOT="c:\go"
    $env:GOPATH="$WorkspaceRoot"

    # Turn off antimalware to make things run significantly faster
    Write-Host -ForegroundColor green "INFO: Disabling Windows Defender for performance..."
    set-mppreference -disablerealtimemonitoring $true -ErrorAction Stop

    # Stop the nssm-controlled docker service if running.
    Stop-NSSMDocker

    # Terminate processes which might be running
    Kill-Processes

    # Detach any VHDs just in case there are lingerers
    Dismount-MountedVHDs

    # Download docker.exe for the control daemon in single binary mode. In dual
    # binary mode, downloads docker.exe for the control client, dockerd.exe for
    # the control daemon
    Write-Host -ForegroundColor green "INFO: Control docker base path $DockerBasePath"
    Remove-Item "$env:Temp\docker.exe" -Erroraction SilentlyContinue
    Remove-Item "$env:Temp\dockercontrol.exe" -Erroraction SilentlyContinue
    Remove-Item "$env:Temp\dockerd.exe" -Erroraction SilentlyContinue
    Remove-Item "$env:Temp\dockerdcontrol.exe" -Erroraction SilentlyContinue

    # Download docker.exe client binary. 
    if (0 -ne (Download-File "$DockerBasePath" "docker.exe" "$env:Temp\docker.exe")) {
        Throw "Download docker failed"
    }
    Copy-Item "$env:Temp\docker.exe" "$env:Temp\dockercontrol.exe"

    # Download dockerd.exe daemon binary. 
    if (0 -ne (Download-file "$DockerBasePath" "dockerd.exe" "$env:Temp\dockerd.exe")) {
        Throw "Download dockerd.exe failed"
    }
    Copy-Item "$env:Temp\dockerd.exe" "$env:Temp\dockerdcontrol.exe"

    # Install gcc if not already installed. This will also install windres
    if (-not (Test-CommandExists gcc)) {
        Remove-Item "$env:Temp\gcc.zip" -Erroraction SilentlyContinue
        Remove-Item "$env:Temp\runtime.zip" -Erroraction SilentlyContinue
        Remove-Item "$env:Temp\binutils.zip" -Erroraction SilentlyContinue
        Write-Host -ForegroundColor green "INFO: Downloading GCC"
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/gcc.zip","$env:Temp\gcc.zip")
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/runtime.zip","$env:Temp\runtime.zip")
        $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/binutils.zip","$env:Temp\binutils.zip")
        Write-Host -ForegroundColor green "INFO: Extracting GCC"
        Expand-Archive $env:Temp\gcc.zip $env:SystemDrive\gcc -Force
        Expand-Archive $env:Temp\runtime.zip $env:SystemDrive\gcc -Force
        Expand-Archive $env:Temp\binutils.zip $env:SystemDrive\gcc -Force
        [Environment]::SetEnvironmentVariable("Path","$env:Path;$env:SystemDrive\gcc\bin", "Machine")
        $env:Path="$env:Path;$env:SystemDrive\gcc\bin"
    }

    # Install gcc if not already installed. This will also install windres
    if (-not (Test-CommandExists windres)) {
        Throw "windres not found. Should have been part of GCC. If you manually installed GCC, un-install and re-run this script"
    }

    # Install git if not already installed
    if (-not (Test-CommandExists git)) {
        Remove-Item "$env:Temp\gitinstaller.exe" -Erroraction SilentlyContinue

    
        Write-Host -ForegroundColor green "INFO: Git installer $GitLocation"
        $r=Download-File "$GitLocation" "" "$env:Temp\gitinstaller.exe"
        Unblock-File "$env:Temp\gitinstaller.exe" -ErrorAction Stop
        Write-Host -ForegroundColor green "INFO: Installing git..."
        Start-Process -Wait "$env:Temp\gitinstaller.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /DIR=c:\git' -ErrorAction Stop

        # Set the path for the machine (as the installer doesn't seem to do it) AND for the current process.
        [Environment]::SetEnvironmentVariable("Path","c:\git\bin;c:\git\usr\bin;$env:Path", "Machine")
        $env:Path="c:\git\bin;c:\git\usr\bin;$env:Path"
    }

    # Clone the sources of the repo being tested
    Get-Sources $Workspace $GitRemote $GitCheckout

    # Get the version of GO from the dockerfile
    $GoVersionInDockerfile = Get-GoVersionFromDockerfile
    $GO_DEFAULT_LOCATION="https://storage.googleapis.com/golang/go"+$GoVersionInDockerfile+".windows-amd64.msi"

    # Install go if not already installed
    if (-not (Test-CommandExists go)) {
        Remove-Item "$env:Temp\goinstaller.msi" -Erroraction SilentlyContinue

        if ([string]::IsNullOrWhiteSpace($GoLocation)) {
            $GoLocation = $GO_DEFAULT_LOCATION
        }

        Write-Host -ForegroundColor green "INFO: GoLang installer $GoLocation"
        $r=Download-File "$GoLocation" "" "$env:Temp\goinstaller.msi"
        Unblock-File "$env:Temp\goinstaller.msi" -ErrorAction Stop
        Write-Host -ForegroundColor green "INFO: Installing go..."
        Start-Process -Wait "$env:Temp\goinstaller.msi" -ArgumentList '/quiet' -ErrorAction Stop
    }

    # Install docker-ci-zap if not already installed
    if (-not (Test-CommandExists docker-ci-zap)) {
        Write-Host -ForegroundColor green "INFO: Installing docker-ci-zap..."
        go get "github.com/jhowardmsft/docker-ci-zap"
        if (-not ($? -eq $true)) {
            Throw "Installation of docker-ci-zap failed"
        }
        if (-not ($env:Path.ToLower() -like "*$workspaceroot\bin*")) {
            [Environment]::SetEnvironmentVariable("Path","$workspaceroot\bin;$env:Path", "Machine")
            $env:Path="$workspaceroot\bin;$env:Path"
        }
    }

    # Install docker-signal if not already installed
    if (-not (Test-CommandExists docker-signal)) {
        Write-Host -ForegroundColor green "INFO: Installing docker-signal..."
        go get "github.com/jhowardmsft/docker-signal"
        if (-not ($? -eq $true)) {
            Throw "Installation of docker-signal failed"
        }
        if (-not ($env:Path.ToLower() -like "*$workspaceroot\bin*")) {
            [Environment]::SetEnvironmentVariable("Path","$workspaceroot\bin;$env:Path", "Machine")
            $env:Path="$workspaceroot\bin;$env:Path"
        }
    }

    # Zap the control daemons path if asked to destroy the cache
    if ( Test-Path $ControlRoot -ErrorAction SilentlyContinue ) {
        if ($DestroyCache -eq $true) {
            Write-Host -ForegroundColor green "INFO: Zapping $ControlRoot..."
            docker-ci-zap "-folder=$ControlRoot"
        } else {
            Write-Host -ForegroundColor green "INFO: Keeping control daemon cache hot"
            Remove-Item "$ControlRoot\daemon\docker.pid" -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Create the directories for starting the control daemon. OK if these fail (hot cache)
    Write-Host -ForegroundColor green "INFO: Preparing $ControlRoot..."
    New-Item "$ControlRoot\daemon" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item "$ControlRoot\graph" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
 
    # Install golint if not already installed. Required for basic testing.
    if (-not (Test-CommandExists golint)) {
        Write-Host -ForegroundColor green "INFO: Installing golint..."
        go get -u github.com/golang/lint/golint
        if (-not ($? -eq $true)) {
            Throw "Installation of golint failed"
        }
        if (-not ($env:Path.ToLower() -like "*$workspaceroot\bin*")) {
            [Environment]::SetEnvironmentVariable("Path","$workspaceroot\bin;$env:Path", "Machine")
            $env:Path="$workspaceroot\bin;$env:Path"
        }
    }

    # TODO: This will eventually be in the docker sources. Step can be removed when that's done.
    # Download the CI script
    Write-Host -ForegroundColor green "INFO: CI script $CIScriptLocation"
    $r=Download-File "$CIScriptLocation" "" "$ControlRoot\CIScript.sh"
    # END TODO

    # Update GOPATH now everything is installed
    $env:GOPATH="$WorkspaceRoot\src\github.com\docker\docker\vendor;$WorkspaceRoot"
   

    # Work out the -H for the protocol
    if ($Protocol -eq $DEFAULT_PROTOCOL) {
        $env:DOCKER_HOST="npipe:////./pipe/docker_engine"
    } else {
        $env:DOCKER_HOST="tcp://127.0.0.1:2375"

    }

    # Start the control daemon
    $daemon="$env:Temp\dockerdcontrol.exe --graph $ControlRoot --pidfile=$ControlRoot\daemon\docker.pid -H=$env:DOCKER_HOST"
    if ($HyperVControl -eq $True) {
        $daemon=$daemon+" --isolation=hyperv"
    }
    if ($ControlDebugMode -eq $True) {
        $daemon=$daemon+" -D"
    }
    Write-Host -ForegroundColor green "INFO: Starting a control daemon..."
    $control=start-process "cmd" -ArgumentList "/s /c $daemon > $ControlRoot\daemon\daemon.log 2>&1" -WindowStyle Minimized
    $tail = start-process "tail" -ArgumentList "-f $ControlRoot\daemon\daemon.log" -ErrorAction SilentlyContinue

    # Give it a few seconds to come up
    Start-Sleep -s 5  # BUGBUG Doing a curl to it to get OK would be better up to 60 seconds.
    $controlDaemonStarted=$true

    # TODO Use the one from the cloned sources once it's checked in to docker/docker master
    #      which will be somewhere under $Workspace/jenkins/w2w/...
    # Run the shell script!
    Write-Host -ForegroundColor green "INFO: Starting the CI script..."
    sh "/$TestrunDrive/control/CIScript.sh"
    if (-not ($? -eq $true)) {
        Throw "CI script failed, so quitting wrapper script"
    }

    Write-Host -ForegroundColor green "INFO: Success!!!"
    exit 0
}
Catch [Exception] {
    Write-Host -ForegroundColor Red ("`r`n`r`nERROR: Failed '$_'")
    exit 1
}
Finally {
    Kill-Processes

    # Save the daemon under test log
    if ($controlDaemonStarted -eq $true) {
        Write-Host -ForegroundColor green "INFO: Saving the control daemon log $ControlRoot\daemon\daemon.log to $env:Temp\dockercontroldaemon.log"
        Copy-Item "$ControlRoot\daemon\daemon.log" "$env:Temp\dockercontroldaemon.log" -Force -ErrorAction SilentlyContinue
    }

    Write-Host -ForegroundColor Yellow "INFO: End of wrapper script at $(date)"
}
