#Variables
$rg = "rg-afd-apps-$(Get-Date -Format 'ddMMyyyy')"
$region  = 'East US'
Write-Host "Creating $rg in $region" -ForegroundColor Yellow
New-AzResourceGroup -Name $rg -Location $region | Out-Null
if(Get-Command dotnet){
    Write-Host "DotNet is installed, good to proceed " -ForegroundColor Green
}

else {
    Write-Error "DotNet is missing, install DotNet before proceeding" -ErrorAction Break
    Exit
}

function Build-Deploy {
    [CmdletBinding()]
    param (

    # ResourceGroup
    [Parameter(Mandatory = $true)]
    [String]
    $ResourceGroupName,

    # Plan Suffix
    [Parameter(Mandatory = $true)]
    [string]
    $Suffix,

    # Region
    [Parameter(Mandatory = $true)]
    [string]
    $Location
        
    )
    $appName = "$Suffix$(Get-Random)"
    Set-Location $HOME
    Write-Host "Creating a new app in dotnet : $appName" -ForegroundColor Yellow
    dotnet new webapp -n "KodeKloud-$Suffix" --framework net7.0
    Set-Location "KodeKloud-$Suffix"
    Write-Host "Creating $appName in Azure Web Apps" -ForegroundColor Yellow
    New-AzWebApp -Name $appName -ResourceGroupName $ResourceGroupName -Location $Location
    Write-Host "Building app locally" -ForegroundColor Yellow
    dotnet publish --configuration Release
    Set-Location bin\Release\net7.0\publish
    Compress-Archive -Path * -DestinationPath deploy.zip  
    Write-Host "Publishing code to $appName" -ForegroundColor Yellow
    Publish-AzWebApp -ResourceGroupName $ResourceGroupName -Name $appName  -ArchivePath (Get-Item .\deploy.zip).FullName -Force 
    Write-Host "Build and publish finished" -ForegroundColor Green
}

Build-Deploy -ResourceGroupName $rg -Location 'eastus' -Suffix "EUS"
Build-Deploy -ResourceGroupName $rg -Location 'westeurope' -Suffix "WEU" 
Build-Deploy -ResourceGroupName $rg -Location 'southeastasia' -Suffix "SEA" 