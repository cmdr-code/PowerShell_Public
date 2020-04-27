function Clean-FolderDirectory {
<#
    .SYNOPSIS
    Cleans a directory. Removes files older than 7 days, empty folders and root folders which have not been used in one month.
#>
[CmdletBinding()]
param(
    [string]$RootDirectory = 'C:\Temp\',
    [string]$Exlusions = 'AddExclusionsHere'
)
    # LongPathsEnabled Registry Entry
    $RegistryPath = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem'
    $LongPathsEnabled = Get-ItemProperty -Path $RegistryPath -Name LongPathsEnabled
    If ($LongPathsEnabled.LongPathsEnabled -eq 0) {
        Set-ItemProperty -Path $RegistryPath -Name LongPathsEnabled -Value 1
        Write-Verbose 'Long File Paths registry entry added. Reboot may be required for full effect.'
    } Else {
        Write-Verbose 'Long File Paths is already enabled.'
    }

    # Folder Paths 
    $ScriptDirectory = 'C:\Temp'
    If ((Test-Path -Path $RootDirectory)) {
        Write-Verbose "$RootDirectory exists"
    } Else {
        Write-Verbose "$RootDirectory does not exist or no access."
        Return
    }

    # Dates
    $SevenDays = (Get-Date).AddDays(-7)
    $OneMonth = (Get-Date).AddMonths(-1)

    # Statistics Variables
    $RemovedFilesCount = 0
    $RemovedFilesSize = 0
    $EmptyDirectoryCount = 0
    $RemovedRootDirectoryCount = 0

    # Remove Files Sitting Directly in the Root Directory
    $RootDirectoryFiles = Get-ChildItem -Path $RootDirectory -File
    If ($RootDirectoryFiles.Count -gt 0) {
        $RootDirectoryFiles | ForEach-Object {
            Write-Verbose "Root directory file removed: $($_.FullName)"
            $RemovedFilesCount++
            $RemovedFilesSize += $_.Length
            Remove-Item $_.FullName
        }
    }

    $SubFolders = Get-ChildItem -Path $RootDirectory -Directory -Exclude $FolderExlusions
    ForEach ($Folder in $SubFolders) {
        # Files older than 7 days
        $FilesForRemoval = Get-ChildItem -Path $Folder.FullName -Recurse -File | Where-Object {$_.CreationTime -lt $SevenDays}
        If ($FilesForRemoval.Count -gt 0) {
            $Folder.FullName | Out-File -FilePath $ScriptDirectory\$(Get-Date -format "yyyy-MM-dd")-Statistics.txt -Append
            $FilesForRemoval | Where-Object { !$_.PSIsContainer } | Group-Object Extension | 
            Select-Object @{n="Extension";e={$_.Name -replace '^\.'}}, @{n="Size (MB)";e={[math]::Round((($_.Group | Measure-Object Length -Sum).Sum / 1MB), 2)}}, Count |
            Out-File -FilePath $ScriptDirectory\$(Get-Date -format "yyyy-MM-dd")-Statistics.txt -Append
        }
        $FilesForRemoval | ForEach-Object {
            Write-Verbose "File older than 7 days removed: $($_.FullName)"
            $RemovedFilesCount++
            $RemovedFilesSize += $_.Length
            Remove-Item $_.FullName
        }

        # Empty Directories
        Do {
            $EmptyDirectories = Get-ChildItem -Path $Folder.FullName -Directory -Recurse | Where-Object {(Get-ChildItem $_.FullName -Force).Count -eq 0} | Select-Object -ExpandProperty FullName
            $EmptyDirectories | ForEach-Object {
                Write-Verbose "An empty directory has been removed: $($_)"
                $EmptyDirectoryCount++
                Remove-Item $_
            }
        } While ($EmptyDirectories.Count -gt 0)

        # Empty Root Directories
        If ($Folder.LastWriteTime -lt $OneMonth) {
            Write-Verbose "Disused root directory has been removed: $($_.FullName)"
            $RemovedRootDirectoryCount++
            Remove-Item -LiteralPath $Folder.FullName
        }
    }
    # Statistics
    $Statistics = @{'Removed Files Count'="$RemovedFilesCount"; 
                    'Removed Items Size (MB)'=[math]::Round(($RemovedFilesSize / 1MB), 2); 
                    'Empty Directory Count'="$EmptyDirectoryCount"; 
                    'Removed Root Directory Count'="$RemovedRootDirectoryCount"
    }
    $Statistics.GetEnumerator() | Sort-Object Name |
    ForEach-Object {"{0} : {1}" -f $_.Name,$_.Value} |
    Add-Content $ScriptDirectory\$(Get-Date -format "yyyy-MM-dd")-Statistics.txt

    $Message = "The deletion report is attached."

    $EmailSettings = @{
        To = ''
        from = ''
        SmtpServer = ''
        Subject = 'Deletion Report'
        Port = ''
        Body = $Message
        BodyAsHTML = $True
        Attachment = "$ScriptDirectory\$(Get-Date -format "yyyy-MM-dd")-Statistics.txt"
    }

    Send-MailMessage @EmailSettings

    # Clean up
    Remove-Item "$ScriptDirectory\$(Get-Date -format "yyyy-MM-dd")-Statistics.txt"
}
