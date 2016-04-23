#-----------------------
# InstallMostThings.ps1
#-----------------------


# Version configuration. We put them here rather than in packer variables so that this script block can be run on any machine,
# not just a CI server. Note Git is a full location, not a version as interim releases have more than just the version in the path.
echo "$(date) InstallMostThings.ps1 starting" >> $env:SystemDrive\packer\configure.log
# 2.8 seems to have issues with path after installing. Need to sort this still. BUGBUG @jhowardmsft Ditto in dockerfile.Windows
#$GIT_LOCATION="https://github.com/git-for-windows/git/releases/download/v2.8.1.windows.1/Git-2.8.1-64-bit.exe"
$GIT_LOCATION="https://github.com/git-for-windows/git/releases/download/v2.7.2.windows.1/Git-2.7.2-64-bit.exe"
$JDK_LOCATION="http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jdk-8u77-windows-x64.exe"
$LITEIDE_LOCATION="https://sourceforge.net/projects/liteide/files/X28/liteidex28.windows-qt4.zip/download"
$NPP_LOCATION="https://notepad-plus-plus.org/repository/6.x/6.9.1/npp.6.9.1.Installer.exe"
$PuTTY_LOCATION="https://the.earth.li/~sgtatham/putty/latest/x86/putty.zip"
$JQ_LOCATION="https://github.com/stedolan/jq/releases/download/jq-1.5/jq-win64.exe"
$SQLITE_LOCATION="https://www.sqlite.org/2016/sqlite-amalgamation-3110100.zip"
$DOCKER_LOCATION="https://master.dockerproject.org/windows/amd64"

echo "$(date)  Git:       $GIT_LOCATION"         >> $env:SystemDrive\packer\configure.log
echo "$(date)  JDK:       $JDK_LOCATION"         >> $env:SystemDrive\packer\configure.log
echo "$(date)  LiteIDE:   $LITEIDE_LOCATION"     >> $env:SystemDrive\packer\configure.log
echo "$(date)  Notepad++: $NPP_LOCATION"        >> $env:SystemDrive\packer\configure.log
echo "$(date)  PuTTY:     $PuTTY_LOCATION"         >> $env:SystemDrive\packer\configure.log
echo "$(date)  JQ:        $JQ_LOCATION"         >> $env:SystemDrive\packer\configure.log
echo "$(date)  SQLite:    $SQLITE_LOCATION"     >> $env:SystemDrive\packer\configure.log
echo "$(date)  Docker:    $DOCKER_LOCATION"     >> $env:SystemDrive\packer\configure.log

# Stop on error
$ErrorActionPreference="stop"

