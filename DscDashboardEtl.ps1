param($deployContext, $credential)


Configuration DscDashboardEtl
{
	param($deployContext)
	
	 Import-DscResource -Module PSDesiredStateConfiguration, xWebAdministration, xComputerManagement, xSqlServer, xSystemSecurity
    
	Node localhost
	{

		File WatchGuardFolder
        {
            Ensure = "Present"  
            Type = "Directory"             
			DestinationPath = $deployContext.WatchGuardFolder
        }

		
		xFileSystemAccessRule SetWatchGuardFolderAccess 
		{
			Path = "$($deployContext.WatchGuardFolder)"
			Identity = "Administrators"
			Rights = "FullControl"
		
		}         	       

        File ApplicationFolder
        {
            Ensure = "Present"  
            Type = "Directory" 
            
			DestinationPath = $deployContext.ApplicationFolder
        }        
		
		
        File DashboardEtlContent
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

        xScheduledTask DashboardEtlTask
        {
            TaskName = "WatchGuard Video EL Dashboard ETL"
            ActionExecutable = "{0}\Dashboard.Etl.Exe" -f $deployContext.ApplicationBinFolder
            ScheduleType = "Minutes"
            RepeatInterval = 5
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
	}
}


DscDashboardEtl -deployContext $deployContext