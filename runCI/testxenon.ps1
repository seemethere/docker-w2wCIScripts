e:\docker\ci\w2w\runCI\Invoke-DockerCI.ps1 `
-HyperVDUT `
-SkipValidationTests `
-SkipUnitTests `
-SkipAllCleanup `
-WindowsBaseImage nanoserver `
-CIScriptLocation E:\docker\ci\w2w\runci\executeCI.ps1 `
-GitRemote https://github.com/microsoft/docker `
-GitCheckout jjh/nanoserver `
-skipclone `
-skipimagebuild `
-skipbinarybuild `
#-IntegrationTestName "TestEvents*" `
-SkipCOntrolDownload

#-SkipClone -SkipBinaryBuild -SkipImageBuild
#-SkipIntegrationTests 
#-SkipControlDownload