try {

    # Set PATH for machine and current session
    echo "$(date) InstallMostThings.ps1 Updating path" >> $env:SystemDrive\packer\configure.log
    $env:Path="$env:SystemDrive\Program Files (x86)\Notepad++;$env:Path;$env:SystemDrive\gcc\bin;$env:SystemDrive\go\bin;$env:SystemDrive\pstools;$env:SystemDrive\gopath\bin;$env:SystemDrive\liteide\bin;$env:SystemDrive\pstools;$env:SystemDrive\putty;$env:SystemDrive\jdk\bin;$env:SystemDrive\git\cmd;$env:SystemDrive\git\bin;$env:SystemDrive\git\usr\bin"
    [Environment]::SetEnvironmentVariable("Path",$env:Path, "Machine")


    # Work out the version of GO from dockerfile.Windows currently on master
    echo "$(date) InstallMostThings.ps1 Working out GO version..." >> $env:SystemDrive\packer\configure.log
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
    echo "$(date) InstallMostThings.ps1 Need GO version $GO_VERSION" >> $env:SystemDrive\packer\configure.log

    # Work out the commit of RSRC from dockerfile.Windows we downloaded above
    echo "$(date) InstallMostThings.ps1 Working out RSRC version..." >> $env:SystemDrive\packer\configure.log
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
    echo "$(date) InstallMostThings.ps1 Need RSRC at $RSRC_COMMIT" >> $env:SystemDrive\packer\configure.log

    # Create directory for our local run scripts
    mkdir $env:SystemDrive\scripts -ErrorAction SilentlyContinue 2>&1 | Out-Null

    # Download and install golang, plus set GOROOT and GOPATH for machine and current session.
    echo "$(date) InstallMostThings.ps1 Downloading go..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://storage.googleapis.com/golang/go$GO_VERSION.windows-amd64.msi","$env:Temp\go.msi")
    echo "$(date) InstallMostThings.ps1 Installing go..." >> $env:SystemDrive\packer\configure.log
    Start-Process msiexec -ArgumentList "-i $env:Temp\go.msi -quiet" -Wait
    echo "$(date) InstallMostThings.ps1 Updating GOROOT and GOPATH..." >> $env:SystemDrive\packer\configure.log
    [Environment]::SetEnvironmentVariable("GOROOT", "$env:SystemDrive\go", "Machine")
    $env:GOROOT="$env:SystemDrive\go"
    [Environment]::SetEnvironmentVariable("GOPATH", "$env:SystemDrive\gopath", "Machine")
    $env:GOPATH="$env:SystemDrive\gopath"


    # Download and install git
    echo "$(date) InstallMostThings.ps1 Downloading git..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("$GIT_LOCATION","$env:Temp\gitsetup.exe")
    echo "$(date) InstallMostThings.ps1 Installing git..." >> $env:SystemDrive\packer\configure.log
    Start-Process $env:Temp\gitsetup.exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /DIR=$env:SystemDrive\git" -Wait


    # Download and install GCC
    echo "$(date) InstallMostThings.ps1 Downloading compiler 1 of 3..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/gcc.zip","$env:Temp\gcc.zip")
    echo "$(date) InstallMostThings.ps1 Downloading compiler 2 of 3..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/runtime.zip","$env:Temp\runtime.zip")
    echo "$(date) InstallMostThings.ps1 Downloading compiler 3 of 3..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://raw.githubusercontent.com/jhowardmsft/docker-tdmgcc/master/binutils.zip","$env:Temp\binutils.zip")
    echo "$(date) InstallMostThings.ps1 Extracting compiler 1 of 3..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\gcc.zip $env:SystemDrive\gcc -Force
    echo "$(date) InstallMostThings.ps1 Extracting compiler 2 of 3..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\runtime.zip $env:SystemDrive\gcc -Force
    echo "$(date) InstallMostThings.ps1 Extracting compiler 3 of 3..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\binutils.zip $env:SystemDrive\gcc -Force


    # Perform an initial clone so that we can do a local verification outside of jenkins through c:\scripts\doit.sh
    echo "$(date) InstallMostThings.ps1 Cloning docker sources..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait git -ArgumentList "clone https://github.com/docker/docker $env:SystemDrive\gopath\src\github.com\docker\docker"


    # Install utilities for zapping CI, signalling the daemon and for linting changes. These go to c:\gopath\bin
    echo "$(date) InstallMostThings.ps1 Downloading utilities..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait go -ArgumentList "get -u github.com/jhowardmsft/docker-ci-zap"
    Start-Process -wait go -ArgumentList "get -u github.com/jhowardmsft/docker-signal"
    Start-Process -wait go -ArgumentList "get -u github.com/golang/lint/golint"


    # Build RSRC for embedding resources in the binary (manifest and icon)
    # BUGBUG Remove after https://github.com/docker/docker/pull/22275
    echo "$(date) InstallMostThings.ps1 Building RSRC..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait git -ArgumentList "clone https://github.com/akavel/rsrc.git $env:SystemDrive\go\src\github.com\akavel\rsrc"
    cd $env:SystemDrive\go\src\github.com\akavel\rsrc
    Start-Process -wait git -ArgumentList "checkout -q $RSRC_COMMIT"
    Start-Process -wait go -ArgumentList "install -v"


    # Download docker client
    echo "$(date) InstallMostThings.ps1 Downloading docker.exe..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("$DOCKER_LOCATION/docker.exe","$env:SystemRoot\System32\docker.exe")

    # Download docker daemon
    echo "$(date) InstallMostThings.ps1 Downloading dockerd.exe..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("$DOCKER_LOCATION/dockerd.exe","$env:SystemRoot\System32\dockerd.exe")

    # Download and install Notepad++
    echo "$(date) InstallMostThings.ps1 Downloading Notepad++..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile($NPP_LOCATION,"$env:Temp\nppinstaller.exe")
    echo "$(date) InstallMostThings.ps1 Installing Notepad++..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait $env:Temp\nppinstaller.exe -ArgumentList "/S"


    # Download and install LiteIDE
    #echo "$(date) InstallMostThings.ps1 Downloading LiteIDE..." >> $env:SystemDrive\packer\configure.log
    #$wc=New-Object net.webclient;$wc.Downloadfile($LITEIDE_LOCATION,"$env:Temp\liteide.zip")
    #echo "$(date) InstallMostThings.ps1 Installing LiteIDE..." >> $env:SystemDrive\packer\configure.log
    #Expand-Archive $env:Temp\liteide.zip $env:SystemDrive\


    # Download and install PSTools
    echo "$(date) InstallMostThings.ps1 Downloading PSTools..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://download.sysinternals.com/files/PSTools.zip","$env:Temp\pstools.zip")
    echo "$(date) InstallMostThings.ps1 Installing PSTools..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\pstools.zip c:\pstools


    # Add registry keys for enabling nanoserver
    echo "$(date) InstallMostThings.ps1 Adding nano registry keys..." >> $env:SystemDrive\packer\configure.log
    REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipVersionCheck /t REG_DWORD /d 2 /f | Out-Null
    REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Windows Containers" /v SkipSkuCheck /t REG_DWORD /d 2 /f | Out-Null

    # Stop Server Manager from opening at logon
    echo "$(date) InstallMostThings.ps1 Turning off server manager at logon..." >> $env:SystemDrive\packer\configure.log
    REG ADD "HKLM\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f | Out-Null

    # Download and install PuTTY
    echo "$(date) InstallMostThings.ps1 Downloading PuTTY..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile($PuTTY_LOCATION,"$env:Temp\putty.zip")
    echo "$(date) InstallMostThings.ps1 Installing PuTTY..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\putty.zip $env:SystemDrive\putty

    # Install jq
    echo "$(date) InstallMostThings.ps1 Downloading JQ..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile($JQ_LOCATION,"$env:SystemRoot\system32\jq.exe")

    # Download and install Java Development Kit 
    # http://stackoverflow.com/questions/10268583/downloading-java-jdk-on-linux-via-wget-is-shown-license-page-instead
    echo "$(date) InstallMostThings.ps1 Downloading JDK..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;
    $wc.Headers.Set("Cookie","oraclelicense=accept-securebackup-cookie")
    $wc.Downloadfile("$JDK_LOCATION","$env:Temp\jdkinstaller.exe")
    echo "$(date) InstallMostThings.ps1 Installing JDK..." >> $env:SystemDrive\packer\configure.log
    Start-Process -Wait "$env:Temp\jdkinstaller.exe" -ArgumentList "/s /INSTALLDIRPUBJRE=$env:SystemDrive\jdk"

    # Download and compile sqlite3.dll from amalgamation sources in case of a dynamically linked docker binary
    echo "$(date) InstallMostThings.ps1 Downloading SQLite sources..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile($SQLITE_LOCATION,"$env:Temp\sqlite.zip")
    echo "$(date) InstallMostThings.ps1 Extracting SQLite sources..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive $env:Temp\sqlite.zip $env:SystemDrive\sqlite
    cd $env:SystemDrive\sqlite
    move .\sql*\* .
    echo "$(date) InstallMostThings.ps1 Compiling SQLite3.dll..." >> $env:SystemDrive\packer\configure.log
    Start-Process -wait gcc -ArgumentList "-shared sqlite3.c -o sqlite3.dll"
    copy sqlite3.dll $env:SystemRoot\system32

    # Install NSSM by extracting archive and placing in system32
    echo "$(date) InstallMostThings.ps1 downloading NSSM..." >> $env:SystemDrive\packer\configure.log
    $wc=New-Object net.webclient;$wc.Downloadfile("https://nssm.cc/release/nssm-2.24.zip","$env:Temp\nssm.zip")
    echo "$(date) InstallMostThings.ps1 extracting NSSM..." >> $env:SystemDrive\packer\configure.log
    Expand-Archive -Path $env:Temp\nssm.zip -DestinationPath $env:Temp
    echo "$(date) InstallMostThings.ps1 installing NSSM..." >> $env:SystemDrive\packer\configure.log
    Copy-Item $env:Temp\nssm-2.24\win64\nssm.exe $env:SystemRoot\System32

}
Catch [Exception] {
    echo "$(date) InstallMostThings.ps1 Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InstallMostThings.ps1 Completed." >> $env:SystemDrive\packer\configure.log
}  

