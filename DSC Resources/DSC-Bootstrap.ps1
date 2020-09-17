#requires -version 4.0


<#
A DSC configuration demo
node is new server not domain joined with DHCP

Push an initial configuration to bootstrap it 
to its final Pull configuration

This is an interactive demo although you could use it as a
starting point for your own script.
#>

cls

#region pre-reqs

#create the pulled config and deploy to pull server with GUID

$guid = [guid]::NewGuid().guid
$guid

#the name of the newly created server
$NewServer = "R2Core-Base"
#the new domain name
$NewName =  "CHI-SRV03"
$NewCred = Get-Credential "$newServer\administrator"

#verify name resolution and ping
Test-Connection -ComputerName $newserver
Test-WSMan -ComputerName $newserver

#need to add computer to TrustedHosts for remoting
$saved = Get-Item WSMan:\localhost\Client\TrustedHosts

#parameters for Set-Item
$paramHash = @{
 Path = "WSMan:\localhost\client\trustedhosts"
 Force = $True
}

if ($saved.value) {    
    $paramHash.Add("value","$($saved.value),$newserver")
}
else {
    #no current entries
    $paramHash.Add("value",$newServer)
}

Set-Item @paramHash

#verify
Get-Item WSMan:\localhost\Client\TrustedHosts | Format-List

#endregion

#This configuration requires plain text passwords or you must 
#configure the file share tolet everyone read it

Configuration PushedConfig {

Param(
[System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
)

Import-DscResource -moduleName xNetworking,xComputerManagement

Node $allnodes.nodename {

xDNSServerAddress NewDNS {	

	Address =  @("172.16.30.203","172.16.30.200","8.8.8.8")
	InterfaceAlias = $Node.Interface
	AddressFamily = 'IPv4' 

} #end xDNSServerAddress resource

xComputer DomainJoin {
#I want this to be the last step
	Name = $node.newname
	Credential = $Credential
	DependsOn = "[xDNSServerAddress]NewDNS"
	DomainName = "Globomantics.local"

} #end xComputer resource

xIPAddress NewIP {

	InterfaceAlias = $Node.Interface
	IPAddress = $Node.IPAddress
	AddressFamily = 'IPv4'
	DefaultGateway = '172.16.10.254'
	SubnetMask = 16
    DependsOn = "[xComputer]DomainJoin"

} #end xIPAddress resource


LocalConfigurationManager {
    RebootNodeIfNeeded = $True
    AllowModuleOverwrite = $True

}

} #node

} #end PushedConfig

#LOAD THE CONFIGURATION INTO THE SESSION

#region copy necessary resources to new server
#create a temporary PSDrive with credentials for the new server
#You must be able to resolve new server name

$paramHash = @{
 Name = 'NewServerTmp' PSProvider = 'Filesystem' Root = "\\$NewServer\c$\Program Files\WindowsPowershell\Modules" Credential = $newcred}

New-PSDrive @paramHash

"xNetworking","xComputerManagement" | foreach {
    $a = "c:\program files\windowspowershell\modules\$_"
    $b =  "NewServerTmp:\"

    $paramHash = @{
     Path = $a     Destination = $b     Container = $True     Force = $True     Recurse = $True     Passthru = $True    }

    Copy-Item @paramHash
}

#verify
dir newservertmp:
#endregion

#region get required data

#create a cimsession to the new computer. 
#Assuming 2012R2 with remoting enabled.
$cs = New-CimSession -ComputerName $NewServer -credential $NewCred

$ifAlias = Get-NetAdapter -CimSession $cs | select -ExpandProperty Interfacealias

#verify
$ifalias

#endregion

#region define configdata for pushed configuration
$ConfigData = @{
    # Node specific data
    AllNodes = @( 
       @{
       NodeName = $NewServer;
       NewName = $NewName;
       IPAddress = "172.16.30.112";
       Interface = $IFAlias;
       PSDSCAllowPlainTextPassword = $True
       }
    )
}

#check it out
$configdata.allnodes

#endregion

#region create the MOF
$paramHash = @{
 configurationdata = $configdata credential = 'globomantics\administrator' outputpath = 'c:\DSC\PushedConfig' Verbose = $True}

PushedConfig @paramHash 

#look at the new MOF. Note plain text password
psedit (Join-path $paramhash.outputpath "$newserver.mof")

#update the LCM
Set-DscLocalConfigurationManager -CimSession $cs -Path $paramhash.outputpath -verbose

#verify Push mode
Get-DscLocalConfigurationManager -CimSession $cs
#endregion

#region push the configuration
cls
$paramHash = @{
 ComputerName = $NewServer
 path = "C:\dsc\PushedConfig"
 Credential = $newcred
 wait = $True
 verbose = $True
}

Start-DscConfiguration @paramHash

#reboot the server
Restart-Computer -computername $newserver -Force -Credential $NewCred -wait

#endregion

#define the Pulled configuration
Configuration PulledConfig {

Param(
[string]$Guid,
[System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty

)

Import-DSCResource -modulename xTimeZone,xWinEventLog,xNetworking

Node $allnodes.nodename {

#This should also be part of the desired state
xDNSServerAddress NewDNS {	

	Address =  @("172.16.30.203","172.16.30.200","8.8.8.8")
	InterfaceAlias = $Node.Interface
	AddressFamily = 'IPv4' 

} #end xDNSServerAddress resource

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

} #end PulledConfig

#region setup data for pulled config

psedit c:\scripts\Get-MachineCert.ps1
. c:\scripts\Get-MachineCert.ps1

#need to wait until new server gets a new certificate from AD
# invoke-command -scriptblock { certutil -pulse } -computername $newname
Invoke-Command -scriptblock {
do {
  Start-Sleep -seconds 5
} Until (Get-Item Cert:\LocalMachine\My)
} -computername $NewName

#need certificate to encrypt passwords
$cert = Export-MachineCert -computername $NewName -Path c:\certs

#create Configuration Data
#or this could be stored in a psd1 file
$ConfigData = @{
    # Node specific data
    AllNodes = @( 
       @{
       NodeName = $NewName;
       Interface = $IFAlias;
       Features = @("Windows-Server-Backup");
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
$paramHash = @{
 configurationData = $configData credential = "globomantics\administrator" guid = $guid outputpath = 'c:\dsc\PulledConfig'}

PulledConfig @paramHash

#copy MOF using GUID to Pull Server
$src = "C:\dsc\PulledConfig\$NewName.mof"
$dscPath = "\\chi-web02\c`$\program files\windowspowershell\dscservice\configuration"
$dst = Join-Path -path $dscpath -childpath "$guid.mof"

Copy-Item -path $src -des $dst -PassThru
#checksum the MOF
New-DSCChecksum $dst 

#set the new LCM
Set-DscLocalConfigurationManager -Path C:\dsc\PulledConfig -ComputerName $newname -verbose

#verify
Get-DscLocalConfigurationManager -CimSession $NewName

#check server later to see changes or invoke a pull request

#endregion

#region cleanup 

Remove-CimSession $cs
Remove-PSDrive newservertmp
Set-Item -Path WSMan:\localhost\client\trustedhosts -value $saved.value -Force

#endregion


