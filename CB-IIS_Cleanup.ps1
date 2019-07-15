#region detection
Import-Module WebAdministration
$IsClean = New-Object -TypeName System.Collections.ArrayList

foreach ($WebSite in $(get-website)) {
    $LogFile = "$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%", $env:SystemDrive)
    if (Test-Path -Path $LogFile) {
        if (Get-ChildItem -Path $LogFile -Filter "*.log" -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7)}) {
            $null = $IsClean.Add($false)
        }
        else {
            $null = $IsClean.Add($true)
        }
    }
}
if ($IsClean.Contains($false)) {
    return $false
}
else {
    return $true
}
#endregion detection

#region remediation
Import-Module WebAdministration

foreach ($WebSite in $(get-website)) {
    $LogFile = "$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%", $env:SystemDrive)
    if (Test-Path -Path $LogFile) {
        Get-ChildItem -Path $LogFile -Filter "*.log" -recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | Remove-Item
    }
}
#endregion remediation
