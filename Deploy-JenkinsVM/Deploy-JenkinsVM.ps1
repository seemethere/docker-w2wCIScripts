
param(
    [Parameter(Mandatory=$false)][string]$vmName,
    [Parameter(Mandatory=$false)][switch]$Force=$False,
    [Parameter(Mandatory=$false)][string]$storageAccount, # Storage account for the image and where VM is created eg tp5 or winrs1
    [Parameter(Mandatory=$false)][string]$size="D3", # Size of the VM
    [Parameter(Mandatory=$false)][string]$ImagePrefix, # Image matching string. Must start with this
    [Parameter(Mandatory=$false)][string]$Password=$env:JENKINS_PASSWORD_W2W 
    ###[Parameter(Mandatory=$false)][string]$AzureSubscriptionID=$env:AZURE_SUBSCRIPTION_ID 
)

$vnetSiteName = 'Jenkins'             # Network to connect to
$defaultLocation = 'Central US'       # Hopefully obvious
$size = "Standard_"+"$size"+"_v2"     # Size of the VM

$adminUsername = 'jenkins'
###$defaultPublishSettings = '$env:HOMEPATH/.azure/engine-team@docker.com.publishsettings'

if ([string]::IsNullOrWhiteSpace($Password)) {
     Throw "Password for the user 'jenkins' must be supplied, or provided in $env:JENKINS_PASSWORD_W2W"
}

##if ([string]::IsNullOrWhiteSpace($AzureSubscriptionID)) {
##     Throw "The Azure Subscription ID must be supplied, or provided in $env:AZURE_SUBSCRIPTION_ID"
##}

$ErrorActionPreference = 'Stop'

function ask {
    param([string]$prompt)
    if ($Force -ne $True) {
        $confirm = Read-Host "$prompt [y/n]"
        while($confirm -ne "y") {
            if ($confirm -eq 'n') {Write-Host "OK, exiting...."; exit}
            $confirm = Read-Host "$prompt [y/n]"
        }
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($vmName)) { Throw("vmName parameter must be supplied") }
    if ([string]::IsNullOrWhiteSpace($storageAccount)) { Throw("storageAccount parameter must be supplied - winrs1 or tp5") }
    if ([string]::IsNullOrWhiteSpace($imagePrefix)) { Throw("imagePrefix parameter must be supplied - jenkins-rs1 or jenkins-tp5") }

###    if (Test-Path $defaultPublishSettings) {
###        Write-Host "INFO: Importing Publish Settings File"
###        Import-AzurePublishSettingsFile $defaultPublishSettings
###    }

#    Write-Host "INFO: Configuring the Azure Subscription"
#    Set-AzureSubscription -SubscriptionId $AzureSubscriptionID -CurrentStorageAccountName $storageAccount

    Write-Host "INFO: Checking if VM exists"
    $vm = Get-AzureVM -ServiceName $vmName -Name $vmName -ErrorAction SilentlyContinue
    if ($vm -ne $null) {
        ask("WARN: VM $vmName already exists. Delete it?")
        ask("Really delete $vmName?")
        Write-Host "INFO: Deleting VM..."
        Remove-AzureVM -ServiceName $vmName -Name $vmName
    }

    Write-Host "INFO: Determining if service $vmName exists..."
    $service=Get-AzureService -ServiceName $vmName -ErrorAction SilentlyContinue
    if ( $service -eq $null ) {
        ask("Service $vmName does not exist - create?")
        Write-Host "INFO: Create service..."
        New-AzureService -ServiceName $vmName -Location $defaultLocation
    } else {
        Write-Host "INFO: Service exists."
    }

    Write-Host "INFO: Determining the latest '$imagePrefix' image..."
    $sourceImages = Get-AzureVMImage | Where-Object { $_.ImageName -like "$imagePrefix*" } | Sort-Object -Descending CreatedTime
    if ($sourceImages -eq $null) {
        Throw "No source images were found"
    }
    $sourceImageName = $sourceImages[0].ImageName
    Write-Host "INFO: Latest is $sourceImageName"
    ask("Right image?")

    Write-Host "INFO: Creating the configuration object..."
    $vmc = New-AzureVMConfig -ImageName $sourceImageName -InstanceSize $size -Name $vmName -DiskLabel $vmName |
            Add-AzureEndpoint -Name 'SSH' -LocalPort 22 -PublicPort 22 -Protocol tcp |
            Set-AzureSubnet 'Subnet-1'

    Write-Host "INFO: Creating a provisioning configuration..."
    $pc=Add-AzureProvisioningConfig -VM $vmc `
                                    -Windows `
                                    -AdminUsername $adminUsername `
                                    -Password $Password

    Write-Host "INFO: Creating the VM..."
    $pc | New-AzureVM -ServiceName $vmName -VNetName $vnetSiteName

}
catch { Write-Host -ForegroundColor Red "ERROR: $_" }
finally { Write-Host -ForegroundColor Yellow "Complete" }

