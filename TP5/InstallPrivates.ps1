#-----------------------
# InstallPrivates.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallPrivates.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    #--------------------------------------------------------------------------------------------
    # Configure Test Signing
    c:\privates\certutil -addstore root "c:\privates\testroot-sha2.cer"
    bcdedit /set "{current}" testsigning On

    #--------------------------------------------------------------------------------------------
    # Hack to retry networking up to 5 times - stops very common busybox not found. Andrew working on real fix post 4D.
    #echo "$(date) Phase2.ps1 Installing private HostNetSvc.dll..." >> $env:SystemDrive\packer\configure.log
    #copy c:\windows\system32\HostNetSvc.dll c:\windows\system32\HostNetSvc.orig.dll
    #c:\privates\sfpcopy c:\privates\HostNetSvc.dll c:\windows\system32\HostNetSvc.dll


    #--------------------------------------------------------------------------------------------
    # Updated networking fix.
    echo "$(date) Phase2.ps1 Installing private Net*.dll..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\NetMgmtIF.dll          c:\windows\system32\NetMgmtIF.orig.dll
    copy c:\windows\system32\NetSetupApi.dll        c:\windows\system32\NetSetupApi.orig.dll
    copy c:\windows\system32\NetSetupEngine.dll     c:\windows\system32\NetSetupEngine.orig.dll
    copy c:\windows\system32\NetSetupSvc.dll        c:\windows\system32\NetSetupSvc.orig.dll

    c:\privates\sfpcopy c:\privates\NetMgmtIF.dll      c:\windows\system32\NetMgmtIF.dll
    c:\privates\sfpcopy c:\privates\NetSetupApi.dll    c:\windows\system32\NetSetupApi.dll
    c:\privates\sfpcopy c:\privates\NetSetupEngine.dll c:\windows\system32\NetSetupEngine.dll
    c:\privates\sfpcopy c:\privates\NetSetupSvc.dll    c:\windows\system32\NetSetupSvc.dll


    #--------------------------------------------------------------------------------------------
    # JohnR csrss fix for leaking containers
    echo "$(date) Phase2.ps1 Installing private ntoskrnl.exe..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\ntoskrnl.exe c:\windows\system32\ntoskrnl.orig.exe
    c:\privates\sfpcopy c:\privates\ntkrnlmp.exe c:\windows\system32\ntoskrnl.exe

    #--------------------------------------------------------------------------------------------
    # Scott fixes for filter. Fixes 2 bugs, neither in 4D.
    echo "$(date) Phase2.ps1 Installing private wcifs.sys..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\drivers\wcifs.sys c:\windows\system32\drivers\wcifs.orig.sys
    c:\privates\sfpcopy c:\privates\wcifs.sys c:\windows\system32\drivers\wcifs.sys
}
Catch [Exception] {
    echo "$(date) InstallPrivates.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    echo "$(date) InstallPrivates.ps1 completed. Reboot required" >> $env:SystemDrive\packer\configure.log
} 

