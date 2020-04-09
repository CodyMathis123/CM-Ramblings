#region IIS Log Cleanup
#region Variables
$Remediate = $false
$LogCleanupDays = 7
#endregion Variables

#region Action
Import-Module WebAdministration
$AllWebsites = Get-Website

#region Loop through all websites, identify log file path, and check for old files. Removing according to remediation preference
foreach ($WebSite in $AllWebsites) {
    $LogFilePath = [string]::Format("{0}\w3svc{1}", $WebSite.LogFile.Directory, $WebSite.ID).Replace('%SystemDrive%', $env:SystemDrive)
    if (Test-Path -Path $LogFilePath) {
        $AllLogFiles = Get-ChildItem -Path $LogFilePath -Filter "*.log" -Recurse
        if ($OldLogs = $AllLogFiles.Where( { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogCleanupDays) })) {
            switch ($Remediate) {
                $true {
                    $OldLogs | Remove-Item -Force
                }
                $false {
                    return $false
                }
            }
        }
    }
}
#endregion Loop through all websites, identify log file path, and check for old files. Removing according to remediation preference

#region If we make it through the loop with no $false returns, then we are compliant. Return $True
return $true
#endregion If we make it through the loop with no $false returns, then we are compliant. Return $True
#endregion Action
#endregion IIS LogCleanup