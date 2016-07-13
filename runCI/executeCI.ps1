# Jenkins CI scripts for Windows to Windows CI (Powershell Version)
# By John Howard (@jhowardmsft) January 2016 - bash version; July 2016 Ported to PowerShell

$ErrorActionPreference = 'Stop'
$StartTime=Get-Date
#$env:DOCKER_DUT_DEBUG="yes" # Comment out to not be in debug mode

# TODO : Cleanup script parity
# TODO : Make sure if this script errors, so does Invoke-DockerCI. Changed the return passing, so make sure of this!!!!

# -------------------------------------------------------------------------------------------
# When executed, we rely on four variables being set in the environment:
#
# [The reason for being environment variables rather than parameters is historical. No reason
# why it couldn't be updated.]
#
#    SOURCES_DRIVE       is the drive on which the sources being tested are cloned from.
#                        This should be a straight drive letter, no platform semantics.
#                        For example 'c'
#
#    SOURCES_SUBDIR      is the top level directory under SOURCES_DRIVE where the
#                        sources are cloned to. There are no platform semantics in this
#                        as it does not include slashes. 
#                        For example 'gopath'
#
#                        Based on the above examples, it would be expected that Jenkins
#                        would clone the sources being tested to
#                        SOURCES_DRIVE\SOURCES_SUBDIR\src\github.com\docker\docker, or
#                        c:\gopath\src\github.com\docker\docker
#
#    TESTRUN_DRIVE       is the drive where we build the binary on and redirect everything
#                        to for the daemon under test. On an Azure D2 type host which has
#                        an SSD temporary storage D: drive, this is ideal for performance.
#                        For example 'd'
#
#    TESTRUN_SUBDIR      is the top level directory under TESTRUN_DRIVE where we redirect
#                        everything to for the daemon under test. For example 'CI'.
#                        Hence, the daemon under test is run under
#                        TESTRUN_DRIVE\TESTRUN_SUBDIR\CI-<CommitID> or
#                        d:\CI\CI-<CommitID>
#
# In addition, the following variables can control the run configuration:
#
#    DOCKER_DUT_DEBUG        if defined starts the daemon under test in debug mode.
#
#    SKIP_VALIDATION_TESTS   if defined skips the validation tests
#
#    SKIP_UNIT_TESTS         if defined skips the unit tests
#
#    SKIP_INTEGRATION_TESTS  if defined skips the integration tests
#
#    DOCKER_DUT_HYPERV       if default daemon under test default isolation is hyperv
#
#    INTEGRATION_TEST_NAME   to only run partial tests eg "TestInfo*" will only run
#                            any tests starting "TestInfo"
#
#    SKIP_BINARY_BUILD       if defined skips building the binary
#
#    SKIP_ZAP_DUT            if defined doesn't zap the daemon under test directory
# -------------------------------------------------------------------------------------------
#
# Jenkins Integration. Add a Windows Powershell build step as follows:
#
#    Write-Host -ForegroundColor green "INFO: Jenkins build step starting"
#    $CISCRIPT_DEFAULT_LOCATION = "https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/runCI/executeCI.ps1"
#    $CISCRIPT_LOCAL_LOCATION = "$env:TEMP\executeCI.ps1"
#    Write-Host -ForegroundColor green "INFO: Removing cached execution script"
#    Remove-Item $CISCRIPT_LOCAL_LOCATION -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
#    $wc = New-Object net.webclient
#    try {
#        Write-Host -ForegroundColor green "INFO: Downloading latest execution script..."
#        $wc.Downloadfile($CISCRIPT_DEFAULT_LOCATION, $CISCRIPT_LOCAL_LOCATION)
#    } 
#    catch [System.Net.WebException]
#    {
#        Throw ("Failed to download: $_")
#    }
#    & $CISCRIPT_LOCAL_LOCATION
# -------------------------------------------------------------------------------------------

$SCRIPT_VER="13-Jul-2016 09:59 PDT" 

