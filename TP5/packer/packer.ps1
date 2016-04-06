if (($env:password -eq "") -or ($env:password -eq $null)) {
	Write-Error "Must have environment variable 'password' set matching the Jenkins user account"
	exit 1
}
packer.exe build packer.json