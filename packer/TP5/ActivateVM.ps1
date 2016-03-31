#-----------------------
# ActivateVM.ps1
#-----------------------

# Set as a run-once on system start 

cscript $env:SystemDrive\windows\system32\slmgr.vbs /ipk 6XBNX-4JQGW-QX6QG-74P76-72V67
cscript $env:SystemDrive\windows\system32\slmgr.vbs /ato

# Delete the scheduled task
$ConfirmPreference='none'
Get-ScheduledTask 'ActivateVM' | Unregister-ScheduledTask
