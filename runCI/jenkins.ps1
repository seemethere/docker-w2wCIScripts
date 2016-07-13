    Write-Host -ForegroundColor green "INFO: Jenkins build step starting"
    & .\executeCI.ps1; Write-Host "Jenkins LEC= $LastExitCode  DU=$_"