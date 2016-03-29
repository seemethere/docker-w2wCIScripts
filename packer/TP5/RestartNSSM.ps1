#-----------------------
# RestartNSSM.ps1
#-----------------------

Write-Host "INFO: Executing RestartNSSM.ps1"

# Restart the NSSM docker service. This will cause the base images to be picked up.
nssm stop docker -erroraction silentlycontinue
nssm start docker -erroraction silentlycontinue

Write-Host "INFO: RestartNSSM.ps1 completed"

