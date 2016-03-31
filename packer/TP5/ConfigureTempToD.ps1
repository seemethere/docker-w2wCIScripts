#-----------------------
# ConfigureTempToD.ps1
#-----------------------


# Update TEMP and TMP for current session and machine
Write-Host "INFO: Executing ConfigureTempToD.ps1"
$env:Temp="d:\temp"
$env:Tmp=$env:Temp
[Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "Machine")
[Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "Machine")
[Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "User")
[Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "User")

# Create the TEMP directory 
mkdir $env:Temp -erroraction SilentlyContinue 2>&1 | Out-Null
Write-Host "INFO: ConfigureTempToD.ps1 completed"

echo "ConfigureTempToD.ps1 ran" > $env:SystemDrive\packer\ConfigureTempToD.txt

# Delete the scheduled task
$ConfirmPreference='none'
Get-ScheduledTask 'ConfigureTempToD' | Unregister-ScheduledTask
