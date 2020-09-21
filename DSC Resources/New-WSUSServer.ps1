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
        # DotNet 3.5
        WindowsFeature DotNet35 {
           Ensure = "Present"
           Name   = "NET-Framework-Core"
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
            Classifications = @('E6CF1350-C01B-414D-A61F-263D14D133B4','E0789628-CE08-4437-BE74-2495B842F43B','0FA1201D-4330-4FA8-8AE9-B877473B6441','28BC880E-0592-4CBF-8F95-C79B17911D5F','CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83')
            # ("Critical Updates","Definition Updates","Security Updates","Update Rollups","Updates")
            ContentDir = "C:\WSUS_Updates"
            Languages = "en"
            Products = "Windows Server 2019"
            SynchronizationsPerDay = 1
            Synchronize = $true
            SynchronizeAutomatically = $true
            SynchronizeAutomaticallyTimeOfDay = "00:00"
            UpdateImprovementProgram = $False
            DependsOn = "[WindowsFeature]UpdateServices"
        }
        # DownloadUpdateBinariesAsNeeded = $False

        Service WSUS_Service {
            Name = "WSUSService"
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
