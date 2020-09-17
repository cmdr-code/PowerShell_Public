﻿
cls

$Uri = "http://chi-web02.globomantics.local:9080/PSDSCComplianceServer.svc/Status"

#look at data in a browser
start $uri

#query and convert to JSON
$ContentType = "application/json" 
$Credential = Get-Credential "globomantics\jeff"
 $paramHash = @{
     Uri = $Uri

$response = Invoke-WebRequest @paramHash 

$response.Content

$response.Content | convertfrom-json

$response.Content | convertfrom-json | select -expand value

#use my function
psedit S:\Get-DSCNodeStatus.ps1
#load it
. S:\Get-DSCNodeStatus.ps1

Get-DSCnodestatus
Get-DSCnodestatus -Verbose
get-DSCnodestatus -Computername chi-core01.globomantics.local 
get-DSCnodestatus -Computername chi-core01 
Get-DSCNodeStatus -computername chi-test01 -credential globomantics\administrator