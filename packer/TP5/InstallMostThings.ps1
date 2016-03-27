#-----------------------
# InstallMostThings.ps1
#-----------------------


# Version configuration. We put them here rather than in packer variables so that this script block can be run on any machine,
# not just a CI server. Note Git is a full location, not a version as interim releases have more than just the version in the path.
$GIT_LOCATION="https://github.com/git-for-windows/git/releases/download/v2.7.4.windows.1/Git-2.7.4-64-bit.exe"
$JDK_LOCATION="http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jdk-8u77-windows-x64.exe"
$LITEIDE_LOCATION="https://sourceforge.net/projects/liteide/files/X28/liteidex28.windows-qt4.zip/download"
$NPP_LOCATION="https://notepad-plus-plus.org/repository/6.x/6.9/npp.6.9.Installer.exe"
$PuTTY_LOCATION="https://the.earth.li/~sgtatham/putty/latest/x86/putty.zip"
$JQ_LOCATION="https://github.com/stedolan/jq/releases/download/jq-1.5/jq-win64.exe"
$SQLITE_LOCATION="https://www.sqlite.org/2016/sqlite-amalgamation-3110100.zip"
$DOCKER_LOCATION="https://master.dockerproject.org/windows/amd64/docker.exe"


# Stop on error
$ErrorActionPreference="stop"


# Set PATH for machine and current session
$env:Path="$env:SystemDrive\Program Files (x86)\Notepad++;$env:SystemDrive\git\cmd;$env:SystemDrive\git\bin;$env:SystemDrive\git\usr\bin;$env:Path;$env:SystemDrive\gcc\bin;$env:SystemDrive\go\bin;$env:SystemDrive\tools;$env:SystemDrive\gopath\bin;$env:SystemDrive\liteide\bin;$env:SystemDrive\pstools;$env:SystemDrive\putty;$env:SystemDrive\jdk\bin"
[Environment]::SetEnvironmentVariable("Path",$env:Path, "Machine")


# Work out the version of GO from dockerfile.Windows currently on master
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


# Work out the commit of RSRC from dockerfile.Windows we downloaded above
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


# Create directory for our local run scripts
mkdir $env:SystemDrive\scripts -ErrorAction SilentlyContinue


# Downloads scripts for performing local runs.
# BUGBUG - All except Invoke-DockerCI will eventually be in the docker source.
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/executeCI.sh","$env:SystemDrive\scripts\executeCI.sh")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/cleanupCI.sh","$env:SystemDrive\scripts\cleanupCI.sh")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/RunOnCIServer.cmd","$env:SystemDrive\scripts\RunOnCIServer.cmd")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-w2wCIScripts/master/Kill-LongRunningDocker.ps1","$env:SystemDrive\scripts\Kill-LongRunningDocker.ps1")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/Invoke-DockerCI/master/Invoke-DockerCI.ps1","$env:SystemDrive\scripts\Invoke-DockerCI.ps1")


# Download and install golang, plus set GOROOT and GOPATH for machine and current session.
$wc=New-Object net.webclient;$wc.Downloadfile("https://storage.googleapis.com/golang/go$GO_VERSION.windows-amd64.msi","$env:Temp\go.msi")
Start-Process msiexec -ArgumentList "-i $env:Temp\go.msi -quiet" -Wait
[Environment]::SetEnvironmentVariable("GOROOT", "$env:SystemDrive\go", "Machine")
$env:GOROOT="$env:SystemDrive\go"
[Environment]::SetEnvironmentVariable("GOPATH", "$env:SystemDrive\gopath", "Machine")
$env:GOPATH="$env:SystemDrive\gopath"


# Download and install git
$wc=New-Object net.webclient;$wc.Downloadfile("$GIT_LOCATION","$env:Temp\gitsetup.exe")
Start-Process $env:Temp\gitsetup.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /DIR=$env:SystemDrive\git" -Wait


