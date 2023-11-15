mkdir C:\Temp
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled false
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Add-WindowsFeature RSAT-ADDS-Tools
Install-WindowsFeature -name AD-Domain-Services
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
$pass="DcP@55w0rd"
$sPwd = $pass | ConvertTo-SecureString -AsPlainText -Force
Install-ADDSForest -DomainName 'kodekloudlab.local' -SafeModeAdministratorPassword $spwd -Confirm:$false -Force -InstallDns:$true -DomainNetbiosName Kodekloud -NoRebootOnCompletion
Start-Sleep -s 10
Restart-computer