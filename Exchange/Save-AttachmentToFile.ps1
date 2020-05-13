## Tested on Exchange 2019 CU5

## USER PROMPT PSW    ## 
$cred = Get-Credential 

$ExchAPIURL = "https://exchange-fqdn/api/v2.0/me/messages"
$ExchAPIURL = "https://exchange-fqdn/api/v2.0/me/MailFolders/Inbox/messages"

# Filter Data
$DayMinusOne = $(Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
$Subject = 'Subject'

# Filter Query
$FilterSubject = '?$search="subject:' + $Subject + '"'
$FilterDate = '$"filter=ReceivedDateTime+ge+{' + $DayMinusOne + '}'
$FilterAttachments = '$"filter=HasAttachments:true"'

## Get all messages that have attachments where received date is greater than $date  
$messageQuery = "$ExchAPIURL$FilterSubject&$FilterAttachments&$FilterDate"

$messages = Invoke-RestMethod $messageQuery -Credential $cred 

$messageid = $messages.value.id

# get attachments and save to file system 
$query = $url + '/' + $messageid[0] + "/attachments" 
$attachments = Invoke-RestMethod $query -Credential $cred 

# in case of multiple attachments in email 
foreach ($attachment in $attachments.value) 
{ 
    $attachment.Name 
    $path = "c:\Temp\" + $attachment.Name 
    
    $Content = [System.Convert]::FromBase64String($attachment.ContentBytes) 
    Set-Content -Path $path -Value $Content -Encoding Byte 
}

# Move the message to deleted items.
$MoveQuery = "/$MessageId/move"
$body="{""DestinationId"":""DeletedItems""}"

$messageQuery = "$ExchAPIURL$MoveQuery"
$messages = Invoke-RestMethod $messageQuery -Method POST -Body $Body -ContentType "application/json" -Credential $cred
