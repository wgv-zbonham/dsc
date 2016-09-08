

<#
Requirements

    Windows Management Framework 5.0 (PowerShell)
    PowerShell DSC Roles and Features requires server SKU's
    Web Deploy 3.5
    Network Access (to install module dependencies, working on including them in the package)
    Running as an Administrator on the server

#>

. .\DeployDependencies.ps1
. .\DeployContext.ps1


[xml]$environment = get-content .\localhost.environment

$dc = new-object DeployContext

.\DashboardAppRole -deployContext $dc

Start-DscConfiguration -path .\DashboardAppRole -wait -force
