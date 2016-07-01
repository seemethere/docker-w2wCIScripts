if (($env:JENKINS_PASSWORD_W2W -eq "") -or ($env:JENKINS_PASSWORD_W2W -eq $null)) {
    Write-Error "Must have environment variable 'JENKINS_PASSWORD_W2W' set matching the Jenkins user account"
    exit 1
}
if (($env:imageprefix -eq "") -or ($env:imageprefix -eq $null)) {
    Write-Error "Must have environment variable 'imageprefix' set eg jenkins-tp5"
    exit 1
}
if (($env:storageaccount -eq "") -or ($env:storageaccount -eq $null)) {
    Write-Error "Must have environment variable 'storageaccount' set eg winrs1 or tp5"
    exit 1
}
if (($env:osimagelabel -eq "") -or ($env:osimagelabel -eq $null)) {
    Write-Error "Must have environment variable 'osimagelabel' set eg azureTP5vNN where NN is a version or build number"
    exit 1
}

packer.exe build packer.json