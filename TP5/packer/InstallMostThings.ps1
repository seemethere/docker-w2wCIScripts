#-----------------------
# InstallMostThings.ps1
#-----------------------


# Version configuration. We put them here rather than in packer variables so that this script block can be run on any machine,
# not just a CI server. Note Git is a full location, not a version as interim releases have more than just the version in the path.
Write-Host "INFO: Executing InstallMostThings.ps1"
$GIT_LOCATION="https://github.com/git-for-windows/git/releases/download/v2.7.4.windows.1/Git-2.7.4-64-bit.exe"
$JDK_LOCATION="http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jdk-8u77-windows-x64.exe"
$LITEIDE_LOCATION="https://sourceforge.net/projects/liteide/files/X28/liteidex28.windows-qt4.zip/download"
$NPP_LOCATION="https://notepad-plus-plus.org/repository/6.x/6.9/npp.6.9.Installer.exe"
$PuTTY_LOCATION="https://the.earth.li/~sgtatham/putty/latest/x86/putty.zip"
$JQ_LOCATION="https://github.com/stedolan/jq/releases/download/jq-1.5/jq-win64.exe"
$SQLITE_LOCATION="https://www.sqlite.org/2016/sqlite-amalgamation-3110100.zip"
$DOCKER_LOCATION="https://master.dockerproject.org/windows/amd64/docker.exe"


Write-Host " Git:       $GIT_LOCATION"
Write-Host " JDK:       $JDK_LOCATION"
Write-Host " LiteIDE:   $LITEIDE_LOCATION"
Write-Host " Notepad++: $NPP_LOCATION"
Write-Host " PuTTY:     $PuTTY_LOCATION"
Write-Host " JQ:        $JQ_LOCATION"
Write-Host " SQLite:    $SQLITE_LOCATION"
Write-Host " Docker:    $DOCKER_LOCATION"

# Stop on error
$ErrorActionPreference="stop"


# Set PATH for machine and current session
Write-Host "INFO: Updating path..."
$env:Path="$env:SystemDrive\Program Files (x86)\Notepad++;$env:Path;$env:SystemDrive\gcc\bin;$env:SystemDrive\go\bin;$env:SystemDrive\tools;$env:SystemDrive\gopath\bin;$env:SystemDrive\liteide\bin;$env:SystemDrive\pstools;$env:SystemDrive\putty;$env:SystemDrive\jdk\bin;$env:SystemDrive\git\cmd;$env:SystemDrive\git\bin;$env:SystemDrive\git\usr\bin"
[Environment]::SetEnvironmentVariable("Path",$env:Path, "Machine")


# Work out the version of GO from dockerfile.Windows currently on master
Write-Host "INFO: Calculating golang version..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/docker/docker/master/Dockerfile.windows","$env:Temp\dockerfile.Windows")
$pattern=select-string $env:Temp\dockerfile.windows -pattern "GO_VERSION="
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
$GO_VERSION=$line.Substring($index+1)
Write-Host "INFO: Need GO version $GO_VERSION"


# Work out the commit of RSRC from dockerfile.Windows we downloaded above
Write-Host "INFO: Calculating RSRC version..."
$pattern=select-string $env:Temp\dockerfile.windows -pattern "RSRC_COMMIT="
if ($pattern.Count -lt 1) {
	Throw "Could not find RSRC_COMMIT= in dockerfile.Windows!"
}
$line=$pattern[0]
$line=$line -replace "\\",""
$line=$line.TrimEnd()
$index=$line.indexof("=")
if ($index -eq -1) {
	Throw "Could not find '=' in the RSRC_COMMIT line of dockerfile.Windows"
}
$RSRC_COMMIT=$line.Substring($index+1)
Write-Host "INFO: Need RSRC at $RSRC_COMMIT"

# Create directory for our local run scripts
mkdir $env:SystemDrive\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null


# Downloads scripts for performing local runs.
Write-Host "INFO: Downloading CI scripts for local run into c:\scripts"
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/executeCI.sh","$env:SystemDrive\scripts\executeCI.sh")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/cleanupCI.sh","$env:SystemDrive\scripts\cleanupCI.sh")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/TP5/RunOnCIServer.cmd","$env:SystemDrive\scripts\RunOnCIServer.cmd")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/Invoke-DockerCI/master/Invoke-DockerCI.ps1","$env:SystemDrive\scripts\Invoke-DockerCI.ps1")


# Download and install golang, plus set GOROOT and GOPATH for machine and current session.
Write-Host "INFO: Downloading go..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://storage.googleapis.com/golang/go$GO_VERSION.windows-amd64.msi","$env:Temp\go.msi")
Write-Host "INFO: Installing go..."
Start-Process msiexec -ArgumentList "-i $env:Temp\go.msi -quiet" -Wait
Write-Host "INFO: Updating GOROOT and GOPATH..."
[Environment]::SetEnvironmentVariable("GOROOT", "$env:SystemDrive\go", "Machine")
$env:GOROOT="$env:SystemDrive\go"
[Environment]::SetEnvironmentVariable("GOPATH", "$env:SystemDrive\gopath", "Machine")
$env:GOPATH="$env:SystemDrive\gopath"


# Download and install git
Write-Host "INFO: Downloading git..."
$wc=New-Object net.webclient;$wc.Downloadfile("$GIT_LOCATION","$env:Temp\gitsetup.exe")
Write-Host "INFO: Installing git..."
Start-Process $env:Temp\gitsetup.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /DIR=$env:SystemDrive\git" -Wait


