

<#
Requirements

    Windows Management Framework 5.0 (PowerShell)
    Network Access (to install module dependencies, working on including them in the package)
    Running as an Administrator on the server (filesystem, database access)
    
    RISK: PowerShell DSC Roles and Features requires server SKU's.  Non servers targets are a risk.
#>

. .\DeployDependencies.ps1
. .\DeployContext.ps1
. .\SqlPackager.ps1

# push down 
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True


[xml]$environment = get-content .\localhost.environment


$dc = new-object DeployContext

$credential = Get-Credential -Username $Env:Userdomain\$Env:Username -m "The credential that will be used to administer WatchGuard Video applications"
$dc.DeployCredential = $credential

Write-Host "Deploying database projects"

Deploy-WgvAllDatabases $dc

.\DashboardAppRole -deployContext $dc | out-null

Write-Host "DSC configuration starting ..."
Start-DscConfiguration -path .\DashboardAppRole -wait -force
Write-Host "DSC configuration complete"

Write-Host "Deployment Complete.  Have a nice day."
