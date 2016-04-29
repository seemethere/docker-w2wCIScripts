$env:imageprefix="jenkins-tp5"
$env:storageaccount="tp5"
$env:osimagelabel="azuretp5v$version"

if (($env:version -eq "") -or ($env:version -eq $null)) {
    Write-Error "Must have environment variable 'version' set eg 30 as of 4/20/2016"
    exit 1
}
if (($env:password -eq "") -or ($env:password -eq $null)) {
    Write-Error "Must have environment variable 'password' set matching the Jenkins user account"
    exit 1
}
if (($env:imageprefix -eq "") -or ($env:imageprefix -eq $null)) {
    Write-Error "Must have environment variable 'imageprefix' set eg jenkins-tp5"
    exit 1
}
if (($env:storageaccount -eq "") -or ($env:storageaccount -eq $null)) {
    Write-Error "Must have environment variable 'storageaccount' set eg tp5"
    exit 1
}
if (($env:osimagelabel -eq "") -or ($env:osimagelabel -eq $null)) {
    Write-Error "Must have environment variable 'osimagelabel' set eg azuretp5vxxx where x is a version number"
    exit 1
}

packer.exe build .\packer.json