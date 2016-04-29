$env:imageprefix="jenkins-rs1"
$env:storageaccount="winrs1"
$env:osimagelabel="azurers1$version"

if (($env:version -eq "") -or ($env:version -eq $null)) {
    Write-Error "Must have environment variable 'version'"
    exit 1
}
if (($env:password -eq "") -or ($env:password -eq $null)) {
    Write-Error "Must have environment variable 'password' set matching the Jenkins user account"
    exit 1
}
if (($env:imageprefix -eq "") -or ($env:imageprefix -eq $null)) {
    Write-Error "Must have environment variable 'imageprefix' set eg jenkins-rs1"
    exit 1
}
if (($env:storageaccount -eq "") -or ($env:storageaccount -eq $null)) {
    Write-Error "Must have environment variable 'storageaccount' set eg winrs1"
    exit 1
}
if (($env:osimagelabel -eq "") -or ($env:osimagelabel -eq $null)) {
    Write-Error "Must have environment variable 'osimagelabel' set eg azurers1xxxxx where xxxxx is a build number"
    exit 1
}

packer.exe build ..\common\packer.json