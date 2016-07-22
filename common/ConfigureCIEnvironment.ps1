#-----------------------
# ConfigureCIEnvironment.ps1
#-----------------------

# Configure the variables used by executeCI.ps1 invoked by Jenkins
echo "$(date) ConfigureCIEnvironment started" >> $env:SystemDrive\packer\configure.log
Write-Host "INFO: Executing ConfigureCIEnvironment.ps1"
$env:SOURCE_DRIVE="c"
$env:SOURCES_SUBDIR="gopath"
setx "SOURCES_DRIVE" "$env:SOURCES_DRIVE" /M
setx "SOURCES_SUBDIR" "$env:SOURCES_SUBDIR" /M


if ($env:LOCAL_CI_INSTALL -eq 1) {
    $env:TESTRUN_DRIVE="c"
} else {
    $env:TESTRUN_DRIVE="d"
}
$env:TESTRUN_SUBDIR="CI"
setx "TESTRUN_DRIVE" "$env:TESTRUN_DRIVE" /M
setx "TESTRUN_SUBDIR" "$env:TESTRUN_SUBDIR" /M
echo "$(date) ConfigureCIEnvironment completed" >> $env:SystemDrive\packer\configure.log
