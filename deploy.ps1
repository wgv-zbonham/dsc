
param($environmentPath="environment.xml")

<#
Requirements

    Windows Management Framework 5.0 (PowerShell)
    Network Access (to install module dependencies, working on including them in the package)
    Running as an Administrator on the server (filesystem, database access)
    
    RISK: PowerShell DSC Roles and Features requires server SKU's.  Non servers targets are a risk.
#>

cls

$deployTime = [datetime]::Now.ToString("yyyy-MM-dd-HHmmss")
$logname = ".\deploy.{0}.log" -f $deployTime
Start-Transcript -path $logname -Append

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



function MakeCert() {
	Write-Verbose("Creating deployment certificate")

	New-SelfsignedCertificateEx -Subject "CN=${ENV:ComputerName}" -EKU 'Document Encryption' -KeyUsage 'KeyEncipherment, DataEncipherment'-SAN ${ENV:ComputerName} -FriendlyName 'WatchGuard Video Deployment Encryption Certificate' -Exportable -StoreLocation 'LocalMachine' -KeyLength 2048 -ProviderName 'Microsoft Enhanced Cryptographic Provider v1.0' -AlgorithmName 'RSA' -SignatureAlgorithm 'SHA256'

	# Locate the newly created certificate
	$Cert = Get-ChildItem -Path cert:\LocalMachine\My `
		| Where-Object {
			($_.FriendlyName -eq 'WatchGuard Video Deployment Encryption Certificate') `
			-and ($_.Subject -eq "CN=${ENV:ComputerName}")
		} | Select-Object -First 1


	$thumbprint = $Cert.Thumbprint
	$certificatePath = Join-Path -Path $fi.DirectoryName -ChildPath "WatchGuardVideo.Deployment.cer"

	Write-Verbose "thumbprint: $thumbprint"

	
	# export the public key certificate
	$cert | Export-Certificate -FilePath $certificatePath -Force

	Write-Verbose("Created deployment certificate $certificatePath and thumbprint $thumbprint")
	
	return @{ "CertificateFile" = $certificatePath; "Thumbprint" = $cert.Thumbprint }
}


function Deploy($settings) {


	$certificateData = MakeCert

	. .\DeployContext.ps1

	$dc = new-object DeployContext $settings
		
	
	#$credential = Get-Credential -Username $Env:Userdomain\$Env:Username -m "The credential that will be used to administer WatchGuard Video applications" 
	$dc.DeployCredential = $credential
	$dc.DeploymentCertificateThumbprint = $certificateData.Thumbprint
	

	Write-Host "Deploying database projects"

	$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            CertificateFile = $certificateData.CertificateFile
			Thumbprint = $certificateData.Thumbprint
        }
    )
}

	.\DashboardConfiguration -deployContext $dc -ConfigurationData $cd -Credential $credential | out-null

	Set-DscLocalConfigurationManager .\DashboardConfiguration
	
	Write-Host "DSC configuration starting ..."
	Start-DscConfiguration -path .\DashboardConfiguration -wait -force -Credential $credential
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
Stop-Transcript

