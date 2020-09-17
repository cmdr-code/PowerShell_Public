#setup up http DSC Pull server

cls

#Use DSC configuration
psedit s:\new-dscpullserverconfig.ps1

#verify
get-windowsfeature -computer chi-web02 | where installed

#error is ok
start http://chi-web02:8080

#zip resources
psedit s:\new-ziparchive.ps1
#load it
. s:\new-ziparchive.ps1

#copy zipped custom resources to share and checksum them

Get-DscResource | 
where path -match "^c:\\Program Files\\WindowsPowerShell\\Modules" |
Select -expandProperty Module -Unique | 
foreach {
 $out = "{0}_{1}.zip" -f $_.Name,$_.Version
 $zip = Join-Path -path "\\chi-web02\c$\Program Files\WindowsPowerShell\DSCService\Modules" -ChildPath $out
 New-ZipArchive -path $_.ModuleBase -OutputPath $zip -Passthru
 #give file a chance to close
 start-sleep -Seconds 1 
 If (Test-Path $zip) {
    Try {
        New-DSCCheckSum -ConfigurationPath $zip -ErrorAction Stop
    }
    Catch {
        Write-Warning "Failed to create checksum for $zip"
    }
 }
 else {
    Write-Warning "Failed to find $zip"
 }
 
}

dir "\\chi-web02\c$\Program Files\WindowsPowerShell\DSCService\Modules" | group Extension

# invoke-item "\\chi-web02\c$\program files\windowspowershell\modules\"

#create and copy configurations using the pull server
psedit s:\demopullconfig2.ps1

#dynamically build config data
psedit s:\Get-MachineCert.ps1
#load it
. s:\Get-MachineCert.ps1

#using a credential
$Cred = get-credential globomantics\administrator

#nodes to be configured
$nodes = @("chi-test01","chi-core01")

cls
foreach ($node in $nodes) {
 $allnodes=@()
 $cert = Export-MachineCert -computername $node -path c:\certs
 $interfaceAlias = Get-NetAdapter -CimSession $node | 
 select -expand Name

 $NodeHash = @{
    Nodename = $node
    CertificateFile = $cert.path
    Thumbprint = $cert.thumbprint
    Interface = $InterfaceAlias
 }

 $allnodes+=$nodehash

 #create config data 
 $ConfigData=@{AllNodes=$AllNodes}

 #create a guid for the node
 $guid= [guid]::NewGuid().guid 

 #create the MOF
$ConfigHash = @{
 guid = $guid
 credential = $cred
 OutputPath = "c:\dsc\DemoPull2"
 ConfigurationData = $configdata
 verbose = $True
}

 DemoPull2 @confighash

 #configure LCM for each node
$lcmHash = @{
 ComputerName = $node path = "c:\dsc\DemoPull2" Verbose = $True}

Set-DscLocalConfigurationManager @lcmHash

 #copy MOF with GUID to pull server
 $src = Join-path -path "C:\DSC\demopull2" -childpath "$node.mof"
 $dscPath = "\\chi-web02\c`$\program files\windowspowershell\dscservice\configuration"
 $dst = Join-path -path $dscpath -childpath "$guid.mof"

 Copy-Item -path $src -Destination $dst -PassThru
 #checksum the MOF
 New-DSCChecksum $dst 

} #foreach node

#verify
Get-DscLocalConfigurationManager -CimSession $nodes

dir $dscpath\*.mof*

#force the configuration
psedit s:\invoke-pull.ps1 
#load it
. S:\Invoke-Pull.ps1

cls
invoke-pull -computername $nodes -verbose

Get-DscConfiguration -CimSession chi-core01 -verbose
Get-DscConfiguration -CimSession chi-test01 -verbose

Test-DscConfiguration -CimSession $nodes 

#demo compliance server after a break to give nodes 
#chances to update

