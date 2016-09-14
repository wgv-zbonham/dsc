

# "C:\SqlPackager\SqlPackage.exe /action:publish /targetdatabasename:%(DacPacs.Filename)_CD /targetservername:$(DatabaseServerName) /sourcefile:%(DacPacs.FullPath) /p:CreateNewDatabase=true /v:WGReportDb=$(WGReportDb) /v:WGStagingDb=$(WGStagingDb)" 	

$SqlPackageExe = Resolve-Path .\tools\sqlpackager\sqlpackage.exe

function Deploy-WgvDatabase($servername, $databasename, $dacpac, $alwaysCreate = $true, $sqlvars = @{})
{
	Write-Verbose "Deploying $databasename to $servername"
    Write-Debug("Deploy-WgvDatabase($servername, $databasename, $dacpac, $alwaysCreate = $true, $sqlvars = @{})")
    
    $cmd = "$SqlPackageExe /action:publish /targetdatabasename:$databasename /targetservername:$servername /sourcefile:$dacpac /p:CreateNewDatabase=$alwaysCreate " + $(Get-WgvSqlCmdVarsFrom $sqlvars)
    
    Write-Debug($cmd)
    
    iex $cmd | Write-Verbose
    
}

function Deploy-WgvAllDatabases([DeployContext]$deployContext) {

   Write-Debug("Deploy-WgvAllDatabases")

    $packageFolder = resolve-path $deployContext.PackageFolder
 
    $dacpacs = iex "dir $packageFolder\*.dacpac -recurse"
    
    foreach($dacpac in $dacpacs) 
    {
        $dbName = [io.path]::GetFileNameWithoutExtension($dacpac.Name)
        $actualDbName = $dbName
        
        if ( $deployContext.DbConnections.ContainsKey($dbName) ) 
        {
            $actualDbName = $deployContext.DbConnections[$dbName]
        }
        
        Deploy-WgvDatabase -servername localhost -databasename $actualDbName -dacpac  $dacpac.FullName -sqlvars $deployContext.SqlVars      
    }
}



function Get-WgvSqlCmdVarsFrom($sqlvars) 
{
    $varstring = ""
    
    foreach($key in $sqlvars.Keys)
    {
        $value = $sqlvars[$key]
        
        $varstring += "/v:{0}={1} " -f $key, $value
    }    
    return $varstring    
}



class DatabaseConnection {
    [string]$ServerName = $null
    [string]$DatabaseName = $null
    
    DatabaseConnection ($connectionString) {

        $db = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        
        $this.ServerName = $db.DataSource
        $this.DatabaseName = $db.Database
        
        $db.Dispose()
    
    }
    
    
}