# Dismount-MountedVHDs unmounts any VHDs which may be still mounted from a previous run
Function Nuke-Everything {
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        Write-Host -ForegroundColor green "INFO: Nuke-Everything..."
        $containerCount = ($(docker ps -aq | Measure-Object -line).Lines) 
        if (-not $LastExitCode -eq 0) {
            Throw "ERROR: Failed to get container count from control daemon while nuking"
        }

        Write-Host -ForegroundColor green "INFO: Container count on control daemon to delete is $containerCount"
        if ($(docker ps -aq | Measure-Object -line).Lines -gt 0) {
            docker rm -f $(docker ps -aq)
        }
        $imageCount=($(docker images --format "{{.Repository}}:{{.ID}}" | `
                        select-string -NotMatch "windowsservercore" | `
                        select-string -NotMatch "nanoserver" | `
                        select-string -NotMatch "docker" | `
                        Measure-Object -line).Lines)
        if ($imageCount -gt 0) {
            Write-Host -Foregroundcolor green "INFO: Non-base image count on control daemon to delete is $imageCount"
            docker rmi -f `
                $(docker images --format "{{.Repository}}:{{.ID}}" | `
                        select-string -NotMatch "windowsservercore" | `
                        select-string -NotMatch "nanoserver" | `
                        select-string -NotMatch "docker").ToString().Split(":")[1]
        }

        # Kill any spurious daemons. The '-' is IMPORTANT otherwise will kill the control daemon!
        $pids=$(get-process | where-object {$_.ProcessName -like 'dockerd-*'}).id
        foreach ($p in $pids) {
            Write-Host "INFO: Killing daemon with PID $p"
            Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
        }

        Stop-Process -name "cc1" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "link" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "compile" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "ld" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "go" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "git" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "git-remote-https" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null
        Stop-Process -name "integration-cli.test" -Force -ErrorAction SilentlyContinue 2>&1 | Out-Null

        # Detach any VHDs
        gwmi msvm_mountedstorageimage -namespace root/virtualization/v2 -ErrorAction SilentlyContinue | foreach-object {$_.DetachVirtualHardDisk() }

        # Stop any compute processes
        Get-ComputeProcess | Stop-ComputeProcess -Force

        # Delete the directory using our dangerous utility unless told not to
        if (Test-Path "$env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR") {
            if ($env:SKIP_ZAP_DUT -ne "") {
                Write-Host -ForegroundColor Green "INFO: Nuking $env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR"
                docker-ci-zap "-folder=$env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR"
            } else {
                Write-Host -ForegroundColor Cyan "WARN: Skip nuking $env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR"
            }
        }

    } catch {
        # Don't throw any errors onwards Throw $_
    }
}

