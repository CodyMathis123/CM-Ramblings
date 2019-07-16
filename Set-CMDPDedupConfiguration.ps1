#region Deduplication configuration detection
try {
    $Dedup = Get-DedupVolume -ErrorAction Ignore
}
catch {
}
$DriveCompliance = @{ }

$PSDefaultParameterValues["New-CMNLogEntry:Component"] = 'Detection'
$PSDefaultParameterValues["New-CMNLogEntry:LogFile"] = "$env:SystemDrive\temp\Set-CMDPDedupConfiguration.log"
New-CMNLogEntry -Entry $('-' * 50) -Type 1
if ($null -ne $Dedup) {
    New-CMNLogEntry -entry "At least one drive has deduplication enabled" -Type 1
    $Drives = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }
    foreach ($D in $Drives) {
        $Include = @{ }
        $DrivePath = [string]::Format("{0}:", $D.DriveLetter)
        $No_SMS = Join-Path -Path $DrivePath -ChildPath 'No_SMS_On_Drive.sms'
        $No_SMS_Exists = Test-Path -Path $No_SMS
        New-CMNLogEntry -entry "Identified Volume $DrivePath" -Type 1
        switch ($No_SMS_Exists) {
            $false {
                New-CMNLogEntry -entry "Found that the 'No_SMS_On_Drive.sms' does not exist on $DrivePath - will check for DP folders." -Type 1
                $SMS_PackageShareFolder = [string]::Format('SMSPKG{0}$', $D.DriveLetter)
                $SMS_PackageShareFolderPath = Get-ChildItem -Path $DrivePath -Filter $SMS_PackageShareFolder
                if ($null -ne $SMS_PackageShareFolderPath) {
                    New-CMNLogEntry -Entry "Adding $($SMS_PackageShareFolderPath.FullName) to inclusion list for $DrivePath" -Type 1
                    $Include[$SMS_PackageShareFolderPath.FullName] = $true
                }
                $SCCMContentLibFolderPath = Get-ChildItem -Path $DrivePath -Filter 'SCCMContentLib'
                if ($null -ne $SCCMContentLibFolderPath) {
                    New-CMNLogEntry -Entry "Adding $($SCCMContentLibFolderPath.FullName) to inclusion list for $DrivePath" -Type 1
                    $Include[$SCCMContentLibFolderPath.FullName] = $true
                }
                if ($Include -ne @{ }) {
                    New-CMNLogEntry -entry "Found that DP/Content Library folders [$($Include.Keys -join '; ')] do exist - will process $DrivePath for deduplication" -Type 1
                    $AllFolders = Get-ChildItem -Path $DrivePath -Directory
                    $Exclude = $AllFolders.FullName | Where-Object { $_ -notin $Include.Keys }
                    $Excludes = $Exclude -replace $DrivePath
                    if ($Dedup.Volume -contains $DrivePath) {
                        New-CMNLogEntry -Entry "Verified that deduplication is enabled for $DrivePath" -Type 1
                        New-CMNLogEntry -Entry "Validating deduplication configuration for $DrivePath" -Type 1
                        $Settings = Get-DedupVolume -Volume $DrivePath
                        try {
                            $Dedup_ExcludeSetting = Compare-Object -ReferenceObject $Excludes -DifferenceObject $Settings.ExcludeFolder
                        }
                        catch {
                            $NoExclusions = $true
                        }        
                        if ($null -eq $Dedup_ExcludeSetting -and -not $NoExclusions) {
                            New-CMNLogEntry -Entry "Deduplication folder exclusions are valid for $DrivePath" -Type 1
                            $DriveCompliance['Exclusions'] = $true
                        }
                        else {
                            New-CMNLogEntry -Entry "Failed to validate deduplication folder exclusion for $DrivePath" -Type 3
                            foreach ($Exclusion in $Dedup_ExcludeSetting) {
                                if ($Exclusion.SideIndicator -eq '<=') {
                                    New-CMNLogEntry -Entry "Exclusion list for $DrivePath is missing $($Exclusion.InputObject) which should be added" -Type 3
                                }
                                elseif ($Exclusion.SideIndicator -eq '=>') {
                                    New-CMNLogEntry -Entry "Exclusion list for $DrivePath has an additional exclusion of $($Exclusion.InputObject) which should be removed" -Type 3
                                }
                            }
                            $DriveCompliance['Exclusions'] = $false
                        }
                        if ($Settings.MinimumFileAgeDays -eq 1) {
                            New-CMNLogEntry -Entry "Deduplication [MinimumFileAgeDays=1] configuration is valid for $DrivePath" -Type 1
                            $DriveCompliance['MinimumFileAgeDays'] = $true
                        }
                        else {
                            New-CMNLogEntry -Entry "Failed to validate MinimumFileAgeDays configuration for $DrivePath" -Type 3
                            $DriveCompliance['MinimumFileAgeDays'] = $false
                        }
                    }
                    else {
                        New-CMNLogEntry -Entry "Failed to verify that deduplication is enabled for $DrivePath" -Type 3
                        $DriveCompliance['Deduplication'] = $false
                    }
                }
                else {
                    New-CMNLogEntry -entry "Found that no Distribution Point or Content Library folders exists on $DrivePath - will NOT process for deduplication." -Type 2
                }
            }
            $true {
                New-CMNLogEntry -entry "Found that the 'No_SMS_On_Drive.sms' exists on $DrivePath - will NOT process for deduplication." -Type 2
            }
        }
    }
    $Compliance = [bool]($DriveCompliance.Values -notcontains $false)
    New-CMNLogEntry -Entry "Finished deduplication configuration validation [Compliance=$Compliance]" -Type 1
    New-CMNLogEntry -Entry $('-' * 50) -Type 1
    return $Compliance
}
else {
    New-CMNLogEntry -Entry "No drives found to have deduplication enabled" -Type 3
    New-CMNLogEntry -Entry $('-' * 50) -Type 1
    return $false
}
#endregion Deduplication configuration detection

