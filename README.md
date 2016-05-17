About
------

John Howard, Microsoft Corporation (@jhowardmsft). November 2016. 

This repo has (almost) everything to deploy, configure, run Docker CI on Windows Server 2016. As of May 2016, it includes support for TP5 pre-4D ZDP, TP5 with 5B, and RS1 builds (experimental, more work to do).

###Directories - Deployment scripts
- <b>common</b> -  Common to all flavours (TP5, RS1 etc)
- <b>tp5</b> -  Exclusive to TP5
- <b>tp5pre4d</b> -  Exclusive to TP5 Pre-4D builds (now retired)
- <b>rs1</b> -  Exclusive to RS1 builds leading to 2016 RTM.

###Other directories
- <b>runCI</b> -  The scripts to run CI, including <b>Invoke-DockerCI</b>
- <b>Deploy-JenkinsVM</b> -  Easy way to deploy a Jenkins VM
- <b>Install-DevVM</b> -  Setup a development/CI VM if on Microsoft corpnet. (Hard coded bits for jhoward)

How to use.
--

### Install packer and pre-reqs

- Need publish settings in $env:HOME\\.azure\engine-team@docker.com.publishsettings
  Get-AzurePublishSettingsFile and save to above location.

- Download Windows 64-bit packer from https://www.packer.io/downloads.html
  (This was verified using version 0.10.0). Extract to e:\packer
  
- Copy the two files at the top to the directory (or have e:\packer in path)

- Download Packer-Azure from https://github.com/Azure/packer-azure and
  extract to the same directory. Direct link https://github.com/Azure/packer-azure/releases

- Make sure your azure credentials are set.   (Add-AzureAccount for engine-team@docker.com)



### Create a VHD.

I prepare my own. Here's an example. 
- Create a generation 1 VM in Hyper-V and use a <B>VHD, not a VHDX</B>. Size 127GB
- Install from media (datacentre, with GUI)


    # Allow Enhanced Session Mode (optional)
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
    
    # Copy base images to c:\baseimages as windowsservercore.wim and nanoserver.wim
    c:\windows\system32\sysprep\sysprep /oobe /generalize /shutdown
    
    # Copy the VHD to AzureTP5vX.vhd where X is used in the next part for upload.
    
### (TP5) Then upload it to Azure and deploy a Jenkins VM. 

Note this will require some username/password/subscription IDs. This is for TP5

    # BUMP THE VERSION EACH TIME!!!
    $version=54  # packer.ps1 picks this up too.
    $env:BranchType="tp5"
    $env:version=$version
    $env:storageaccount="tp5"
    $env:JENKINS_PASSWORD_W2W="SECRET"
    $env:AZURE_SUBSCRIPTION_ID="SECRET"
    $env:AZURE_SUBSCRIPTION_USERNAME="SECRET"
    $env:AZURE_SUBSCRIPTION_PASSWORD="SECRET"


    $userName = $env:AZURE_SUBSCRIPTION_USERNAME
    $securePassword = ConvertTo-SecureString -String $env:AZURE_SUBSCRIPTION_PASSWORD -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($userName, $securePassword)
    Add-AzureAccount -Credential $cred 

    # Upload the VHD
    Add-Azurevhd "https://tp5.blob.core.windows.net/vhds/azuretp5v$version.vhd" -LocalFilePath ".\azuretp5v$version.vhd"

    # Add image to your list of custom images
    Add-AzureVMImage -imagename "azuretp5v$version" -MediaLocation "https://tp5.blob.core.windows.net/vhds/azuretp5v$version.vhd" -OS Windows

    z:
    cd \docker\ci\W2W\common
    .\packer.ps1 $env:version

    # Deploy VM - this will pick up the last image by timestamp uploaded, which starts 'azuretp5v'
    cd ..\Deploy-JenkinsVM
    .\Deploy-JenkinsVM -StorageAccount "tp5" -Force -Size "D3" -ImagePrefix "jenkins-tp5" "jenkins-tp5-99" -Password "$env:JENKINS_PASSWORD_W2W" -AzureSubscriptionID "$env:AZURE_SUBSCRIPTION_ID"


