param()

@{
    AllNodes = 
    @(
        @{
            NodeName           = "*"
            WatchGuardFolder   = "C:\WatchGuardVideo"
        },
		@{
            NodeName           = "zachbonham"
            Role               = "DASHBOARD"
			WatchGuardFolder   = "C:\WatchGuardVideo"
        }
    );
}