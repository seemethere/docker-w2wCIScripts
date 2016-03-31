#-----------------------
# UserTempToD.ps1
# This runs as a scheduled task post-sysprep
#-----------------------


# Update TEMP and TMP for current user
$env:Temp="d:\temp"
$env:Tmp=$env:Temp
[Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "User")
[Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "User")

# Create the TEMP directory 
mkdir $env:Temp -erroraction SilentlyContinue 2>&1 | Out-Null
Write-Host "INFO: UserTempToD.ps1 completed"

# Delete the scheduled task
$ConfirmPreference='none'
Get-ScheduledTask 'UserTempToD' | Unregister-ScheduledTask

