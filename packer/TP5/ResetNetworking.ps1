#-----------------------
# ResetNetworking.ps1
# Note this runs post-sysprep, so have to delete the scheduled task
# This is a TP5 hack. #6925609
#-----------------------

# Stop on error
$ErrorActionPreference="stop"

netsh int ipv4 reset
# Needs a reboot - taken care of in RebootOnce.ps1

# Delete the scheduled task
$ConfirmPreference=='none'
Get-ScheduledTask 'ResetNetworking' | Unregister-ScheduledTask

echo "ResetNetworking.ps1 ran" > $env:SystemDrive\packer\ResetNetworking.txt