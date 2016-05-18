
if (($env:BranchType -eq "") -or ($env:BranchType -eq $null)) {
    Throw "BranchType must be set in the environment one of tp5, tp5pre4d, tp5prod or rs1, and in lowercase)"
}

$BranchType = $env:BranchType.ToLower()
$env:imageprefix="jenkins-"+$BranchType.ToLower()

if ($BranchType -eq "rs1") {
    # rs1 storage account was taken
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
    Write-Error "Must have environment variable 'storageaccount' set eg winrs1 or tp5"
    exit 1
}
if (($env:osimagelabel -eq "") -or ($env:osimagelabel -eq $null)) {
    Write-Error "Must have environment variable 'osimagelabel' set eg azure$BranchTypevxxxxx where xxxxx is a build number"
    exit 1
}

packer.exe build packer.json