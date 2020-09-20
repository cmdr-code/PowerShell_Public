configuration New-WSUSServer {
Param (
[Parameter(Position=0,Mandatory,
HelpMessage="Enter a server name to configure as a WSUS server")]
[ValidateNotNullorEmpty()]
[string[]]$ComputerName
) 

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName UpdateServicesDsc
    #Import-Module NetworkingDsc
    #Import-Module xWebAdministration
    #Import-Module xWindowsUpdate
    

    # One can evaluate expressions to get the node list
    # E.g: $AllNodes.Where("Role -eq Web").NodeName
    # $AllNodes.Where{$_.Role -eq "WebServer"}.NodeName
    node $ComputerName {
        WindowsFeature DotNet35 {
           Ensure = "Present"
           Name   = "NET-Framework-Core" # DotNet 3.5
           Source = "D:\sources\sxs"
        }

        # UpdateServices
        WindowsFeature UpdateServices {
           Ensure = "Present"
           Name   = "UpdateServices"
           DependsOn = "[WindowsFeature]DotNet35"
        }

        WindowsFeature UpdateServices_RSAT {
           Ensure = "Present"
           Name   = "UpdateServices-RSAT"
           IncludeAllSubFeature = $True
           DependsOn = "[WindowsFeature]UpdateServices"
        }

        File WSUS_Updates_Directory {
            Ensure          = "Present"
            DestinationPath = "C:\WSUS_Updates"
            Type            = "Directory"
            DependsOn       = "[WindowsFeature]UpdateServices"
        }
        
        UpdateServicesServer WSUS_Configuration {
            Ensure = "Present"
            Classifications = ''
            ContentDir = "C:\WSUS_Updates"
            Languages = 'en'
            Products = 'Windows Server 2019'
            SynchronizationsPerDay = 1
            Synchronize = $true
            SynchronizeAutomatically = $true
            SynchronizeAutomaticallyTimeOfDay = "00:00"
            UpdateImprovementProgram = $False
            DependsOn = "[WindowsFeature]UpdateServices"
        }
        
        Service WSUS_Service {
            Name = "WSUSServer"
            StartUpType = "Automatic"
            State = "Running"
            DependsOn = "[WindowsFeature]UpdateServices"
        }      
    }
}

# ConfigurationName -configurationData <path to ConfigurationData (.psd1) file>

#create the MOF
New-WSUSServer -computername TEST01 -output c:\DSC\New-WSUSServer -verbose

#push the configuration
$paramHash = @{
 Path = "C:\dsc\New-WSUSServer"
 ComputerName = "TEST01"
 wait = $True
 verbose = $True
 Force = $True
}

Start-DscConfiguration @paramHash
