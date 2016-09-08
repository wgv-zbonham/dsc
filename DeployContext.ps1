
write-debug "Loading DeployContext"

class DeployContext {

    [string]$WatchGuardFolder = "c:\watchguardvideo"
    [string]$PackageFolder = $(Resolve-Path .\packages | Select -expandproperty Path)
    
	[string]$FeatureName = "Dashboard"
    [string]$FeatureVersion = "4.2.0.263"
    [PSCredential]$DeployCredential = $null
        
    [string]$PackageVersion = "overridden"
    [string]$ApplicationFolder = "overridden"
    [string]$ApplicationWwwFolder = "overridden"
    [string]$ApplicationBinFolder = "overridden"
	
	[string]$DashboardWebCertThumbprint = ""
    
    [hashtable]$DbConnections = @{ "WGReport" = "WGReport"; "WGStaging" = "WGStaging" }
    [hashtable]$SqlVars = @{ "WGReportDb" = "WGReport"; "WGStagingDb" = "WGStaging" }
	
    [string]$WGEvidenceLibraryDbName = "WGEvidenceLibrary"
   
    [string]$WGReportDbName = "WGReport"
    [string]$WGStagingDbName = "WGStaging"
    [string]$WGLoggingDbName = "WGReport"
    
	[string]$WGEvidenceLibraryDbConnectionString = "Data Source=.;Initial Catalog=WGEvidenceLibrary_CD;Integrated Security=True"
	[string]$WGReportDbConnectionString = "Data Source=.;Initial Catalog=WGReport_CD;Trusted_Connection=True"
	[string]$WGLoggingDbConnectionString = "Data Source=.;Initial Catalog=WGReport_CD;Trusted_Connection=True"
    
        
    # todo load from environment
    DeployContext () {
        $this.ApplicationFolder = "{0}\apps\{1}" -f $this.WatchGuardFolder, $this.FeatureName
        $this.ApplicationBinFolder = "{0}\bin" -f $this.ApplicationFolder
        $this.ApplicationWwwFolder = "{0}\www" -f $this.ApplicationFolder
        $this.PackageVersion = "{0}_{1}" -f $this.FeatureName, $this.FeatureVersion
    }

     <#
    DeployContext ([xml]$environment) {
    
        write-host $environment
    }
		#>
	
	
}