#-----------------------
# ConfigureCIEnvironment.ps1
#-----------------------

# Configure the variables used by the executeCI.sh and cleanupCI.sh scripts invoked by Jenkins
[Environment]::SetEnvironmentVariable("SOURCES_DRIVE", "c", "Machine")
[Environment]::SetEnvironmentVariable("SOURCES_SUBDIR", "gopath", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_DRIVE", "d", "Machine")
[Environment]::SetEnvironmentVariable("TESTRUN_SUBDIR", "CI", "Machine")

