#-----------------------
# InstallPrivates.ps1
#-----------------------

$ErrorActionPreference='Stop'

echo "$(date) InstallPrivates.ps1 started" >> $env:SystemDrive\packer\configure.log

try {
    echo "$(date) InstallPrivates.ps1 starting" >> $env:SystemDrive\packer\configure.log    
    # Privates installed after ZDP has rebooted.

    c:\privates\certutil -addstore root "c:\privates\testroot-sha2.cer"
    bcdedit /set "{current}" testsigning On

    # Hack to retry networking up to 5 times - stops very common busybox not found. Andrew working on real fix post 4D.
    echo "$(date) InstallPrivates.ps1 Installing private HostNetSvc.dll..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\HostNetSvc.dll c:\windows\system32\HostNetSvc.orig.dll
    c:\privates\sfpcopy c:\privates\HostNetSvc.dll c:\windows\system32\HostNetSvc.dll

    # JohnR csrss fix for leaking containers
    echo "$(date) InstallPrivates.ps1 Installing private ntoskrnl.exe..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\ntoskrnl.exe c:\windows\system32\ntoskrnl.orig.exe
    c:\privates\sfpcopy c:\privates\ntkrnlmp.exe c:\windows\system32\ntoskrnl.exe

    # Scott fixes for filter. Fixes 2 bugs, neither in 4D.
    echo "$(date) InstallPrivates.ps1 Installing private wcifs.sys..." >> $env:SystemDrive\packer\configure.log
    copy c:\windows\system32\drivers\wcifs.sys c:\windows\system32\drivers\wcifs.orig.sys
    c:\privates\sfpcopy c:\privates\wcifs.sys c:\windows\system32\drivers\wcifs.sys
}
Catch [Exception] {
    echo "$(date) InstallPrivates.ps1 complete with Error '$_'" >> $env:SystemDrive\packer\configure.log
    exit 1
}
Finally {
    # Disable the scheduled task
    echo "$(date) InstallPrivates.ps1 disabling scheduled task.." >> $env:SystemDrive\packer\configure.log
    $ConfirmPreference='none'
    Get-ScheduledTask 'InstallPrivates' | Disable-ScheduledTask

    echo "$(date) InstallPrivates.ps1 completed. Reboot required" >> $env:SystemDrive\packer\configure.log
} 

