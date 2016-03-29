#-----------------------
# ActivateVM.ps1
#-----------------------

# Set as a run-once on system start 

Write-Host "INFO: Executing ActivateVM.ps1"

cscript $env:SystemDrive\windows\system32\slmgr.vbs /ipk 6XBNX-4JQGW-QX6QG-74P76-72V67
cscript $env:SystemDrive\windows\system32\slmgr.vbs /ato
echo "ActivateVM.ps1 ran" > $env:SystemDrive\scripts\activated.txt

# Delete the scheduled task
$ConfirmPreference=='none'
Get-ScheduledTask 'ActivateVM' | Unregister-ScheduledTask

Write-Host "INFO: ActivateVM.ps1 completed"