#-----------------------
# RestartNSSM.ps1
#-----------------------

Write-Host "INFO: Executing RestartNSSM.ps1"

# Restart the NSSM docker service. This will cause the base images to be picked up.
Start-Process -wait nssm -ArgumentList "stop docker" -erroraction silentlycontinue 
Start-Process -wait nssm -ArgumentList "start docker" -erroraction silentlycontinue 

Write-Host "INFO: RestartNSSM.ps1 completed"

