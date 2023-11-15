Write-Host "Azure AD Connect Demo - v1.0, written by Rithin Skaria" `
    -ForegroundColor "Red" -BackgroundColor "White"
#Variables
$rg = read-host "(new) Resource Group Name"
$region = "eastus"
$username = "kodekloud" #username for the VM
$plainPassword = "VMP@55w0rd" #your VM password
$VMSize = "Standard_D2s_v3"

#Creating VM credential; use your own password and username by changing the variables if needed
$password = ConvertTo-SecureString $plainPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password);

#Setting execution policy
Set-ExecutionPolicy Bypass

#Checking if required modules are installed

if (Get-Command -Name 'Get-AzContext' -Ea SilentlyContinue ) {
    Write-Host "INFO: Az Module is already installed, skipping to next step" -ForegroundColor Green
}
else {
    Write-Host "INFO: Requires installation of Az module" -ForegroundColor Yellow
    Install-Module Az -Force -AllowClobber
    Import-Module Az -Force 
}

Login-AzAccount -UseDeviceAuthentication
$WarningPreference = 'SilentlyContinue'
#Create RG
New-AzResourceGroup -n $rg -l $region

#########-----Create network---------######
#Creating vnet

Write-Host "Adding subnet configuration" `
    -ForegroundColor "Green" -BackgroundColor "Black"

$dcSnet = New-AzVirtualNetworkSubnetConfig `
    -Name 'dc-snet' `
    -AddressPrefix 10.0.0.0/24
 
$serversSnet = New-AzVirtualNetworkSubnetConfig `
    -Name 'server-snet' `
    -AddressPrefix 10.0.1.0/24
   

Write-Host "Creating dc-vnet" `
    -ForegroundColor "Green" -BackgroundColor "Black"

New-AzVirtualNetwork `
    -ResourceGroupName $rg `
    -Location $region `
    -Name "dc-vnet" `
    -AddressPrefix 10.0.0.0/16 `
    -Subnet $dcSnet, $serversSnet `
    -DnsServer 10.0.0.4,1.1.1.1 | Out-Null

#-------------------Create DC-----------------------------#
Write-Host "Creating domain controller" `
    -ForegroundColor "Green" -BackgroundColor "Black"
    New-AzVm `
    -ResourceGroupName $rg `
    -Name "dc-01" `
    -Location $region `
    -Size $VMSize `
    -Credential $credential `
    -Image 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest' `
    -VirtualNetworkName 'dc-vnet' `
    -SubnetName 'dc-snet' `
    -SecurityGroupName 'dc-nsg' `
    -PublicIpAddressName 'dc-pip' `
    -OpenPorts 3389 | Out-Null

#-----------------------Install AD DS on DC--------------------#
Start-Sleep 60
Write-Host -ForegroundColor Green "Started installation of AD DS to DC" 
Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName 'dc-01' -CommandId RunPowerShellScript -ScriptPath '.\030-Hybrid Identity\prep-dc.ps1'
Write-Host -ForegroundColor Green "DC-01 Active Directory Installation completed" 
Restart-AzVM -Name 'dc-01' -ResourceGroupName $rg
Start-Sleep 15

#-------------------Create server-----------------------------#
Write-Host "Creating client server" `
-ForegroundColor "Green" -BackgroundColor "Black"
New-AzVm `
-ResourceGroupName $rg `
-Name "server-01" `
-Size $VMSize `
-Credential $credential `
-Location $region `
-Image 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest' `
-VirtualNetworkName 'dc-vnet' `
-SubnetName 'server-snet' `
-SecurityGroupName 'server-nsg' `
-PublicIpAddressName 'server-pip' `
-OpenPorts 3389 | Out-Null

#------------------------------Create users in DC-------------------#
Write-Host -ForegroundColor Green "Started creating users in DC" 
Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName 'dc-01' -CommandId RunPowerShellScript -ScriptPath '.\030-Hybrid Identity\prep-users.ps1'
Write-Host -ForegroundColor Green "Created users in DC-01" 

Write-Host "Finished!" -ForegroundColor Green
