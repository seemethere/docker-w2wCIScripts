#-----------------------
# ConfigureCIEnvironment.ps1
#-----------------------

# Configure the variables used by the executeCI.sh and cleanupCI.sh scripts invoked by Jenkins
Write-Host "INFO: Executing ConfigureCIEnvironment.ps1"
[Environment]::SetEnvironmentVariable("SOURCES_DRIVE", "c", "Machine")
[Environment]::SetEnvironmentVariable("SOURCES_SUBDIR", "gopath", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_DRIVE", "d", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_SUBDIR", "CI", "Machine")
Write-Host "INFO: ConfigureCIEnvironment.ps1 completed"
