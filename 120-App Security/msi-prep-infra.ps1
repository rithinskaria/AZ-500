#Variables
$rg = "rg-msi-$(Get-Random)"
$location = "eastus"
$adminLogin = "kodekloud"
$plainPassword = "VMP@55w0rd" 
$serverName = "sql-server-$(Get-Random)"
$databaseName = "db-adv-works"
$startIp = "0.0.0.0"
$endIp = "0.0.0.0"
$functionAppName = "fn$(Get-Random)$(Get-Date -Format 'ddMM')"
$keyVault = "akv$(Get-Random)"
$signedInUser =  (Get-AzContext).Account.Id

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
$connectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$adminLogin;Password=$plainPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

#KeyVault creation
Write-Host "Creating keyvault" -ForegroundColor Green
$akv = New-AzKeyVault `
-Name $keyVault `
-ResourceGroupName $rg `
-Location $location `
-Sku Standard
Write-Host "Giving access policy to user to write connection string" -ForegroundColor Green
Set-AzKeyVaultAccessPolicy `
 -VaultName $akv.VaultName `
 -UserPrincipalName "$signedInUser" `
 -PermissionsToSecrets get,set,delete
$secret =  ConvertTo-SecureString $connectionString -AsPlainText -Force
Write-Host "Writing secret to keyvault" -ForegroundColor Green
Set-AzKeyVaultSecret -VaultName $akv.VaultName -Name "sql" -SecretValue $secret

#Creating functions
Write-Host "Creating function app" -ForegroundColor Green
$storageAccount = New-AzStorageAccount -ResourceGroupName $rg -Name "stfn$(Get-Random)" -Location $location -SkuName "Standard_LRS" -AllowBlobPublicAccess $true
New-AzFunctionApp `
-ResourceGroupName $rg `
-Name $functionAppName `
-StorageAccount $storageAccount.StorageAccountName `
-Location $location `
-Runtime PowerShell `
-FunctionsVersion 4 `
-OSType Windows `
-RuntimeVersion '7.2'
$storageKey = (Get-AzStorageAccount -ResourceGroupName $rg -Name $storageAccount.StorageAccountName ).Context.ConnectionString
# Set the SPN details as environment variables in the Function App
Write-Host "Setting environment variables" -ForegroundColor Green
$envVariables = @{
    "AzureWebJobsStorage" = "DefaultEndpointsProtocol=https;$($storageKey.Split(';')[-2]);$($storageKey.Split(';')[-1]);EndpointSuffix=core.windows.net"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "FUNCTIONS_WORKER_RUNTIME" = "powershell"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = "DefaultEndpointsProtocol=https;$($storageKey.Split(';')[-2]);$($storageKey.Split(';')[-1]);EndpointSuffix=core.windows.net"
    "AKV" = "$($akv.VaultUri)"
}

$code = @"
# Input bindings are passed in via param block.
param(`$Request, `$TriggerMetadata)

# Interact with query parameters or the body of the request.
`$connectionString = "$connectionString"

# Create a SQL Connection
`$connection = New-Object System.Data.SqlClient.SqlConnection
`$connection.ConnectionString = `$connectionString

# Open the connection
`$connection.Open()

# Create a SQL Command to fetch table names
`$command = `$connection.CreateCommand()
`$command.CommandText = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Execute the command and fetch results
`$reader = `$command.ExecuteReader()

`$tables = @()
while (`$reader.Read()) {
    `$tables += `$reader["TABLE_NAME"]
}

# Close the connection
`$connection.Close()

# Return table names as the response
`$body = @{
    tables = `$tables
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.Net.HttpStatusCode]::OK
    Body = `$body
})
"@

$codeMsi =  @"
# Input bindings are passed in via param block.
param(`$Request, `$TriggerMetadata)
`$keyVaultUrl=`$env:AKV
`$resourceUri = 'https://vault.azure.net'
`$tokenAuthUri = `$env:MSI_ENDPOINT +"?resource=`$resourceUri&api-version=2017-09-01"
`$tokenResponse = Invoke-RestMethod -Uri `$tokenAuthUri -Headers @{"Secret" = "`$env:MSI_SECRET"} -Method GET
`$token = `$tokenResponse.access_token    
`$connectionString = (Invoke-RestMethod -Method GET -Headers @{"Authorization" = "Bearer `$token"} -Uri "`$keyVaultUrl/secrets/sql?api-version=7.1").value

# Create a SQL Connection
`$connection = New-Object System.Data.SqlClient.SqlConnection
`$connection.ConnectionString = `$connectionString

# Open the connection
`$connection.Open()

# Create a SQL Command to fetch table names
`$command = `$connection.CreateCommand()
`$command.CommandText = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Execute the command and fetch results
`$reader = `$command.ExecuteReader()

`$tables = @()
while (`$reader.Read()) {
    `$tables += `$reader["TABLE_NAME"]
}

# Close the connection
`$connection.Close()

# Return table names as the response
`$body = @{
    tables = `$tables
} | ConvertTo-Json

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.Net.HttpStatusCode]::OK
    Body = `$body
})
"@ 
Set-AzWebApp -ResourceGroupName $rg -Name $functionAppName -AppSettings $envVariables | Out-Null
Write-Host "Creating functions" -ForegroundColor Green
func new function --name "GetDatabaseTables" --template "HTTP trigger" --authLevel "function" --worker-runtime PowerShell
func new function --name "GetDatabaseTablesMSI" --template "HTTP trigger" --authLevel "function" --worker-runtime PowerShell
Set-Content -Path .\function\GetDatabaseTables\run.ps1 -Value $code
Set-Content -Path .\function\GetDatabaseTablesMSI\run.ps1 -Value $codeMsi
Write-Host "Publishing function" -ForegroundColor Green
Set-Location ./function
func azure functionapp publish $functionAppName

