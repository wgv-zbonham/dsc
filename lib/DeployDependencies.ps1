

function Install-ModuleIfNeeded ($moduleName) {

		
    if ((Get-Module -Name $moduleName) -eq $null) {

		Write-Host "Acquiring dependency $moduleName"
        Install-Module $moduleName
    }
}


Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Write-Verbose

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Write-Verbose


Install-ModuleIfNeeded xWebAdministration
Install-ModuleIfNeeded xComputerManagement
Install-ModuleIfNeeded xSqlServer
Install-ModuleIfNeeded xSystemSecurity



# Get-Credential prompts at command line
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True
