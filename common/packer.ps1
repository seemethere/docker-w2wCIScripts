
if (($env:BranchType.ToLower() -ne "tp5") -and 
    ($env:BranchType.ToLower() -ne "tp5pre4d") -and
    ($env:BranchType.ToLower() -ne "rs1")) {
    Throw "BranchType must be set in the environment one of TP5, TP5Pre4D or RS1"
}

$env:imageprefix="jenkins-"+$BranchType.ToLower()

if ($env:BranchType.ToLower() -eq "rs1") {
    $env:storageaccount="winrs1"
} else {
    $env:storageaccount="tp5"
}
$env:osimagelabel="azure"+$BranchType+"v"+$version

if (($env:version -eq "") -or ($env:version -eq $null)) {
    Write-Error "Must have environment variable 'version'"
    exit 1
}
if (($env:password -eq "") -or ($env:password -eq $null)) {
    Write-Error "Must have environment variable 'password' set matching the Jenkins user account"
    exit 1
}
if (($env:imageprefix -eq "") -or ($env:imageprefix -eq $null)) {
    Write-Error "Must have environment variable 'imageprefix' set eg jenkins-$BranchType"
    exit 1
}
if (($env:storageaccount -eq "") -or ($env:storageaccount -eq $null)) {
    Write-Error "Must have environment variable 'storageaccount' set eg winrs1 pr tp5"
    exit 1
}
if (($env:osimagelabel -eq "") -or ($env:osimagelabel -eq $null)) {
    Write-Error "Must have environment variable 'osimagelabel' set eg azure$BranchTypexxxxx where xxxxx is a build number"
    exit 1
}

packer.exe build packer.json