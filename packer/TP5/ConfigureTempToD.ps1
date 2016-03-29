#-----------------------
# ConfigureTempToD.ps1
#-----------------------


# Update TEMP and TMP for current session and machine
$env:Temp="d:\temp"
$env:Tmp=$env:Temp
[Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "Machine")
[Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "Machine")
[Environment]::SetEnvironmentVariable("TEMP", "$env:Temp", "User")
[Environment]::SetEnvironmentVariable("TMP", "$env:Temp", "User")

# Create the TEMP directory 
mkdir $env:Temp -erroraction SilentlyContinue
