#-----------------------
# ConfigureCIEnvironment.ps1
#-----------------------

# Configure the variables used by the executeCI.sh and cleanupCI.sh scripts invoked by Jenkins
echo "$(date) ConfigureCIEnvironment started" >> $env:SystemDrive\packer\configure.log
Write-Host "INFO: Executing ConfigureCIEnvironment.ps1"
[Environment]::SetEnvironmentVariable("SOURCES_DRIVE", "c", "Machine")
[Environment]::SetEnvironmentVariable("SOURCES_SUBDIR", "gopath", "Machine")
if ($LOCAL_CI_INSTALL -eq 1) {
    [Environment]::SetEnvironmentVariable("TESTRUN_DRIVE", "c", "Machine")
} else {
    [Environment]::SetEnvironmentVariable("TESTRUN_DRIVE", "d", "Machine")
}
[Environment]::SetEnvironmentVariable("TESTRUN_SUBDIR", "CI", "Machine")
echo "$(date) ConfigureCIEnvironment completed" >> $env:SystemDrive\packer\configure.log
