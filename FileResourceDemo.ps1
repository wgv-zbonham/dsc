Configuration FileResourceDemo
{
	Node localhost
	{	
        File DirectoryCreate
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            
			DestinationPath = "C:\wgv\apps"
        }
	}
}

FileResourceDemo