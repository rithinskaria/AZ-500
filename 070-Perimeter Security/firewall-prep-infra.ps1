#Preferences
$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Break'

#Variables
$rg = "rg-fw-spokes-$(Get-Date -Format 'yyyyMMdd')"
$region = "eastus"
$username = "kodekloud" #username for the VM
$plainPassword = "VMP@55w0rd" #your VM password

#Creating VM credential; use your own password and username by changing the variables if needed
$password = ConvertTo-SecureString $plainPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password);

#Create RG
Write-Host "Adding resource group : $rg " `
    -ForegroundColor "Yellow" -BackgroundColor "Black"
New-AzResourceGroup -n $rg -l $region | Out-Null

#########-----Create resources---------######

#Creating vnet and VMs in spoke-a
Write-Host "Adding spoke-a network configuration" `
    -ForegroundColor "Yellow" -BackgroundColor "Black"

$spokeASubnet = New-AzVirtualNetworkSubnetConfig `
    -Name 'default' `
    -AddressPrefix 192.168.1.0/24 

$spokeA = New-AzVirtualNetwork `
    -ResourceGroupName $rg `
    -Location eastus `
    -Name "spoke-a" `
    -AddressPrefix 192.168.1.0/24 `
    -Subnet $spokeASubnet 

Write-Host "Adding spoke-b network configuration" `
    -ForegroundColor "Yellow" -BackgroundColor "Black"
$spokeBSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name 'default' `
    -AddressPrefix 192.168.2.0/24 

$spokeB = New-AzVirtualNetwork `
    -ResourceGroupName $rg `
    -Location eastus `
    -Name "spoke-b" `
    -AddressPrefix 192.168.2.0/24 `
    -Subnet $spokeBSubnet 

#NSG
Write-Host "Setting up NSG to allow SSH traffic to VMs" `
    -ForegroundColor "Yellow" -BackgroundColor "Black"
$ssh = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" -Access Allow `
    -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 22

$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
-Location $region -Name "spoke-nsg" -SecurityRules $ssh

Set-AzVirtualNetworkSubnetConfig -Name default -VirtualNetwork $spokeA -AddressPrefix "192.168.1.0/24" `
-NetworkSecurityGroup $networkSecurityGroup | Out-Null

Set-AzVirtualNetworkSubnetConfig -Name default -VirtualNetwork $spokeB -AddressPrefix "192.168.2.0/24" `
-NetworkSecurityGroup $networkSecurityGroup | Out-Null

$spokeA | Set-AzVirtualNetwork | Out-Null
$spokeB | Set-AzVirtualNetwork| Out-Null


for ($i = 1; $i -lt 3; $i++) {
    Write-Host "Creating spoke-a-vm-$i" -ForegroundColor "Yellow" -BackgroundColor "Black"
    $spAvm = New-AzVM -Name "spoke-a-vm-$i" `
        -ResourceGroupName $rg `
        -Location eastus `
        -Size 'Standard_B1s' `
        -Image "Ubuntu2204" `
        -VirtualNetworkName "spoke-a" `
        -SubnetName 'default' `
        -Credential $credential `
        -PublicIpAddressName "spoke-a-vm-$i-pip" `
        -PublicIpSku Standard
    $fqdn = $spAvm.FullyQualifiedDomainName
    Write-Host "spoke-a-vm-$i FQDN : $fqdn " -ForegroundColor Green 
    Write-Host "Creating spoke-b-vm-$i" -ForegroundColor "Yellow" -BackgroundColor "Black" 
    $spBvm = New-AzVM -Name "spoke-b-vm-$i" `
        -ResourceGroupName $rg `
        -Location eastus `
        -Image "Ubuntu2204"  `
        -Size 'Standard_B1s' `
        -VirtualNetworkName "spoke-b" `
        -SubnetName 'default' `
        -Credential $credential `
        -PublicIpAddressName "spoke-b-vm-$i-pip" `
        -PublicIpSku Standard
    $fqdn = $spBvm.FullyQualifiedDomainName
    Write-Host "spoke-b-vm-$i FQDN: $fqdn "  -ForegroundColor Green 
}



