

Configuration DashboardWebRole
{
	Node localhost
	{	
        File DirectoryCreate
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = "C:\wgv\apps"
        }
		
		
		xWebAppPool DashboardAppPool
		{
			Name = "Dashboard"
			Ensure = "Present"
			autoStart = $true
			managedPipelineMode = "Integrated"
			startMode = "AlwaysRunning"
			managedRuntimeVersion = "v4.0"
			identityType = "LocalSystem"  # this identity is what we go after the database as, unless over riden in the connection string via sql auth
		}
	}
}

DashboardWebRole