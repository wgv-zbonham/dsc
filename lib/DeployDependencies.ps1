

function Install-ModuleIfNeeded ($moduleName) {
    
    if ((Get-Module -Name $moduleName) -eq $null) {

        Install-Module $moduleName
    }
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted



Install-ModuleIfNeeded xWebAdministration
Install-ModuleIfNeeded xComputerManagement


# Get-Credential prompts at command line
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True
