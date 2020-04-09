<#
    .SYNOPSIS
        IIS Log Cleanup
    .DESCRIPTION
        This script will cleanup all IIS logs according to the LogCleanupDays parameter, and the Remediate parameter
    .PARAMETER Remediate
        A boolean that determines if the logs will be cleaned up, or if we simply return compliance
    .PARAMETER LogCleanupDays
        A positive integer value of days which you want to retain logs for, defaulting to 7. Anything older than the specified number of days will be removed,
        or used to return compliance if remediation is set to false.
    .EXAMPLE
        C:\PS> Start-IISLogCleanup -Remediate $False -LogCleanupDays 7
            Return a boolean based on whether there are log files older than 7 days
    .EXAMPLE
        C:\PS> Start-IISLogCleanup -Remediate $False -LogCleanupDays 7
            Remove files older than 7 days, and return a boolean of $true if it was succesful
    .OUTPUTS
        [bool]
    .NOTES
        FileName:    Start-IISLogCleanup.ps1
        Author:      Cody Mathis
        Contact:     @CodyMathis123
        Created:     2020-04-09
        Updated:     2020-04-09
#>
param(
    [Parameter(Mandatory = $false)]
    [bool]$Remediate = $false,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$LogCleanupDays = 6
)
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
                    try {
                        $OldLogs | Remove-Item -Force -ErrorAction Stop
                    }
                    catch {
                        return $false
                    }
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