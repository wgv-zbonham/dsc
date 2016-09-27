param($deployContext, $credential)


Configuration DashboardConfiguration
{
	param($deployContext)
	
	 Import-DscResource -Module PSDesiredStateConfiguration, xWebAdministration, xComputerManagement, xSqlServer, xSystemSecurity
    
	Write-Verbose "Using certificate $($deployContext.DeploymentCertificateThumbprint)"

	Node localhost
	{
		LocalConfigurationManager 
        { 
             CertificateId = $deployContext.DeploymentCertificateThumbprint 
        } 	       

        File ApplicationFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $deployContext.ApplicationFolder
        }        
		
		File WatchGuardWwwFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = "{0}\apps\WatchGuardVideo\www" -f $deployContext.WatchGuardFolder            
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

		File DashboardWebContent
        {
            DestinationPath = $deployContext.ApplicationWwwFolder
            SourcePath = "{0}\{1}\Dashboard.Web" -f $deployContext.PackageFolder, $deployContext.PackageVersion
            Ensure = "Present"
            Type = "Directory"
            Checksum = "modifiedDate"
            Force = $true
            Recurse = $true
            MatchSource = $true
        }

		xFileSystemAccessRule SetWatchGuardFolderAccess 
		{
			Path = "$($deployContext.WatchGuardFolder)"
			Identity = "Administrators"
			Rights = "FullControl"
		
		}
       
	   xWebAppPool WatchGuardAppPool
		{
			Name = "WatchGuardVideo"
			Ensure = "Present"
			autoStart = $true
			managedPipelineMode = "Integrated"
			startMode = "AlwaysRunning"
			managedRuntimeVersion = "v4.0"
			identityType = "NetworkService"  # this identity is what we go after the database as, unless over riden in the connection string via sql auth
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
			identityType = "NetworkService"  # this identity is what we go after the database as, unless over riden in the connection string via sql auth
		}
		
		
        
		xWebsite WatchguardWebsite
        {
            Name = "WatchGuardVideo"
            ApplicationPool = "WatchGuardVideo"
            EnabledProtocols = "http"
            Ensure = "Present"
            PhysicalPath = "{0}\apps\WatchGuardVideo\www" -f $deployContext.WatchGuardFolder
            PreloadEnabled = $true
            State = "Started"
            BindingInfo  = @(   MSFT_xWebBindingInformation
                                {
                                   Protocol              = "HTTP"
                                   Port                  = 80                                   
                                }
                             )
        }
		
        #todo bindings need to be lifted up
        xWebsite DashboardWebsite
        {
            Name = "WatchGuardVideoDashboard"
            ApplicationPool = "EL-Dashboard"
            EnabledProtocols = "http"
            Ensure = "Present"
            PhysicalPath = "{0}\apps\Dashboard\www" -f $deployContext.WatchGuardFolder
            PreloadEnabled = $true
            State = "Started"
            BindingInfo  = @(   MSFT_xWebBindingInformation
                                {
                                   Protocol              = "HTTP"
                                   Port                  = 5000                                   
                                }
                             )
        }

        <#
        Archive DashboardContent
        {
            Ensure = "Present"  
            Path = "{0}\{1}\Dashboard.Web.zip" -f $deployContext.PackageFolder, $deployContext.PackageVersion
            Destination = $deployContext.ApplicationWwwFolder
        }
		#>

        
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
				Write-Verbose "Checking $path"
				[xml]$xml = Get-Content $path
		 
				#$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGEvidenceLibraryConnection']")
				#$cn = $node.Attributes["connectionString"].Value
				#$stateMatched = $cn -eq  $using:deployContext.Settings["WGEvidenceLibraryConnection"]
				#return $stateMatched
				return $false
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
		
		
		Script ModifyWebConfigDashboardPath
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//appSettings/add[@key='DashboardPath']")
								
				$node.Attributes["value"].Value = $using:deployContext.Settings["DashboardPath"]
				$xml.Save($path)
			}
			TestScript = 
			{
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//appSettings/add[@key='DashboardPath']")
				$cn = $node.Attributes["value"].Value
				$stateMatched = $cn -eq  $using:deployContext.Settings["DashboardPath"]
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
		
		Script ModifyWebConfigReportsPath
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//appSettings/add[@key='ReportsPath']")
								
				$node.Attributes["value"].Value = $using:deployContext.Settings["ReportsPath"]
				$xml.Save($path)
			}
			TestScript = 
			{
				$path = "$($using:deployContext.ApplicationWwwFolder)\web.config"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//appSettings/add[@key='ReportsPath']")
				$cn = $node.Attributes["value"].Value
				$stateMatched = $cn -eq  $using:deployContext.Settings["ReportsPath"]
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
		

		
		Script ChangeEtlWGEvidenceLibraryConnectionString
		{
			SetScript =
			{   
				$path = "$($using:deployContext.ApplicationBinFolder)\Dashboard.Etl.exe.config"
				Write-Verbose "ChangeEtlWGEvidenceLibraryConnectionString-SetScript $path"
				[xml]$xml = Get-Content $path
		 
				$node = $xml.SelectSingleNode("//connectionStrings/add[@name='WGEvidenceLibraryConnection']")

				if ($node -eq $null) 
				{
					Write-Error "Did not find connectionString named 'WGEvidenceLibraryConnection"
					return;
				}
				$cs = $using:deployContext.Settings["WGEvidenceLibraryConnection"]

				Write-Verbose "ChangeEtlWGEvidenceLibraryConnectionString-SetScript applying WGEvidenceLibraryConnection connectionString $cs"
								
				$node.Attributes["connectionString"].Value = $using:deployContext.Settings["WGEvidenceLibraryConnection"]
				Write-Verbose "ChangeEtlWGEvidenceLibraryConnectionString-SetScript saving web.config"

				$xml.Save($path)

				Write-Verbose "ChangeEtlWGEvidenceLibraryConnectionString-SetScript Saved"
			}
			TestScript = 
			{
				$path = "$($using:deployContext.ApplicationBinFolder)\Dashboard.Etl.exe.config"
				Write-Verbose "ChangeEtlWGEvidenceLibraryConnectionString $path"
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

<#
		xSqlServerLogin DashboardServiceAccount
		{
			Ensure = "Present"
			Name = "watchguardvideo\wgtsservice"
			LoginType = "WindowsUser"
			SqlServer = "."
			SQLInstanceName = "ZACHBONHAM"


		}
#>		

	}
}


DashboardConfiguration -deployContext $deployContext