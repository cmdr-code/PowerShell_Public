function Restart-LockedService {
    <#
        .SYNOPSIS
            This function checks for an event log and will restart the service if it is not seen.
        .DESCRIPTION
            This function will run a check for an event log and restart a corresponding service if the event is not seen
            after x amount of time.   
    #>
    $TwoHours = (Get-Date).AddHours(-2)
    $Event = Get-EventLog -LogName '' -EntryType Warning -Source '' -InstanceId -Before $TwoHours

    $EmailSettings = @{
        To = ''
        from = ''
        SmtpServer = ''
        Subject = 'Service Restart'
        Port = '25'
        BodyAsHTML = $True
    }

    If ($Event.Count -eq 0) {
        Try {
            Get-Service '' | Restart-Service -ErrorAction Stop
            $EmailSettings.Body =  'Events not seen for past two hours.
                                    Service was restarted successfully.'
        } Catch {
            $EmailSettings.Body =  'Events not seen for past two hours.
                                    Service restart attempted, but failed. Manual intervention required.'
        }
        Send-MailMessage @EmailSettings
    }
}
