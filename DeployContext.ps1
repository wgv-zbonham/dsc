class DeployContext {

	[string]$WatchGuardFolder = "c:\watchguard"
	#[string]$DashboardWebFolder = "www\dashboard"
	#[string]$DashboardWebAppPool = "ELDashboard"
	[string]$DashboardWebCertThumbprint = ""
	
	[string]$WGEvidenceLibraryDb = "Data Source=.;Initial Catalog=WGEvidenceLibrary_CD;Integrated Security=True"
	[string]$WGReportDb = "Data Source=.;Initial Catalog=WGReport_CD;Integrated Security=True"
	[string]$WGLoggingDb = "Data Source=.;Initial Catalog=WGReport_CD;Integrated Security=True"
		
	
	
}