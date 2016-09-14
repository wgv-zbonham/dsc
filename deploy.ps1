
param($environmentPath="localhost.environment")

<#
Requirements

    Windows Management Framework 5.0 (PowerShell)
    Network Access (to install module dependencies, working on including them in the package)
    Running as an Administrator on the server (filesystem, database access)
    
    RISK: PowerShell DSC Roles and Features requires server SKU's.  Non servers targets are a risk.
#>

cls

Write-Host "$([char]0x00A9) 2016, WatchGuard Video.  All rights reserved."
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Package deployment starting ..."
Write-Host "Node Name: $env:computername.$env:userdnsdomain"
Write-Host "Identity: $(whoami)"


$fi = new-object system.io.fileinfo $myinvocation.mycommand.path
$lib = [system.io.path]::Combine($fi.DirectoryName, "lib")


Write-Debug ("loading lib from directory:  "  + $lib)

# load all
foreach( $dir in dir $lib\*.ps1) {
	write-debug ( "loading lib: " + ($dir.FullName) )
 
	. $dir.FullName 
}

function Deploy($settings) {


	. .\DeployContext.ps1

	$dc = new-object DeployContext $settings
		
	<#
	$credential = Get-Credential -Username $Env:Userdomain\$Env:Username -m "The credential that will be used to administer WatchGuard Video applications"
	$dc.DeployCredential = $credential
	#>

	Write-Host "Deploying database projects"

	# Deploy-WgvAllDatabases -deployContext $dc

	.\DashboardConfiguration -deployContext $dc | out-null

	Write-Host "DSC configuration starting ..."
	Start-DscConfiguration -path .\DashboardConfiguration -wait -force
	Write-Host "DSC configuration complete"


}

Write-Host "Loading environment settings from $environmentPath"
[xml]$xml = Get-Content -path $environmentPath 

$settings = @{}
foreach($setting in $xml.environment.settings.setting) 
{	
	$settings[$setting.name] = $setting.value
}



$deployTime = Measure-Command { Deploy $settings }


Write-Host ""
Write-Host "Package deployment complete in $("{0:hh\:mm\:ss\,fff}" -f $deployTime).   Have a nice day."

