

function Install-ModuleIfNeeded ($moduleName) {
    
    if (-not (Get-Module -Name $moduleName)) {
        Install-Module $moduleName -force
    }
}


Install-ModuleIfNeeded PSDesiredStateConfiguration
Install-ModuleIfNeeded xWebAdministration
Install-ModuleIfNeeded xWebDeploy