Try {
    Write-Host -ForegroundColor Yellow "INFO: Started at $(date)..."
    Write-Host  -ForegroundColor Green "INFO: Script version $SCRIPT_VER"
    Set-PSDebug -Trace 0  # 1 to turn on

    # Git version
    Write-Host  -ForegroundColor Green "INFO: Running $(git version)"

    # OS Version
    $bl=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion"  -Name BuildLabEx).BuildLabEx
    $a=$bl.ToString().Split(".")
    $Branch=$a[3]
    $Build=$a[0]+"."+$a[1]+"."+$a[4]
    Write-Host -ForegroundColor green "INFO: Branch:$Branch Build:$Build"

    # List the environment variables
    Get-ChildItem Env:

    # PR
    if (-not ($env:PR -eq $Null)) {
        echo "INFO: PR#$env:PR (https://github.com/docker/docker/pull/$env:PR)"
    }

    # Make sure docker is installed
    if ((Get-Command "docker" -ErrorAction SilentlyContinue) -eq $null) {
        Throw "ERROR: docker is not installed or not found on path"
    }

    # Make sure go is installed
    if ((Get-Command "go" -ErrorAction SilentlyContinue) -eq $null) {
        Throw "ERROR: go is not installed or not found on path"
    }

    # Make sure golint is installed
    if ((Get-Command "golint" -ErrorAction SilentlyContinue) -eq $null) {
        Throw "ERROR: golint is not installed or not found on path"
        Throw "ERROR: golint is not installed or not found on path"
    }

    # Make sure docker-ci-zap is installed
    if ((Get-Command "docker-ci-zap" -ErrorAction SilentlyContinue) -eq $null) {
        Throw "ERROR: docker-ci-zap is not installed or not found on path"
    }

    # Make sure SOURCES_DRIVE is set
    if ($env:SOURCES_DRIVE -eq $Null) {
        Throw "ERROR: Environment variable SOURCES_DRIVE is not set"
    }

    # Make sure TESTRUN_DRIVE is set
    if ($env:TESTRUN_DRIVE -eq $Null) {
        Throw "ERROR: Environment variable TESTRUN_DRIVE is not set"
    }

    # Make sure SOURCES_SUBDIR is set
    if ($env:SOURCES_SUBDIR -eq $Null) {
        Throw "ERROR: Environment variable SOURCES_SUBDIR is not set"
    }

    # Make sure TESTRUN_SUBDIR is set
    if ($env:TESTRUN_SUBDIR -eq $Null) {
        Throw "ERROR: Environment variable TESTRUN_SUBDIR is not set"
    }

    # SOURCES_DRIVE\SOURCES_SUBDIR must be a directory and exist
    if (-not (Test-Path -PathType Container "$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR")) {
        Throw "ERROR: $env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR must be an existing directory"
    }


    # Create the TESTRUN_DRIVE\TESTRUN_SUBDIR if it does not already exist
    New-Item -ItemType Directory -Force -Path "$env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR" -ErrorAction SilentlyContinue | Out-Null

    Write-Host  -ForegroundColor Green "INFO: Configured sources under $env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\..."
    Write-Host  -ForegroundColor Green "INFO: Configured test run under $env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR\..."

    # Set the GOPATH to the root and the vendor directory
    $env:GOPATH="$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\src\github.com\docker\docker\vendor;$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR"
    Write-Host -ForegroundColor Green "INFO: GOPATH set to $env:GOPATH"

    # Check the intended source location is a directory
    if (-not (Test-Path -PathType Container "$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\src\github.com\docker\docker" -ErrorAction SilentlyContinue)) {
        Throw "ERROR: $env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\src\github.com\docker\docker is not a directory!"
    }

    # Make sure we start at the root of the sources
    cd "$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\src\github.com\docker\docker"
    Write-Host  -ForegroundColor Green "INFO: Running in $(pwd)"

    # Make sure we are in repo
    if (-not (Test-Path -PathType Leaf -Path ".\Dockerfile.windows")) {
        Throw "$(pwd) does not container Dockerfile.Windows!"
    }
    Write-Host  -ForegroundColor Green "INFO: Github docker/docker repository was found"

    # Make sure windowsservercore image is installed
    $ErrorActionPreference = "SilentlyContinue"
    $build = $(docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "windowsservercore" | select-String -NotMatch "latest")
    $ErrorActionPreference = "Stop"

    if ($build -eq $null) {
        Write-Host  -ForegroundColor Green "INFO: Loading windowsservercore.tar. This may take some time..."
        $ErrorActionPreference = "SilentlyContinue"
        docker load -i c:\baseimages\windowsservercore.tar
        $ErrorActionPreference = "Stop"
        if (-not $LastExitCode -eq 0) {
            Throw "ERROR: Failed to load c:\baseimages\windowsservercore.tar"
        }

        Write-Host  -ForegroundColor Green "INFO: docker load of windowsservercore completed successfully"
        # Get the build now as we just loaded it
        $ErrorActionPreference = "SilentlyContinue"
        $build = $(docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "windowsservercore" | select-String -NotMatch "latest").ToString().Split(":")[1]
        $ErrorActionPreference = "Stop"

        if ($build -eq "") {
            Throw "ERROR: Could not find build even after loading it"
        }
        Write-Host  -ForegroundColor Green "INFO: Build is $build"
    }

    # Guaranteed is installed now, so can do ToString() without hitting an exception
    $ErrorActionPreference = "SilentlyContinue"
    $build = $(docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "windowsservercore" | select-String -NotMatch "latest").ToString().Split(":")[1]
    $ErrorActionPreference = "Stop"

    # Get the name. We started prefixing microsoft/ around 2016 TP5 6D
    $ErrorActionPreference = "SilentlyContinue"
    $imageName = $(docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "windowsservercore" | select-String -NotMatch "latest").ToString().Split(":")[0]
    $ErrorActionPreference = "Stop"
    if ($imageName -eq "") {
        Throw "ERROR: Could not find windowsservercore image"
    }
    Write-Host  -ForegroundColor Green "INFO: Image name is $imageName"

    # Tag it as latest if not already tagged
    if ($(docker images | select -skip 1 | select-string "windowsservercore" | select-String -NotMatch $build | Measure-Object -line).Lines -ne 1) {
        docker tag "$imagename`:$build" "windowsservercore`:latest"
        if ($LastExitCode -ne 0) {
            docker images
            Throw "ERROR: Failed to tag $imagename`:$build as windowsservercore`:latest"
        }
        Write-Host  -ForegroundColor Green "INFO: Tagged $imageName`:$build as windowsservercore`:latest"
    }
    
    # Provide the docker version for debugging purposes.
    Write-Host  -ForegroundColor Green "INFO: Docker version of control daemon"
    Write-Host
    $ErrorActionPreference = "SilentlyContinue"
    docker version
    $ErrorActionPreference = "Stop"
    if (-not($LastExitCode -eq 0)) {
        Write-Host 
        Write-Host  -ForegroundColor Green "---------------------------------------------------------------------------"
        Write-Host  -ForegroundColor Green " Failed to get a response from the control daemon. It may be down."
        Write-Host  -ForegroundColor Green " Try re-running this CI job, or ask on #docker-dev or #docker-maintainers"
        Write-Host  -ForegroundColor Green " to see if the the daemon is running. Also check the nssm configuration."
        Write-Host  -ForegroundColor Green " DOCKER_HOST is set to $DOCKER_HOST."
        Write-Host  -ForegroundColor Green "---------------------------------------------------------------------------"
        Write-Host 
        Throw "ERROR: The control daemon does not appear to be running."
    }
    Write-Host

    # Same as above, but docker info
    Write-Host  -ForegroundColor Green "INFO: Docker info of control daemon"
    Write-Host
    $ErrorActionPreference = "SilentlyContinue"
    docker info
    $ErrorActionPreference = "Stop"
    echo $LastExitCode
    if (-not($LastExitCode -eq 0)) {
        Throw "ERROR: The control daemon does not appear to be running."
    }
    Write-Host

    # Get the commit has and verify we have something
    $ErrorActionPreference = "SilentlyContinue"
    $COMMITHASH=$(git rev-parse --short HEAD)
    $ErrorActionPreference = "Stop"
    if (-not($LastExitCode -eq 0)) {
        Throw "ERROR: Failed to get commit hash. Are you sure this is a docker repository?"
    }
    Write-Host  -ForegroundColor Green "INFO: Commit hash is $COMMITHASH"

    # Nuke everything and go back to our sources after
    Nuke-Everything
    cd "$env:SOURCES_DRIVE`:\$env:SOURCES_SUBDIR\src\github.com\docker\docker"

    # Redirect to a temporary location. 
    $TEMPORIG=$env:TEMP
    $env:TEMP="$env:TESTRUN_DRIVE`:\$env:TESTRUN_SUBDIR\CI-$COMMITHASH"
    $env:USERPROFILE="$TEMP\userprofile"
    $env:LOCALAPPDATA="$TEMP\localappdata"
    $errorActionPreference='Stop'
    New-Item -ItemType Directory "$env:TEMP" -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory "$env:TEMP\userprofile" -ErrorAction SilentlyContinue  | Out-Null
    New-Item -ItemType Directory "$env:TEMP\localappdata" -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory "$env:TEMP\binary" -ErrorAction SilentlyContinue | Out-Null
    Write-Host -ForegroundColor Green "INFO: Location for testing is $env:TEMP"

    # CI Integrity check - ensure we are using the same version of go as present in the Dockerfile
    $warnGoVersionAtEnd=0
    $ErrorActionPreference = "SilentlyContinue"
    $goVersionDockerfile=$(Get-Content ".\Dockerfile" | Select-String "ENV GO_VERSION").ToString().Split(" ")[2]
    $goVersionInstalled=$(go version).ToString().Split(" ")[2].SubString(2)
    $ErrorActionPreference = "Stop"
    Write-Host  -ForegroundColor Green "INFO: Validating installed GOLang version $goVersionInstalled is correct..."
    if (-not($goVersionInstalled -eq $goVersionDockerfile)) {
        $warnGoVersionAtEnd=1
    }

    # CI Integrity check - ensure Dockerfile.windows and Dockerfile go versions match
    $goVersionDockerfileWindows=$(Get-Content ".\Dockerfile.windows" | Select-String "ENV GO_VERSION").ToString().Replace("ENV GO_VERSION=","").Replace("\","").Trim()
    Write-Host  -ForegroundColor Green "INFO: Validating GOLang consistency in Dockerfile.windows..."
    if (-not ($goVersionDockerfile -eq $goVersionDockerfileWindows)) {
        Throw "ERROR: Mismatched GO versions between Dockerfile and Dockerfile.windows. Update your PR to ensure that both files are updated and in sync."
    }

    # Build the image
    Write-Host  -ForegroundColor Cyan "`n`nINFO: Building the image from Dockerfile.windows at $(Get-Date)..."
    Write-Host
    $ErrorActionPreference = "SilentlyContinue"
    $Duration=$(Measure-Command { docker build -t docker -f Dockerfile.windows . | Out-Host })
    $ErrorActionPreference = "Stop"
    if (-not($LastExitCode -eq 0)) {
        Throw "ERROR: Failed to build image from Dockerfile.windows"
    }

    Write-Host  -ForegroundColor Green "INFO: Image build ended at $(Get-Date). Duration`:$Duration"

    # Build the binary in a container unless asked to skip it
    if ($env:SKIP_BINARY_BUILD -eq $null) {
        Write-Host  -ForegroundColor Cyan "`n`nINFO: Building the test binaries at $(Get-Date)..."
        $ErrorActionPreference = "SilentlyContinue"
        docker rm -f $COMMITHASH 2>&1 | Out-Null
        $Duration=$(Measure-Command {     docker run --name $COMMITHASH docker sh -c 'cd /c/go/src/github.com/docker/docker; hack/make.sh binary' | Out-Host })
        $ErrorActionPreference = "Stop"
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Failed to build binary"
        }
        Write-Host  -ForegroundColor Green "INFO: Binaries build ended at $(Get-Date). Duration`:$Duration"

        # Copy the binaries out of the container
        $v=$(Get-Content ".\VERSION" -raw).ToString().Replace("`n","").Trim()
        $contPath="$COMMITHASH`:c`:\go\src\github.com\docker\docker\bundles\$v"
        $ErrorActionPreference = "SilentlyContinue"
        docker cp "$contPath\binary-client\docker.exe" $env:TEMP\binary\
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Failed to docker cp the client binary (docker.exe) from $contPath\binary-client\ to $env:TEMP\binary"
        }
        docker cp "$contPath\binary-daemon\dockerd.exe" $env:TEMP\binary\
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Failed to docker cp the daemon binary (dockerd.exe) from $contPath\binary-daemon\ to $env:TEMP\binary"
        }
        $ErrorActionPreference = "Stop"

        # Copy the built dockerd.exe to dockerd-$COMMITHASH.exe so that easily spotted in task manager.
        Write-Host -ForegroundColor Green "INFO: Copying the built daemon binary to $env:TEMP\binary\dockerd-$COMMITHASH.exe..."
        Copy-Item $env:TEMP\binary\dockerd.exe $env:TEMP\binary\dockerd-$COMMITHASH.exe -Force -ErrorAction SilentlyContinue

        # Copy the built docker.exe to docker-$COMMITHASH.exe
        Write-Host -ForegroundColor Green "INFO: Copying the built client binary to $env:TEMP\binary\docker-$COMMITHASH.exe..."
        Copy-Item $env:TEMP\binary\docker.exe $env:TEMP\binary\docker-$COMMITHASH.exe -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host -ForegroundColor Yellow "WARN: Skipping building the binaries"
    }
    
    # Work out the the -H parameter for the daemon under test (DASHH_DUT) and client under test (DASHH_CUT)
    #$DASHH_DUT="npipe:////./pipe/$COMMITHASH" # Can't do remote named pipe
    #$ip = (resolve-dnsname $env:COMPUTERNAME -type A -NoHostsFile -LlmnrNetbiosOnly).IPAddress # Useful to tie down
    $DASHH_CUT="tcp://127.0.0.1`:2357"    # Not a typo for 2375!
    $DASHH_DUT="tcp://0.0.0.0:2357"       # Not a typo for 2375!

    # Arguments for the daemon under test
    $dutArgs=@()
    $dutArgs += "-H $DASHH_DUT"
    $dutArgs += "--graph $env:TEMP\daemon"
    $dutArgs += "--pidfile $env:TEMP\docker.pid"

    # Arguments: Are we starting the daemon under test in debug mode?
    if (-not ("$env:DOCKER_DUT_DEBUG" -eq "")) {
        Write-Host -ForegroundColor Green "INFO: Running the daemon under test in debug mode"
        $dutArgs += "-D"
    }

    # Arguments: Are we starting the daemon under test with Hyper-V containers as the default isolation?
    if (-not ("$env:DOCKER_DUT_HYPERV" -eq "")) {
        Write-Host -ForegroundColor Green "INFO: Running the daemon under test with Hyper-V containers as the default"
        $dutArgs += "--exec-opt isolation=hyperv"
    }

    # Start the daemon under test, ensuring everything is redirected to folders under $TEMP.
    # Important - we launch the -$COMMITHASH version so that we can kill it without
    # killing the control daemon. 
    Write-Host -ForegroundColor Green "INFO: Starting a daemon under test..."
    Write-Host -ForegroundColor Green "INFO: Args: $dutArgs"
    New-Item -ItemType Directory $env:TEMP\daemon -ErrorAction SilentlyContinue  | Out-Null

    # Cannot fathom why, but always writes to stderr....
    Start-Process "$env:TEMP\binary\dockerd-$COMMITHASH" `
                  -ArgumentList $dutArgs `
                  -RedirectStandardOutput "$env:TEMP\dut.out" `
                  -RedirectStandardError "$env:TEMP\dut.err" #`
                  #-NoNewWindow
    Write-Host -ForegroundColor Green "INFO: Process started successfully."
    $daemonStarted=1

    # Verify we can get the daemon under test to respond 
    $tries=20
    Write-Host -ForegroundColor Green "INFO: Waiting for the daemon under test to start..."
    while ($true) {
        $ErrorActionPreference = "SilentlyContinue"
        & "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" version 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"
        if ($LastExitCode -eq 0) {
            break
        }

        $tries--
        if ($tries -le 0) {
            $DumpDaemonLog=1
            Throw "ERROR: Failed to get a response from the daemon under test"
        }
        Write-Host -NoNewline "."
        sleep 1
    }
    Write-Host -ForegroundColor Green "INFO: Daemon under test started and replied!"

    # Provide the docker version of the daemon under test for debugging purposes.
    Write-Host -ForegroundColor Green "INFO: Docker version of the daemon under test"
    Write-Host 
    $ErrorActionPreference = "SilentlyContinue"
    & "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" version
    $ErrorActionPreference = "Stop"
    if ($LastExitCode -ne 0) {
        Throw "ERROR: The daemon under test does not appear to be running."
        $DumpDaemonLog=1
    }
    Write-Host

    # Same as above but docker info
    Write-Host -ForegroundColor Green "INFO: Docker info of the daemon under test"
    Write-Host 
    $ErrorActionPreference = "SilentlyContinue"
    & "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" info
    $ErrorActionPreference = "Stop"
    if ($LastExitCode -ne 0) {
        Throw "ERROR: The daemon under test does not appear to be running."
        $DumpDaemonLog=1
    }
    Write-Host

    # Same as above but docker images
    Write-Host -ForegroundColor Green "INFO: Docker images of the daemon under test"
    Write-Host 
    $ErrorActionPreference = "SilentlyContinue"
    & "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" images
    $ErrorActionPreference = "Stop"
    if ($LastExitCode -ne 0) {
        Throw "ERROR: The daemon under test does not appear to be running."
        $DumpDaemonLog=1
    }
    Write-Host


    # Make sure windowsservercore image is loaded/tagged in the daemon under test

    # A: Find out how many windowsservercore images are present which are not tagged 'latest'
    $ErrorActionPreference = "SilentlyContinue"
    $dutWSCNonLatestCount = $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" images | Select-String "windowsservercore" | Select-String -NotMatch "latest" | Measure-Object -line).Lines
    $ErrorActionPreference = "Stop"
    if (-not $LastExitCode -eq 0) {
        Throw "ERROR: Failed to get count of windowsservercore images not tagged latest in daemon under test"
    }

    # B: Not present at all, load it.
    if ($dutWSCNonLatestCount -eq 0 ) {
        # Not present. Load it. Assume under c:\baseimages.
        Write-Host -ForegroundColor Cyan "`n`nINFO: Loading windowsservercore.tar at $(Get-Date). This may take some time..."
        $ErrorActionPreference = "SilentlyContinue"
        & "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" load -i c:\baseimages\windowsservercore.tar
        $ErrorActionPreference = "Stop"
        if (-not $LastExitCode -eq 0) {
            Throw "ERROR: Failed to load c:\baseimages\windowsservercore.tar into daemon under test"
        }
        Write-Host  -ForegroundColor Green "INFO: docker load of windowsservercore completed successfully"
    }

    # C: Get the build now as we just loaded it
    $ErrorActionPreference = "SilentlyContinue"
    $dutWSCBuild= $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" images --format "{{.Repository}}:{{.Tag}}" | Select-String "windowsservercore" | select-String -NotMatch "latest").ToString().Split(":")[1]
    $ErrorActionPreference = "Stop"
    if (-not $LastExitCode -eq 0) {
        Throw "ERROR: Could not find build even after loading it"
    }
    Write-Host  -ForegroundColor Green "INFO: Build is $build"

    # D: Get the latest count
    $ErrorActionPreference = "SilentlyContinue"
    $dutWSCLatestCount = $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" images | Select-String "windowsservercore" | Select-String "latest" | Measure-Object -line).Lines
    $ErrorActionPreference = "Stop"
    if (-not $LastExitCode -eq 0) {
        Throw "ERROR: Failed to get count of windowsservercore images tagged latest in daemon under test"
    }

    # E: Tag the image as latest if necessary
    if ($dutWSCLatestCount -eq 0) {
        # We use $imagename as around 2016 TP5 6D we started having the microsoft/ prefix
        $ErrorActionPreference = "SilentlyContinue"
        $dutWSCLatestCount = $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" tag "$imagename`:$dutWSCBuild" "windowsservercore:latest")
        $ErrorActionPreference = "Stop"
        if (-not $LastExitCode -eq 0) {
            Throw "ERROR: Failed to tag $imagename`:$dutWSCBuild as latest"
        }
        Write-Host -ForegroundColor Green "INFO: Tagged $imagename`:$dutWSCBuild with latest"
    }

    # Run the validation tests inside a container unless SKIP_VALIDATION_TESTS is defined
    if ($env:SKIP_VALIDATION_TESTS -eq $null) {

        # Note sleep is necessary for Windows networking workaround (see dockerfile.Windows)
        # TODO: This should no longer be necessary (RS1+)
        Write-Host -ForegroundColor Cyan "INFO: Running validation tests at $(Get-Date)..."
        $ErrorActionPreference = "SilentlyContinue"
        $Duration= $(Measure-Command { & docker run --rm docker sh -c "cd /c/go/src/github.com/docker/docker; hack/make.sh validate-dco validate-gofmt validate-pkg" | Out-Host } )
        $ErrorActionPreference = "Stop"
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Validation tests failed"
        }
        Write-Host  -ForegroundColor Green "INFO: Validation tests ended at $(Get-Date). Duration`:$Duration"
    } else {
        Write-Host -ForegroundColor Yellow "WARN: Skipping validation tests"
    }

    # Run the unit tests inside a container unless SKIP_UNIT_TESTS is defined
    if ($env:SKIP_UNIT_TESTS -eq $null) {
        Write-Host -ForegroundColor Cyan "INFO: Running unit tests at $(Get-Date)..."
        $ErrorActionPreference = "SilentlyContinue"
        $Duration= $(Measure-Command { & docker run --rm docker sh -c "cd /c/go/src/github.com/docker/docker; hack/make.sh test-unit" | Out-Host } )
        $ErrorActionPreference = "Stop"
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Unit tests failed"
        }
        Write-Host  -ForegroundColor Green "INFO: Unit tests ended at $(Get-Date). Duration`:$Duration"
    } else {
        Write-Host -ForegroundColor Yellow "WARN: Skipping unit tests"
    }

    # Add the busybox image. Needed for integration tests
    # Note - this superceeds .ensure-frozen-images-windows previously used in the shell-script version
    if ($env:SKIP_INTEGRATION_TESTS -eq $null) {
        $ErrorActionPreference = "SilentlyContinue"
        $bbCount = $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" images | Select-String "busybox" | Measure-Object -line).Lines
        $ErrorActionPreference = "Stop"
        if (-not($LastExitCode -eq 0)) {
            Throw "ERROR: Could not determine if busybox image is present"
        }
        if ($bbCount -eq 0) {
            Write-Host -ForegroundColor Green "INFO: Building busybox"
            $ErrorActionPreference = "SilentlyContinue"
            $(& "$env:TEMP\binary\docker-$COMMITHASH" "-H=$($DASHH_CUT)" build -t busybox https://raw.githubusercontent.com/jhowardmsft/busybox/master/Dockerfile)
            $ErrorActionPreference = "Stop"
            if (-not($LastExitCode -eq 0)) {
                Throw "ERROR: Failed to build busybox image"
            }
        }
    }

    # Run the integration tests unless SKIP_INTEGRATION_TESTS is defined
    if ($env:SKIP_INTEGRATION_TESTS -eq $null) {
        Write-Host -ForegroundColor Cyan "INFO: Running integration tests at $(Get-Date)..."
        $ErrorActionPreference = "SilentlyContinue"

        # Jumping through hoop craziness. Don't ask! Parameter parsing, powershell, go, parameters starting "-check."... :(
        # Just dump it to a file and pass through in a volume with the binaries
        $c=" `
            `$ErrorActionPreference='Stop'; `
            `$env:PATH='c:\target;'+`$env:PATH; `
            `$env:DOCKER_HOST='tcp://172.16.0.1:2357'; `
            `$cliArgs=@(); `
            `$cliArgs+=`"test`"; 
           "

        # Makes is quicker for debugging to be able to run only a subset of the integration tests
        if ($env:INTEGRATION_TEST_NAME -ne $null) {
            $c += " `$cliArgs+=`"-check.f $env:INTEGRATION_TEST_NAME`";"
            Write-Host -ForegroundColor Yellow "WARN: Only running integration tests matching $env:INTEGRATION_TEST_NAME"
        }

        $c+=" `
            `$cliArgs+=`"-check.v`"; `
            `$cliArgs+=`"-check.timeout=240m`"; `
            `$cliArgs+=`"-test.timeout=360m`"; `
            cd \go\src\github.com\docker\docker\integration-cli;         `
            echo `$cliArgs; `
            Start-Process -Wait -NoNewWindow -FilePath go -ArgumentList `$cliArgs `
           "
        $c | Out-File -Force "$env:TEMP\binary\runIntegrationCLI.ps1"
        $Duration= $(Measure-Command { & docker run --rm -v "$env:TEMP\binary`:c:\target" --entrypoint "powershell" --workdir "c`:\target" docker ".\runIntegrationCLI.ps1"; $ec=$LastExitCode | Out-Host } )
        $ErrorActionPreference = "Stop"
        if (-not($ec -eq 0)) {
            Throw "ERROR: Integration tests failed"
        }
        Write-Host  -ForegroundColor Green "INFO: Integration tests ended at $(Get-Date). Duration`:$Duration"
    }else {
        Write-Host -ForegroundColor Yellow "WARN: Skipping integration tests"
    }

    # Stop the daemon under test
    if ($daemonStarted -eq 1) {
        if (Test-Path "$env:TEMP\docker.pid") {
            $p=Get-Content "$env:TEMP\docker.pid" -raw
            if ($p -ne $null) {
                Write-Host -ForegroundColor green "INFO: Stopping daemon under test"
                taskkill -f -t -pid $p
                Remove-Item "$env:TEMP\docker.pid" -force -ErrorAction SilentlyContinue
                sleep 5
            }
        }
    }

    Write-Host -ForegroundColor Green "INFO: Completed successfully at $(Get-Date)."
    exit 0
}
Catch [Exception] {
    Write-Host -ForegroundColor Red ("`r`n`r`nERROR: Failed '$_' at $(Get-Date)")
    Write-Host "`n`n"
    # Throw the error onwards to ensure Jenkins captures it.
    $host.SetShouldExit(1)
}
Finally {
    $ErrorActionPreference="SilentlyContinue"
    Write-Host  -ForegroundColor Green "INFO: Tidying up at end of run"

    # Dump the daemon log if asked to 
    if ($daemonStarted -eq 1) {
        if ($dumpDaemonLog -eq 1) {
            Write-Host -ForegroundColor Cyan "----------- DAEMON LOG ------------"
            Get-Content "$env:TEMP\dut.err" -ErrorAction SilentlyContinue | Write-Host -ForegroundColor Cyan
            Write-Host -ForegroundColor Cyan "----------- END DAEMON LOG --------"
        }
    }

    # Save the daemon under test log
    if ($daemonStarted -eq 1) {
        Write-Host -ForegroundColor Green "INFO: Saving the daemon under test log ($env:TEMP\dut.err) to $TEMPORIG\CIDUT.log"
        Copy-Item  "$env:TEMP\dut.err" "$TEMPORIG\CIDUT.log" -Force -ErrorAction SilentlyContinue
    }

    # Warning about Go Version
    if ("$warnGoVersionAtEnd" -eq 1) {
        Write-Host
        Write-Host -ForegroundColor Red "---------------------------------------------------------------------------"
        Write-Host -ForegroundColor Red "WARN: CI should be using go version $goVersionDockerfile, but it is using $goVersionInstalled"
        Write-Host
        Write-Host -ForegroundColor Red "        This CI server needs updating. Please ping #docker-dev or"
        Write-Host -ForegroundColor Red "        #docker-maintainers."
        Write-Host -ForegroundColor Red "---------------------------------------------------------------------------"
        Write-Host
    }

    cd "$env:SOURCES_DRIVE\$env:SOURCES_SUBDIR" -ErrorAction SilentlyContinue
    Nuke-Everything
    Write-Host -ForegroundColor Yellow "INFO: End of executeCI at $(date)"

    $Dur=New-TimeSpan -Start $StartTime -End $(Get-Date)
    Write-Host -ForegroundColor Yellow "INFO: Duration $Dur"
}