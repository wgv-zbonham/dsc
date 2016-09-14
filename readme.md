## PANDA - Packaging and Deployment Automation
Package, and deployment, automation is not a new concept. Today, we have a process where each build gets rolled up into a Windows installer (the package). The creation of that package is slow.  Its bound to specific licensed agents, and its using a specialized technology (MSI), resulting in a package that, once completed, is not easily inspected. What we don't have is ease of use when we add new components and features.  We need to create a completely new installer for the new component.  Adding a new website?  It needs a new, custom, installer.  Same thing with Windows services.  These components all have similar requirements, and install the exact same way.  How they differ is the metadata required.  The metadata ties it all together.  With metadata associated with each project we can then use a common tooling to produce a package during the build, and packaging, phase.


### What is a Package?
A package is simply a directory folder containing the resources, and metadata, that need to be deployed.  A package can contain a single component or it contain everything.  Once assembled, the package does not change (though it can be manually manipulated).  The package is what travels from environment to environment.  What changes is the environment.config is input to the deployment process.  In some scenarios, there may be no change, as in the "all in one" scenario.


### What is metadata?
Examples of metadata would be resource type (web, service, file, etc), role, required identies, connection string names, endpoints, etc.  Defined as part of the application development process.

### What is environment.config?
The environment.config is an information model about the environment: servers, roles, connection strings, identities, etc.  The metadata keys, and default values, will be lifted up from metadata found with each package, and merged with the values found in the environment.config.  The environment.config will contain things normally prompted for during the tradtional installation process.  The goal would be to have a majority of these not change per environment, but when they do, there is a single place to make the change, then execute the deploy.

The environment.config will default to installing all roles on the local machine.  The environment.config will also support defining multiple servers and assinging them roles, and having PANDA provision those machines as well.

When we start leveraging roles associated with servers, the deployment will not actually install anything from the package that does not match the role associated with the hostname.  However, the operator will always have the ability to override the behavior or install specific roles (e.g. Deploy-WgvRole -role WIRELESS).

### Patches
Ideally, patches are just complete, but updated, versions of the software.

## Goals

* Simplified packaging and deployment process
* Transparency (can peek into packages, scripts, and understand deployment flow)
* Deployment process that meets the needs of each team.  
* EL 5.0 readiness.  Future products are Azure hosted. Azure does not support MSI based installers easily (there are no servers).  Ideally, we will have similar, if not the same, process for deploying.  While we likely won't replace MSI based installers for client components, all server installs will be PowerShell based.
* Faster onboarding of new applications and services.  Developer will create metadata file and tooling will take care of package creation.
* Faster daily activity. From check in, to deployment to a test environment, is ~40 minutes. This is building the software, packaging the software, then deploying the software. This is a huge amount of waste in our value chain.  Using similar techniques today, we are consistently 1-2 minutes, from developer check in, to server deployment.  This includes deploying 2 databases, 1 website, 1 scheduled task and triggering an external process.  



## Requirements

* Windows Management Framework 5.0 (PowerShell)
** PowerShell DSC is only a requirement because we are trying it as a basis for the tooling.  It gives us many community sourced resources that we are not required to write.
* Some features of the deployment process (multi server) will require pushing to remote servers using WinRM.  This is a feature that is auto-configured on Windows Server 2012R2 but may need to be manually configured for remote machines on previous versions of Windows Server.
* Should be able to bypass remote deployments by copying packages directly to target servers and executing the local, rol based, deployment
* Running as an Administrator on the server (filesystem, database access)
    
## Risks    

* PowerShell DSC Roles and Features requires server SKU's.  Non servers targets are a risk.  However, if we can get away from targeting non server OS's, for server components, we can elminiate entire test branches, too.
* Known module dependencies likely need to be included in the package
* Command line, not everyone is comfortable with the command line.  Even just running .\deploy.ps1.  To mitigate, we can wrap that in .\deploy.bat, and still have single click install for majority of our customers.


## References

Zach Bonham - [PANDA - Packaging and Deployment Automation](http://zachbonham.blogspot.com/2010/03/panda-packaging-and-deployment.html)  
Zach Bonham - [Software Delivery Bottlenecks](http://zachbonham.blogspot.com/2012/04/software-delivery-bottlenecks.html)
