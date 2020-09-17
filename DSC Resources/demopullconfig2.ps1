#requires -version 4.0 

Configuration DemoPull2 {

Param(
[string]$guid,
[System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty

)

Import-DscResource -moduleName xNetworking,xTimeZone

Node $allnodes.nodename {

xTimeZone Eastern {

    TimeZone = "Eastern Standard Time"
    
}  #end xTimeZone


File MyWork {

	DestinationPath = "C:\MyWork"
	Ensure = "Present"
	Force = $True 
	Type = "Directory"

} #end File resource

xDnsServerAddress ChicagoDNS   {
    Address        = "172.16.30.203","172.16.30.200","8.8.8.8"
    InterfaceAlias = $node.interface
    AddressFamily  = "IPv4"

} #end DNSServer resource

Group MyDemo {
	GroupName = "MyDemo"
	Description = "A demo local group"
	Ensure = "Present"
    Credential = $Credential
	MembersToInclude = "Globomantics\Jeff"

} #end Group resource

LocalConfigurationManager {      AllowModuleOverwrite  = "True"
    ConfigurationID = $Guid
    ConfigurationMode = "ApplyandMonitor"
    RefreshMode = "Pull"
    DownloadManagerName = "WebDownloadManager"    DownloadManagerCustomData = @{
        ServerUrl = "http://chi-web02.globomantics.local:8080/PSDSCPullServer.svc"; 
        AllowUnsecureConnection = "True"
      }             CertificateID = $node.thumbprint} #LCM

} #end node

} #close configuration


<#
#sample
$ConfigData
$cdtest = @{
  AllNodes = @( 
    @{
       NodeName = "CHI-CORE01"                
       CertificateFile = "C:\certs\chi-core01.cer"
       Thumbprint = "E7419DA21907361EC82AD1F5D27F674CBCB802AC" 
     }; 
   );
} 
#>

