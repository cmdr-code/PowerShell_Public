#requires -version 4.0

<#
DSC Considerations:

> Do you configure domain or non-domained joined servers?
> Will there be authentication issues?
> Do you need to use passwords which should be encrypted?
> Will the resources you want to use require anything
  additional on the server?
> What will you configure via Group Policy or SCCM?
> What configuration mode do you really need?
> Are you using DSC for ease of setup and configuration
  or to enforce a desired state? 
> Would you benefit from some combination of PowerShell
  script or workflow with DSC?

#>

<#
This sample configuration is for a new machine that has 
already been joined to the domain but with a DHCP 
assigned address.
#>

Configuration ChicagoServer {
Param(
[Parameter(Position=0,Mandatory)]
[string]$Computername,
[string]$GUID,
[System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty

)

Import-DSCResource -modulename xNetworking,xTimeZone,xWinEventLog

Node $Computername {

File Company {
    Ensure = "Present"
    DestinationPath = "c:\Company"
    Type = "Directory"
}

#be careful of permissions. DSC runs under the SYSTEM context
File ITScripts {
    SourcePath = "\\chi-fp02\IT\Scripts"
    DestinationPath = "c:\Company\IT"
    Recurse = $True
    Type = "Directory"
    Ensure = "Present"
    DependsOn = "[File]Company"  
} #end IT Scripts

xIPAddress NewIP {
	InterfaceAlias = $Node.Interface
	IPAddress = $Node.IPAddress
	AddressFamily = 'IPv4'
	DefaultGateway = '172.16.10.254'
	SubnetMask = 16
    DependsOn = "[File]ITScripts"  #don't change until file copy done
} #end xIPAddress resource

xDNSServerAddress IPconfig {	
	Address =  @("172.16.30.203","172.16.30.200","8.8.8.8")
	InterfaceAlias = $Node.Interface
	AddressFamily = 'IPv4' 
	DependsOn = "[xIPAddress]NewIP"
} #end xDNSServerAddress resource

xTimeZone Eastern {
    TimeZone = "Eastern Standard Time"
}  #end xTimeZone

xWinEventLog System {
	LogName = 'System'
	LogMode =  'Retain'
	MaximumSizeInBytes = 64MB
} #end xWinEventLog resource

xWinEventLog Security {
	LogName = 'Security'
	LogMode = 'AutoBackup'
	MaximumSizeInBytes = 128MB
} #end xWinEventLog resource

#region dynamically create resource configurations for each node
#this uses new v4 ForEach syntax
$ConfigurationData.NonNodeData.Services.foreach({
  Service $_ {
   Name = $_
   StartupType = "Automatic"
   State = "Running"
   }

}) #foreach service

#add defined features for all nodes
$Node.features.foreach({ 
    WindowsFeature $_ {
        Name = $_
        Ensure = "Present"
       }
})

#configure LCM
LocalConfigurationManager {

    AllowModuleOverwrite  = $True
    ConfigurationID = $Guid
    ConfigurationMode = "ApplyandAutoCorrect"
    RefreshMode = "Pull"
    DownloadManagerName = "WebDownloadManager"    DownloadManagerCustomData = @{
        ServerUrl = "http://chi-web02.globomantics.local:8080/PSDSCPullServer.svc"; 
        AllowUnsecureConnection = "True"
      }             CertificateID = $node.thumbprint

} #LCM
} #Node

} #configuration

#load the configuration into the session

#region setup data

$ifAlias = Get-NetAdapter -CimSession CHI-SRV02 | select -ExpandProperty Interfacealias

psedit c:\scripts\Get-MachineCert.ps1
. c:\scripts\Get-MachineCert.ps1

#need certificate to encrypt passwords
$cert = Export-MachineCert -computername chi-srv02 -Path c:\certs

$cert

#create Configuration Data
#or this could be stored in a psd1 file
$ConfigData = @{
    # Node specific data
    AllNodes = @( 
       @{
       NodeName = "CHI-SRV02";
       Features = @("Windows-Server-Backup",
       "Windows-Internal-Database",
       "Web-FTP-Server","Telnet-Server");
       IPAddress = "172.16.30.111";
       Interface = $IFAlias;
       CertificateFile = $cert.path
       Thumbprint = $cert.thumbprint
       }
    )
    ;
    #non-node Specific data
    #no code allowed
    NonNodeData = @{Services = "bits","remoteregistry","wuauserv"}
}

#what do we have?
$configdata.allnodes

#endregion

#region create the MOF
$credential = Get-Credential globomantics\jeff
$guid = [guid]::NewGuid().guid

$paramHash = @{
 configurationData = $configData credential = $credential guid = $guid computername = 'chi-srv02' outputpath = 'c:\dsc\ChicagoServer'}

ChicagoServer @paramHash

#endregion

#region set the LCM
$paramHash = @{
 ComputerName = 'chi-srv02' path = 'c:\dsc\chicagoServer' Verbose = $True}

Set-DscLocalConfigurationManager @paramHash

Get-DscLocalConfigurationManager -cimsession $paramhash.computername

#endregion

#region copy MOF with GUID to pull server
#double check the MOF
psedit "C:\dsc\chicagoServer\chi-srv02.mof"

 $src = "C:\dsc\chicagoServer\chi-srv02.mof"
 $dscPath = "\\chi-web02\c`$\program files\windowspowershell\dscservice\configuration"
 $dst = Join-path -path $dscpath -childpath "$guid.mof"

 Copy-Item -path $src -des $dst -PassThru
 #checksum the MOF
 New-DSCChecksum $dst 

 dir "$dscpath\$guid*"
 
#endregion

#region force the configuration
psedit s:\invoke-pull.ps1 
. s:\invoke-pull.ps1

cls
invoke-pull -computername chi-srv02 -verbose

#reboot the server
restart-computer -ComputerName chi-srv02 -wait -force

#might need to clear cache
ipconfig /flushdns
nbtstat -R

#make sure we can connect to it
test-connection chi-srv02

#endregion

#region validate

Get-DscConfiguration -CimSession chi-srv02.globomantics.local

get-service $ConfigData.NonNodeData.services -ComputerName chi-srv02
invoke-command {dir c:\company -recurse } -ComputerName chi-srv02
get-windowsfeature -ComputerName chi-srv02 | where installed
invoke-command {ipconfig /all } -ComputerName chi-srv02
get-eventlog -list -computername chi-srv02

#endregion

#region demo notes

<#
reset items:
remove DNS entries with new IP
verify certificate
delete mof and checksum from pull server

#>

#endregion