
Configuration DashboardAppRole

{
	param()
	
	 Import-DscResource -Module PSDesiredStateConfiguration
	
	Node $AllNodes.ForEach
	{			
        File DirectoryCreate
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $Node.WatchGuardFolder
        }
	}
}

DashboardAppRole -ConfigurationData ConfigurationData.psd1