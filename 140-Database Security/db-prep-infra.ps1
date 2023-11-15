#Variables
$rg = "rg-dbsec-$(Get-Random)"
$location = "eastus"
$adminLogin = "kodekloud"
$plainPassword = "VMP@55w0rd" 
$serverName = "sql-server-$(Get-Random)"
$databaseName = "db-adv-works"
$startIp = "0.0.0.0"
$endIp = "0.0.0.0"

#Create RG
New-AzResourceGroup -Name $rg -Location $location 

#Create SQL Server
Write-host "Creating SQL server" -ForegroundColor Green
$password = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
$server = New-AzSqlServer -ResourceGroupName $rg `
    -ServerName $serverName `
    -Location $location `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $adminLogin, $password)   
Write-host "Created server $($server.ServerName)" -ForegroundColor Green 

#Create firewall rules
Write-host "Configuring SQL server firewall" -ForegroundColor Green
$serverFirewallRule = New-AzSqlServerFirewallRule -ResourceGroupName $rg `
    -ServerName $serverName `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp
Write-host "Created rule -  $($serverFirewallRule.FirewallRuleName) for $($server.ServerName)" -ForegroundColor Green 
Write-host "Creating database" -ForegroundColor Green
$database = New-AzSqlDatabase  -ResourceGroupName $rg `
    -ServerName $serverName `
    -DatabaseName $databaseName `
    -Edition Basic `
    -SampleName "AdventureWorksLT"
Write-host "Created database -  $($database.DatabaseName) for $($server.ServerName)" -ForegroundColor Green 