# Download and install GCC
Write-Host "INFO: Downloading compiler 1 of 3..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/gcc.zip","$env:Temp\gcc.zip")
Write-Host "INFO: Downloading compiler 2 of 3..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/runtime.zip","$env:Temp\runtime.zip")
Write-Host "INFO: Downloading compiler 3 of 3..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/binutils.zip","$env:Temp\binutils.zip")
Write-Host "INFO: Extracting compiler 1 of 3..."
Expand-Archive $env:Temp\gcc.zip $env:SystemDrive\gcc -Force
Write-Host "INFO: Extracting compiler 2 of 3..."
Expand-Archive $env:Temp\runtime.zip $env:SystemDrive\gcc -Force
Write-Host "INFO: Extracting compiler 3 of 3..."
Expand-Archive $env:Temp\binutils.zip $env:SystemDrive\gcc -Force


# Perform an initial clone so that we can do a local verification outside of jenkins through c:\scripts\doit.sh
Write-Host "INFO: Cloning docker sources..."
Start-Process -wait git -ArgumentList "clone https://github.com/docker/docker $env:SystemDrive\gopath\src\github.com\docker\docker"


# Install utilities for zapping CI, signalling the daemon and for linting changes. These go to c:\gopath\bin
Write-Host "INFO: Downloading utilities..."
Start-Process -wait go -ArgumentList "get -u github.com/jhowardmsft/docker-ci-zap"
Start-Process -wait go -ArgumentList "get -u github.com/jhowardmsft/docker-signal"
Start-Process -wait go -ArgumentList "get -u github.com/golang/lint/golint"


# Build RSRC for embedding resources in the binary (manifest and icon)
Write-Host "INFO: Building RSRC..."
Start-Process -wait git -ArgumentList "clone https://github.com/akavel/rsrc.git $env:SystemDrive\go\src\github.com\akavel\rsrc"
cd $env:SystemDrive\go\src\github.com\akavel\rsrc
Start-Process -wait git -ArgumentList "checkout -q $RSRC_COMMIT"
Start-Process -wait go -ArgumentList "install -v"


# Download docker.
Write-Host "INFO: Downloading docker..."
$wc=New-Object net.webclient;$wc.Downloadfile($DOCKER_LOCATION,"$env:SystemRoot\System32\docker.exe")


# Download and install Notepad++
Write-Host "INFO: Downloading Notepad++"
$wc=New-Object net.webclient;$wc.Downloadfile($NPP_LOCATION,"$env:Temp\nppinstaller.exe")
Write-Host "INFO: Installing Notepad++"
Start-Process -wait $env:Temp\nppinstaller.exe -ArgumentList "/S"


# Download and install LiteIDE
Write-Host "INFO: Downloading LiteIDE..."
$wc=New-Object net.webclient;$wc.Downloadfile($LITEIDE_LOCATION,"$env:Temp\liteide.zip")
Write-Host "INFO: Installing LiteIDE..."
Expand-Archive $env:Temp\liteide.zip $env:SystemDrive\


# Download and install PSTools
Write-Host "INFO: Downloading PSTools..."
$wc=New-Object net.webclient;$wc.Downloadfile("https://download.sysinternals.com/files/PSTools.zip","$env:Temp\pstools.zip")
Write-Host "INFO: Installing PSTools..."
Expand-Archive $env:Temp\pstools.zip c:\pstools


# Add registry keys for enabling nanoserver
Write-Host "INFO: Adding nanoserver registry keys..."
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipVersionCheck /t REG_DWORD /d 2 /f | Out-Null
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipSkuCheck /t REG_DWORD /d 2 /f | Out-Null

# Stop Server Manager from opening at logon
REG ADD "HKLM\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f | Out-Null


# Download and install PuTTY
Write-Host "INFO: Downloading PuTTY..."
$wc=New-Object net.webclient;$wc.Downloadfile($PuTTY_LOCATION,"$env:Temp\putty.zip")
Write-Host "INFO: Installing PuTTY..."
Expand-Archive $env:Temp\putty.zip $env:SystemDrive\putty


# Install jq
Write-Host "INFO: Downloading JQ..."
$wc=New-Object net.webclient;$wc.Downloadfile($JQ_LOCATION,"$env:SystemRoot\system32\jq.exe")


# Download and install Java Development Kit 
# http://stackoverflow.com/questions/10268583/downloading-java-jdk-on-linux-via-wget-is-shown-license-page-instead
Write-Host "INFO: Downloading JDK..."
$wc=New-Object net.webclient;
$wc.Headers.Set("Cookie","oraclelicense=accept-securebackup-cookie")
$wc.Downloadfile("$JDK_LOCATION","$env:Temp\jdkinstaller.exe")
Write-Host "INFO: Installing JDK..."
Start-Process -Wait "$env:Temp\jdkinstaller.exe" -ArgumentList "/s /INSTALLDIRPUBJRE=$env:SystemDrive\jdk"


# Download and compile sqlite3.dll from amalgamation sources in case of a dynamically linked docker binary
Write-Host "INFO: Downloading SQLite sources..."
$wc=New-Object net.webclient;$wc.Downloadfile($SQLITE_LOCATION,"$env:Temp\sqlite.zip")
Write-Host "INFO: Extracting SQLite sources..."
Expand-Archive $env:Temp\sqlite.zip $env:SystemDrive\sqlite
cd $env:SystemDrive\sqlite
move .\sql*\* .
Write-Host "INFO: Compiling sqlite3.dll..."
Start-Process -wait gcc -ArgumentList "-shared sqlite3.c -o sqlite3.dll"
copy sqlite3.dll $env:SystemRoot\system32

Write-Host "INFO: InstallMostThings.ps1 completed"