# Download and install GCC
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/gcc.zip","$env:Temp\gcc.zip")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/runtime.zip","$env:Temp\runtime.zip")
$wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/binutils.zip","$env:Temp\binutils.zip")
Expand-Archive $env:Temp\gcc.zip $env:SystemDrive\gcc -Force
Expand-Archive $env:Temp\runtime.zip $env:SystemDrive\gcc -Force
Expand-Archive $env:Temp\binutils.zip $env:SystemDrive\gcc -Force


# Perform an initial clone so that we can do a local verification outside of jenkins through c:\scripts\doit.sh
git clone https://github.com/docker/docker $env:SystemDrive\gopath\src\github.com\docker\docker


# Install utilities for zapping CI, signalling the daemon and for linting changes. These go to c:\gopath\bin
go get -u github.com/jhowardmsft/docker-ci-zap
go get -u github.com/jhowardmsft/docker-signal
go get -u github.com/golang/lint/golint


# Build RSRC for embedding resources in the binary (manifest and icon)
git clone https://github.com/akavel/rsrc.git $env:SystemDrive\go\src\github.com\akavel\rsrc
cd $env:SystemDrive\go\src\github.com\akavel\rsrc
git checkout -q $RSRC_COMMIT
go install -v


# Download docker.
$wc=New-Object net.webclient;$wc.Downloadfile($DOCKER_LOCATION,"$env:SystemRoot\System32\docker.exe")


# Download and install Notepad++
$wc=New-Object net.webclient;$wc.Downloadfile($NPP_LOCATION,"$env:Temp\nppinstaller.exe")
Start-Process -wait $env:Temp\nppinstaller.exe -ArgumentList "/S"


# Download and install LiteIDE
$wc=New-Object net.webclient;$wc.Downloadfile($LITEIDE_LOCATION,"$env:Temp\liteide.zip")
Expand-Archive $env:Temp\liteide.zip $env:SystemDrive\


# Download and install PSTools
$wc=New-Object net.webclient;$wc.Downloadfile("https://download.sysinternals.com/files/PSTools.zip","$env:Temp\pstools.zip")
Expand-Archive $env:Temp\pstools.zip c:\pstools


# Add registry keys for enabling nanoserver
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipVersionCheck /t REG_DWORD /d 2
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipSkuCheck /t REG_DWORD /d 2 


# Download and install PuTTY
$wc=New-Object net.webclient;$wc.Downloadfile($PuTTY_LOCATION,"$env:Temp\putty.zip")
Expand-Archive $env:Temp\putty.zip $env:SystemDrive\putty


# Install jq
$wc=New-Object net.webclient;$wc.Downloadfile($JQ_LOCATION,"$env:SystemRoot\system32\jq.exe")


# Download and install Java Development Kit 
# http://stackoverflow.com/questions/10268583/downloading-java-jdk-on-linux-via-wget-is-shown-license-page-instead
$wc=New-Object net.webclient;
$wc.Headers.Set("Cookie","oraclelicense=accept-securebackup-cookie")
$wc.Downloadfile("$JDK_LOCATION","$env:Temp\jdkinstaller.exe")
Start-Process -Wait "$env:Temp\jdkinstaller.exe" -ArgumentList "/s /INSTALLDIRPUBJRE=$env:SystemDrive\jdk"


# Download and compile sqlite3.dll from amalgamation sources in case of a dynamically linked docker binary
$wc=New-Object net.webclient;$wc.Downloadfile($SQLITE_LOCATION,"$env:Temp\sqlite.zip")
Expand-Archive $env:Temp\sqlite.zip $env:SystemDrive\sqlite
cd $env:SystemDrive\sqlite
move .\sql*\* .
gcc -shared sqlite3.c -o sqlite3.dll
copy sqlite3.dll $env:SystemRoot\system32


# Download and install Cygwin for SSH capability
Mkdir $env:SystemDrive\cygwin -erroraction silentlycontinue
$wc=New-Object net.webclient;$wc.Downloadfile("https://cygwin.com/setup-x86_64.exe","$env:SystemDrive\cygwinsetup.exe")
Start-Process $env:SystemDrive\cygwinsetup.exe -ArgumentList "-q -R $env:SystemDrive\cygwin --packages openssh openssl -l $env:SystemDrive\cygwin\packages -s http://mirrors.sonic.net/cygwin/" -Wait



