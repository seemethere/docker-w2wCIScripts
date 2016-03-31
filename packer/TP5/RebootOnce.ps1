#-----------------------
# RebootOnce.ps1
# This runs as a scheduled task post-sysprep
#-----------------------

echo "RebootOnce.ps1 started" > $env:SystemDrive\packer\RebootOnce.txt

# Idle
Start-Sleep 600 # Give time for cygwin to install and SSH to be configured (SetupSSH.ps1)

# Delete the scheduled task
$ConfirmPreference='none'
Get-ScheduledTask 'RebootOnce' | Unregister-ScheduledTask

echo "RebootOnce.ps1 causing reboot now..." >> $env:SystemDrive\packer\RebootOnce.txt
shutdown /t 0 /r
