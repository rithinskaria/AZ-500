#pref 
$WarningPreference = 'SilentlyContinue'
#Variables
$rg = "rg-akv-fn-$(Get-Date -Format 'ddMMyyyy')"
$location = 'eastus'
$functionAppName = "fn$(Get-Random)$(Get-Date -Format 'ddMM')"

New-AzResourceGroup -Name $rg -Location $location
# Create a new service principal
Write-Host "Creating service principal" -ForegroundColor Green
$spn = New-AzADServicePrincipal -DisplayName "spn-akvfn$(Get-Random)"
$clientId = $spn.AppId
$clientSecret = (New-AzADSpCredential -ObjectId $spn.Id).SecretText
$tenantId= (Get-AzContext).Tenant.Id

# Create a new Function App
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
    "TenantId" = $tenantId
    "ClientId" = $clientId
    "ClientSecret" = $clientSecret
    "ServicePrincipalName" = $spn.DisplayName
    "AzureWebJobsStorage" = "DefaultEndpointsProtocol=https;$($storageKey.Split(';')[-2]);$($storageKey.Split(';')[-1]);EndpointSuffix=core.windows.net"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "FUNCTIONS_WORKER_RUNTIME" = "powershell"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = "DefaultEndpointsProtocol=https;$($storageKey.Split(';')[-2]);$($storageKey.Split(';')[-1]);EndpointSuffix=core.windows.net"
}
Set-AzWebApp -ResourceGroupName $rg -Name $functionAppName -AppSettings $envVariables | Out-Null

# Create the Azure Function to handle the HTTP request
$functionContent = @"
using namespace System.Net
param(`$Request, `$TriggerMetadata)
`$tenantId = `$env:TenantId
`$clientId = `$env:ClientId
`$clientSecret = `$env:ClientSecret
`$keyVaultName = `$Request.Query.keyVaultName
`$keyName = `$Request.Query.secret
`$body = @{
    grant_type    = "client_credentials"
    client_id     = "`$clientId"
    client_secret = "`$clientSecret"
    resource      = "https://vault.azure.net"
}
`$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/`$tenantId/oauth2/token" -Body `$body
`$token = `$tokenResponse.access_token
`$headers = @{
    'Authorization' = "Bearer `$token"
}
`$uri = "https://`$keyVaultName.vault.azure.net/secrets/`$keyName"
`$appendString = "?api-version=7.0"
`$uri = "{0}{1}" -f `$uri, `$appendString
`$keyVaultResponse = Invoke-RestMethod -Method Get -Headers `$headers -Uri `$uri

if (`$keyVaultResponse) {
    `$status = [HttpStatusCode]::OK
    `$body = `$keyVaultResponse.value
} else {
    `$status = [HttpStatusCode]::InternalServerError
    `$body = "Failed to retrieve the key from Key Vault.  ``n `$uri ``n `$keyVaultResponse"
}
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = `$status
    Body = `$body
})
"@

#Create and deploy fn
Write-Host "Creating function" -ForegroundColor Green
func new function --name "RetrieveKey" --template "HTTP trigger" --authLevel "function" --worker-runtime PowerShell
Set-Content -Path .\function\RetrieveKey\run.ps1 -Value $functionContent
Write-Host "Publishing function" -ForegroundColor Green
Set-Location ./function
func azure functionapp publish $functionAppName

