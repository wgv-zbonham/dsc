param($deployContext)


Configuration DashboardConfiguration
{
	param($deployContext)
	
	 Import-DscResource -Module PSDesiredStateConfiguration, xWebAdministration, xComputerManagement
    
	
	Node localhost
	{	       

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
        xWebsite DashboardWebsite
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
        
        xScheduledTask DashboardEtlTask
        {
            TaskName = "WatchGuard Video EL Dashboard ETL"
            ActionExecutable = "{0}\Dashboard.Etl.Exe" -f $deployContext.ApplicationBinFolder
            ScheduleType = "Minutes"
            RepeatInterval = 5
        }
		
		# todo, this needs to be its own module 								
		Script ChangeWGEvidenceLibraryConnectionString
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGEvidenceLibraryConnection']")
								
				$node.Attributes["connectionString"].Value = $using:deployContext.Settings["WGEvidenceLibraryConnection"]
				$xml.Save($path)
			}
			TestScript = 
			{						    
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGEvidenceLibraryConnection']")
				$cn = $node.Attributes["connectionString"].Value
				$stateMatched = $cn -eq  $using:deployContext.Settings["WGEvidenceLibraryConnection"]
				return $stateMatched
			}
			GetScript = 
			{
				return @{
					GetScript = $GetScript
					SetScript = $SetScript
					TestScript = $TestScript
					Result = false
				}
			} 
		}
		
		Script ChangeWGReportConnectionString
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGReportConnection']")
								
				$node.Attributes["connectionString"].Value = $using:deployContext.Settings["WGReportConnection"]
				$xml.Save($path)
			}
			TestScript = 
			{
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGReportConnection']")
				$cn = $node.Attributes["connectionString"].Value
				$stateMatched = $cn -eq  $using:deployContext.Settings["WGReportConnection"]
				return $stateMatched
			}
			GetScript = 
			{
				return @{
					GetScript = $GetScript
					SetScript = $SetScript
					TestScript = $TestScript
					Result = false
				}
			} 
		}
		
		Script ChangeLoggingDbConnectionString
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='LoggingDb']")
								
				$node.Attributes["connectionString"].Value = $using:deployContext.Settings["LoggingDb"]
				$xml.Save($path)
			}
			TestScript = 
			{
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='LoggingDb']")
				$cn = $node.Attributes["connectionString"].Value
				$stateMatched = $cn -eq  $using:deployContext.Settings["LoggingDb"]
				return $stateMatched
		
			}
			GetScript = 
			{
				return @{
					GetScript = $GetScript
					SetScript = $SetScript
					TestScript = $TestScript
					Result = false
				}
			} 
		}

	}
}


DashboardConfiguration -deployContext $deployContext