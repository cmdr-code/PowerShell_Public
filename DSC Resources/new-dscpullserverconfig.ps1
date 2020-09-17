#requires -version 4.0

#HTTP DSC Pull server setup

Configuration NewPullServerConfig {
Param (
[Parameter(Position=0,Mandatory,
HelpMessage="Enter a server name to configure as a Pull server")]
[ValidateNotNullorEmpty()]
[string[]]$ComputerName
) 

Import-DSCResource -ModuleName xPSDesiredStateConfiguration 

Node $ComputerName {
    #add the feature
    WindowsFeature DSCServiceFeature { 
        Ensure = "Present" 
        Name   = "DSC-Service"
    }

    #needed for compliance server
    WindowsFeature WebWindowsAuth {
        Ensure = "Present"
        Name   = "web-Windows-Auth"
        Dependson = "[WindowsFeature]DSCServiceFeature"
    }

    #environment variables will resolve locally
    xDscWebService PSDSCPullServer  {
        Ensure                  = "Present" 
        EndpointName            = "PSDSCPullServer" 
        Port                    =  8080
        PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\DSCPullServer"
        CertificateThumbPrint   = "AllowUnencryptedTraffic" 
        ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
        ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
        State                   = "Started"  
        DependsOn               = "[WindowsFeature]DSCServiceFeature"
    }

    #defining the compliance server
    xDscWebService PSDSCComplianceServer  {
        Ensure                  = "Present" 
        EndpointName            = "PSDSCComplianceServer" 
        Port                    =  9080
        PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\PSDSCComplianceServer"
        CertificateThumbPrint   = "AllowUnencryptedTraffic" 
        State                   = "Started" 
        IsComplianceServer      = $true 
        DependsOn               = @("[WindowsFeature]DSCServiceFeature","[xDSCWebService]PSDSCPullServer")  
    }
    
} #close Node        

} #close configuration

# Get-DscLocalConfigurationManager -CimSession chi-web02
restart-computer chi-web02 -wait

#create the MOF
NewPullServerConfig -computername chi-web02 -output c:\DSC\NewPullServer -verbose

psedit c:\dsc\NewPullServer\chi-web02.mof

#server needs the xPSDesiredStateConfiguration resource
$here = "$env:ProgramFiles\windowsPowerShell\Modules\xPSDesiredStateConfiguration"
$there = "\\chi-web02\c$\program files\windowsPowerShell\Modules\xPSDesiredStateConfiguration"

Copy-Item -path $here -Destination $there -force -Container -Recurse -PassThru 

#push the configuration
cls
$paramHash = @{
 Path = "C:\dsc\NewPullServer"
 ComputerName = "chi-web02"
 wait = $True
 verbose = $True
 Force = $True
}

Start-DscConfiguration @paramHash



 
