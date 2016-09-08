param($deployContext)
Configuration DashboardAppRole

{
	param($deployContext)
	
	 Import-DscResource -Module PSDesiredStateConfiguration, xWebAdministration
	
	Node localhost
	{		
        <#
        WindowsFeature WebManagementService
        {
            Ensure = "Present"
            Name = "Web-Mgmt-Service"
        }
        #>

        File ApplicationFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $deployContext.ApplicationFolder
        }
        <# 
        File BinFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $deployContext.ApplicationBinFolder            
        }
        #>
        File WwwFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $deployContext.ApplicationWwwFolder            
        }
        
        File DashboardEtl
        {
            DestinationPath = $deployContext.ApplicationBinFolder
            SourcePath = "{0}\{1}\Dashboard.Etl" -f $deployContext.PackageFolder, $deployContext.PackageVersion
            Ensure = "Present"
            Type = "Directory"
            Checksum = "modifiedDate"
            Force = $true
            Recurse = $true
            MatchSource = $true
        }
       
        # todo Identity needs to be lifted to deployContext
        xWebAppPool DashboardAppPool
		{
			Name = "EL-{0}" -f $deployContext.FeatureName
			Ensure = "Present"
			autoStart = $true
			managedPipelineMode = "Integrated"
			startMode = "AlwaysRunning"
			managedRuntimeVersion = "v4.0"
			identityType = "LocalSystem"  # this identity is what we go after the database as, unless over riden in the connection string via sql auth
		}
        
        #todo bindings need to be lifted up
        xWebsite DashboardWeb
        {
            Name = $deployContext.FeatureName
            ApplicationPool = "EL-{0}" -f $deployContext.FeatureName
            EnabledProtocols = "http"
            Ensure = "Present"
            PhysicalPath = $deployContext.ApplicationWwwFolder
            PreloadEnabled = $true
            State = "Started"
            BindingInfo  = @(   MSFT_xWebBindingInformation
                                {
                                   Protocol              = "HTTP"
                                   Port                  = 8000                                   
                                }
                             )
            
        }
        
        Archive DashboardContent
        {
            Ensure = "Present"  
            Path = "{0}\{1}\Dashboard.Web.zip" -f $deployContext.PackageFolder, $deployContext.PackageVersion
            Destination = $deployContext.ApplicationWwwFolder
        }
        
        <#
        xWebPackageDeploy DashboardWebPackage
        {
            SourcePath = "{0}\{1}\Dashboard.Web\Dashboard.Web.zip" -f $deployContext.PackageFolder, $deployContext.PackageVersion
            Destination = "c:\watchguardvideo\apps\Dashboard\www"
            Ensure = "Present"
        }
        #>
	}
}


DashboardAppRole -deployContext $deployContext