#-----------------------
# ConfigureCIEnvironment.ps1
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


# Configure the variables used by the executeCI.sh and cleanupCI.sh scripts invoked by Jenkins
[Environment]::SetEnvironmentVariable("SOURCES_DRIVE", "c", "Machine")
[Environment]::SetEnvironmentVariable("SOURCES_SUBDIR", "gopath", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_DRIVE", "d", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_SUBDIR", "CI", "Machine")

