# Variables
# logDirectory - Where the log should be written to
# directory    - The directory to clean of the files
# daysOld      - The max age a file should be before being deleted

# Configure me
$logDirectory = "E:\Logs\clean-up-$(get-date -f yyyy-MM-dd)$ext"
$directory    = 'E:\Home\Downloads'
$daysOld      = -14

# Leave me alone
$files        = Get-ChildItem -Path $directory -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays($daysOld))}
$fileCount    = $files | Measure-Object

# Action
Start-Transcript -Path $logDirectory # Start the transcript

# Only run if we find some files to remove
if ($fileCount.Count -gt 0)
{
    Write-Host $fileCount.Count 'item(s) found to be removed'

    # Loop each file - handy to see what was removed after the fact
    foreach ($file in $files)
    {
        # Check if the file exists (we may have already removed its parent)
        if([System.IO.File]::Exists($file.FullName))
        {
            # File found, write out the file name and path
            Write-Host '>'$file.FullName

            # Attempt to remove the file, if we can't write out an error
            try
            { 
                Remove-Item -Path $file.FullName -Recurse -Force -Confirm:$false
                Write-Host '>> Removed file successfully'
            }
            catch
            {
                Write-Error 'Failed to remove file'
            }
        }
    }
}
else
{
    Write-Host 'No files to remove'
}

Stop-Transcript