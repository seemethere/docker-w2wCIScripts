#-----------------------
# RestartNSSM.ps1
#-----------------------


# Restart the NSSM docker service. This will cause the base images to be picked up.
nssm stop docker -erroraction silentlycontinue
nssm start docker -erroraction silentlycontinue



