Packer bits for building Windows images (@jhowardmsft)

- packer.json - The packer configuration file
- packer.ps1  - Powershell wrapper for running the image build.

To use: 

- Need publish settings in ~/.azure/engine-team@docker.com.publishsettings
  Get-AzurePublishSettingsFile and save to above location.

- Download Windows 64-bit packer from https://www.packer.io/downloads.html
  (This was tested using version 0.10.0). Extract to e:\packer
  
- Copy the two files at the top to the directory (or have e:\packer in path)

- Download Packer-Azure from https://github.com/Azure/packer-azure and
  extract to the same directory. Direct link https://github.com/Azure/packer-azure/releases

- Make sure your azure credentials are set.   (Add-AzureAccount for engine-team@docker.com)

- Check packer.json is pointing to the correct image you have prepared. At the
  time of writing, there is a "tp5" storage container on the engine account on Azure.
  It contains a sysprepped VHD of TP5 with:
  
  - Base OS images for nanoserver and windowsservercore
  - Container role added
  - TP5 workarounds added (see below)
  - Sysprepped
  - Uploaded (Add-AzureVHD "https://tp5.blob.core.windows.net/vhds/azuretp5v2.vhd") where
    - tp5 in the URL is the name of the storage container in Azure
    - v2 in azuretp5v2.vhd represents the version of the VHD. Increment each rebuild.
  - Image created (Add-AzureVMImage -imagename azuretp5v2 -MediaLocation https://tp5.blob.core.windows.net/vhds/azuretp5v2.vhd -OS Windows)
  
- Make sure $env:password is set to the jenkins account password you want

- Run packer.ps1

- Keep the name of the image handy as you'll need that to create a new VM from that image.
  eg at time of writing: TBC 
  

TP5 workarounds
 
 In base VHD: 
 - BringNodeOnline.ps1 and TakeNodeOffline.ps1 added to c:\scripts.
   These are NOT in github due to containing API key.
 - Scheduled task at system startup to run BringNodeOnline.ps1
  
 In packer.json and some .ps1 scripts:
 - Kill-LongRunningDocker.ps1 scheduled task at startup. This should
   not be necessary with the final TP5 ZDP.
 
 In Jenkins
 - At job launch, calls c:\scripts\TakeNodeOffline.ps1
 - At job completion, calls shutdown /t 0 /r
 



