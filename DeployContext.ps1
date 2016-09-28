
write-debug "Loading DeployContext"

class DeployContext {

    [string]$NodeName = [System.Net.Dns]::GetHostName()
    [string]$WatchGuardFolder = "overridden"
    [string]$PackageFolder = $(Resolve-Path .\packages | Select -expandproperty Path)
    
	[string]$FeatureName = "Dashboard"
    [string]$FeatureVersion = "4.2.0.263"
    [PSCredential]$DeployCredential = $null
        
    [string]$PackageVersion = "overridden"
    [string]$ApplicationFolder = "overridden"
    [string]$ApplicationWwwFolder = "overridden"
    [string]$ApplicationBinFolder = "overridden"
	
	[string]$DashboardWebCertThumbprint = ""
    
    [hashtable]$DbConnections = @{ "WGEvidenceLibrary" = "WGEvidenceLibrary"; "WGReport" = "WGReport"; "WGStaging" = "WGStaging" }
    [hashtable]$SqlVars = @{ "WGReportDb" = "WGReport"; "WGStagingDb" = "WGStaging" }
	
    [string]$WGEvidenceLibraryDbName = "WGEvidenceLibrary"
   
    [string]$WGReportDbName = "WGReport"
    [string]$WGStagingDbName = "WGStaging"
    [string]$WGLoggingDbName = "WGReport"
	
	[hashtable]$Settings = @{}
    [string]$DeploymentCertificateThumbprint = "overridden"

    
        
    # todo load from environment
    DeployContext ([hashtable]$settings) {
	
		$this.Settings = $settings
	
		$this.WatchGuardFolder = $this.Settings["WatchGuardFolder"]
        $this.ApplicationFolder = "{0}\apps\{1}" -f $this.WatchGuardFolder, $this.FeatureName
        $this.ApplicationBinFolder = "{0}\bin" -f $this.ApplicationFolder
        $this.ApplicationWwwFolder = "{0}\www" -f $this.ApplicationFolder
        $this.PackageVersion = "{0}_{1}" -f $this.FeatureName, $this.FeatureVersion
		
		Write-Host $this.ApplicationWwwFolder
		
    }

     <#
    DeployContext ([xml]$environment) {
    
        write-host $environment
    }
		#>
	
	
}