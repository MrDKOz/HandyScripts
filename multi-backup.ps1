$paramSources = "C:\Test\dir1\, C:\Test\dir2"
$paramDestinations = "C:\Test\dir3\, C:\Test\dir4"
$paramAppDirName = ''
$paramPreDirName =''
$paramPostDirName = "Post1, Post2"
$paramNumberToKeep = 5

$currentDate = Get-Date
$formattedDate = $currentDate.ToString("yyyy-MM-dd_HH-mm-ss")

$srcDirs = $paramSources.Split(',')
$dstDirs = $paramDestinations.Split(',')
$appNames = If ([string]::IsNullOrEmpty($paramAppDirName)) { @() } Else { $paramAppDirName.Split(',') }
$dirPreFixes = If ([string]::IsNullOrEmpty($paramPreDirName)) { @() } Else { $paramPreDirName.Split(',') }
$dirPstFixes = If ([string]::IsNullOrEmpty($paramPostDirName)) { @() } Else { $paramPostDirName.Split(',') }

Write-Host($srcDirs);

If ($srcDirs.Count -eq $dstDirs.Count) {
    For ($i = 0; $i -le $srcDirs.Count - 1; $i++) {
        # Get variables for this loop
        $currentSrcDir = $srcDirs[$i].Trim()
        $currentDstDir = $dstDirs[$i].Trim()

        $currentAppName = If($appNames) { $appNames[$i].Trim() } Else { "" }

        $currentPrefix = If($dirPreFixes) { $dirPreFixes[$i].Trim() } Else { "" }
        $currentPostfix = If($dirPstFixes) { $dirPstFixes[$i].Trim() } Else { "" }

        $prefixSeperator = If ([string]::IsNullOrEmpty($currentPrefix)) { "" } Else { "_" }
        $postfixSeperator = If ([string]::IsNullOrEmpty($currentPostfix)) { "" } Else { "_" }

        $postFix = $currentPrefix + $prefixSeperator + $formattedDate + $postfixSeperator + $currentPostfix
        $backupSrc = $currentSrcDir + $currentAppName
        $backupDst = Join-Path $currentDstDir $postFix

        # Test the path, perform the backup, then cleanup
        If (Test-Path $backupSrc) {
            # Perform backup
            Write-Host('FROM: ' + $backupSrc + ' TO: ' + $backupDst)
            Copy-Item $backupSrc -Destination $backupDst -Recurse

            # Cleanup old backups
            Write-Host('Checking for previous backups to remove...')
            $backupsToRemove = Get-ChildItem $currentDstDir -Directory | Select-Object Name, CreationTime, FullName | Sort-Object CreationTime

            If ($backupsToRemove.Count -gt $paramNumberToKeep) {
                Write-Host('Removing ' + $backupsToRemove.Count + ' backups')

                for ($b=0; $b -lt ($backupsToRemove.Count -$paramNumberToKeep); $b++) {
                    Remove-Item $backupsToRemove[$b].FullName -Recurse -Force -EA SilentlyContinue -Verbose
                }
            } else {
                Write-Host($backupsToRemove.Count.ToString() + ' previous backup(s) found, number to keep is ' + $paramNumberToKeep + ', nothing to remove')
            }
        } else {
            Write-Host($backupSrc + ' is not a valid directory')
        }
    }
} Else {
    Write-Host('The number of source directories, and destination directories do not match')
    exit -1
}