#region Deduplication configuration remediation
$Drives = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }

$PSDefaultParameterValues["New-CMNLogEntry:Component"] = 'Remediation'
$PSDefaultParameterValues["New-CMNLogEntry:LogFile"] = "$env:SystemDrive\temp\Set-CMDPDedupConfiguration.log"
New-CMNLogEntry -Entry $('-' * 50) -Type 1

foreach ($D in $Drives) {    
    $Include = @{ }
    $DrivePath = [string]::Format("{0}:", $D.DriveLetter)
    $No_SMS = Join-Path -Path $DrivePath -ChildPath 'No_SMS_On_Drive.sms'
    $No_SMS_Exists = Test-Path -Path $No_SMS
    New-CMNLogEntry -entry "Identified Volume $DrivePath" -Type 1
    switch ($No_SMS_Exists) {
        $false {
            New-CMNLogEntry -entry "Found that the 'No_SMS_On_Drive.sms' does not exist on $DrivePath - will check for DP folders." -Type 1

            $SMS_PackageShareFolder = [string]::Format('SMSPKG{0}$', $D.DriveLetter)
            $SMS_PackageShareFolderPath = Get-ChildItem -Path $DrivePath -Filter $SMS_PackageShareFolder
            if ($null -ne $SMS_PackageShareFolderPath) {
                New-CMNLogEntry -Entry "Adding $($SMS_PackageShareFolderPath.FullName) to inclusion list for $DrivePath" -Type 1
                $Include[$SMS_PackageShareFolderPath.FullName] = $true
            }
            $SCCMContentLibFolderPath = Get-ChildItem -Path $DrivePath -Filter 'SCCMContentLib'
            if ($null -ne $SCCMContentLibFolderPath) {
                New-CMNLogEntry -Entry "Adding $($SCCMContentLibFolderPath.FullName) to inclusion list for $DrivePath" -Type 1
                $Include[$SCCMContentLibFolderPath.FullName] = $true
            }
            if ($Include -ne @{ }) {
                New-CMNLogEntry -entry "Found that DP/Content Library folders [$($Include.Keys -join '; ')] do exist - will process $DrivePath for deduplication" -Type 1

                $DedupVolume = $D | Get-DedupVolume
                if ($null -eq $DedupVolume) {
                    New-CMNLogEntry -entry "Deduplication is not enabled on $DrivePath - attempting to enable" -Type 2
                    $D | Enable-DedupVolume -UsageType Default -ErrorAction Stop
                    New-CMNLogEntry -enry "Deduplication enabled on $DrivePath succesfully" -Type 2
                    $DedupVolume = $D | Get-DedupVolume
                }
    
                $AllFolders = Get-ChildItem -Path $DrivePath -Directory
                $Exclude = $AllFolders.FullName | Where-Object { $_ -notin $Include.Keys }
                $Excludes = $Exclude -replace $DrivePath
                try {
                    $Dedup_ExcludeSetting = Compare-Object -ReferenceObject $Excludes -DifferenceObject $DedupVolume.ExcludeFolder
                }
                catch {
                    $NoExclusions = $true
                }
                if ($null -ne $Dedup_ExcludeSetting -or $NoExclusions) {
                    foreach ($Exclusion in $Dedup_ExcludeSetting) {
                        if ($Exclusion.SideIndicator -eq '<=') {
                            New-CMNLogEntry -Entry "Exclusion list for $DrivePath is missing $($Exclusion.InputObject) which will be added" -Type 2
                        }
                        elseif ($Exclusion.SideIndicator -eq '=>') {
                            New-CMNLogEntry -Entry "Exclusion list for $DrivePath has an additional exclusion of $($Exclusion.InputObject) which will be removed" -Type 2
                        }
                    }
                    $DedupVolume | Set-DedupVolume -ExcludeFolder $Excludes
                }
                if ($DedupVolume.MinimumFileAgeDays -ne 1) {
                    New-CMNLogEntry -Entry "Deduplication MinimumFileAgeDays configuration is invalid for $DrivePath and will be configured" -Type 2
                    $DedupVolume | Set-DedupVolume  -MinimumFileAgeDays 1 -ErrorAction Stop
                    New-CMNLogEntry -Entry "Deduplication MinimumFileAgeDays configuration set to 1 for $DrivePath" -Type 2
                }
            }
            else {
                New-CMNLogEntry -entry "Found that no Distribution Point or Content Library folders exists on $DrivePath - will NOT process for deduplication." -Type 2
            }
        }
        $true {
            New-CMNLogEntry -entry "Found that the 'No_SMS_On_Drive.sms' exists on $DrivePath - will NOT process for deduplication." -Type 2
        }
    }
}
New-CMNLogEntry -Entry $('-' * 50) -Type 1
#endregion Deduplication configuration remediation
