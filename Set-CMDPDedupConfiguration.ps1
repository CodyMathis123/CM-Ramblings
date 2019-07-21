#region Deduplication configuration detection
#region variables
$Logging = $true
$LogPath = "$env:SystemDrive\temp"
$LogFile = 'Set-CMDPDedupConfiguration.log'
$MinimumFileAgeDays = 1
#endregion variables

try {
    $Dedup = Get-DedupVolume -ErrorAction Ignore
}
catch {
}
$DriveCompliance = @{ }

#region functions
Function Write-CMLogEntry {
    <#
    .DESCRIPTION
        Write CMTrace friendly log files with options for log rotation
    .EXAMPLE
        $Bias = Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias
        $FileName = "myscript_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + ".log"
        Write-CMLogEntry -Value "Writing text to log file" -Severity 1 -Component "Some component name" -FileName $FileName -Folder "C:\Windows\temp" -Bias $Bias -Enable -MaxLogFileSize 1MB -MaxNumOfRotatedLogs 3
    #>
    param (
        [parameter(Mandatory = $true, HelpMessage = 'Value added to the log file.')]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $false, HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('1', '2', '3')]
        [string]$Severity = 1,
        [parameter(Mandatory = $false, HelpMessage = "Stage that the log entry is occuring in, log refers to as 'component'.")]
        [ValidateNotNullOrEmpty()]
        [string]$Component,
        [parameter(Mandatory = $true, HelpMessage = 'Name of the log file that the entry will written to.')]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,
        [parameter(Mandatory = $true, HelpMessage = 'Path to the folder where the log will be stored.')]
        [ValidateNotNullOrEmpty()]
        [string]$Folder,
        [parameter(Mandatory = $false, HelpMessage = 'Set timezone Bias to ensure timestamps are accurate.')]
        [ValidateNotNullOrEmpty()]
        [int32]$Bias,
        [parameter(Mandatory = $false, HelpMessage = 'Maximum size of log file before it rolls over. Set to 0 to disable log rotation.')]
        [ValidateNotNullOrEmpty()]
        [int32]$MaxLogFileSize = 5MB,
        [parameter(Mandatory = $false, HelpMessage = 'Maximum number of rotated log files to keep. Set to 0 for unlimited rotated log files.')]
        [ValidateNotNullOrEmpty()]
        [int32]$MaxNumOfRotatedLogs = 0,
        [parameter(Mandatory = $false, HelpMessage = 'A switch that enables the use of this function.')]
        [ValidateNotNullOrEmpty()]
        [switch]$Enable
    )
    If ($Enable) {
        # Determine log file location
        $LogFilePath = Join-Path -Path $Folder -ChildPath $FileName

        If ((([System.IO.FileInfo]$LogFilePath).Exists) -And ($MaxLogFileSize -ne 0)) {

            # Get log size in bytes
            $LogFileSize = [System.IO.FileInfo]$LogFilePath | Select-Object -ExpandProperty Length

            If ($LogFileSize -ge $MaxLogFileSize) {

                # Get log file name without extension
                $LogFileNameWithoutExt = $FileName -replace ([System.IO.Path]::GetExtension($FileName))

                # Get already rolled over logs
                $AllLogs = Get-ChildItem -Path $Folder -Name "$($LogFileNameWithoutExt)_*" -File

                # Sort them numerically (so the oldest is first in the list)
                $AllLogs = $AllLogs | Sort-Object -Descending { $_ -replace '_\d+\.lo_$' }, { [Int]($_ -replace '^.+\d_|\.lo_$') } -ErrorAction Ignore
            
                ForEach ($Log in $AllLogs) {
                    # Get log number
                    $LogFileNumber = [int32][Regex]::Matches($Log, "_([0-9]+)\.lo_$").Groups[1].Value
                    switch (($LogFileNumber -eq $MaxNumOfRotatedLogs) -And ($MaxNumOfRotatedLogs -ne 0)) {
                        $true {
                            # Delete log if it breaches $MaxNumOfRotatedLogs parameter value
                            [System.IO.File]::Delete("$($Folder)\$($Log)")
                        }
                        $false {
                            # Rename log to +1
                            $NewFileName = $Log -replace "_([0-9]+)\.lo_$","_$($LogFileNumber+1).lo_"
                            [System.IO.File]::Copy("$($Folder)\$($Log)", "$($Folder)\$($NewFileName)", $true)
                        }
                    }
                }

                # Copy main log to _1.lo_
                [System.IO.File]::Copy($LogFilePath, "$($Folder)\$($LogFileNameWithoutExt)_1.lo_", $true)

                # Blank the main log
                $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, $false)
                $StreamWriter.Close()
            }
        }

        # Construct time stamp for log entry
        switch -regex ($Bias) {
            '-' {
                $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), $Bias)
            }
            Default {
                $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), '+', $Bias)
            }
        }
        # Construct date for log entry
        $Date = (Get-Date -Format 'MM-dd-yyyy')
    
        # Construct context for log entry
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    
        # Construct final log entry
        $LogText = [string]::Format('<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">', $Value, $Time, $Date, $Component, $Context, $Severity, $PID)
    
        # Add value to log file
        try {
            $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, 'Append')
            $StreamWriter.WriteLine($LogText)
            $StreamWriter.Close()
        }
        catch [System.Exception] {
            Write-Warning -Message "Unable to append log entry to $FileName file. Error message: $($_.Exception.Message)"
        }
    }
}
#endregion functions

#region set function defaults
$Bias = Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias
$PSDefaultParameterValues["Write-CMLogEntry:Bias"] = $Bias
$PSDefaultParameterValues["Write-CMLogEntry:Component"] = 'Detection'
$PSDefaultParameterValues["Write-CMLogEntry:FileName"] = $LogFile
$PSDefaultParameterValues["Write-CMLogEntry:Folder"] = $LogPath
$PSDefaultParameterValues["Write-CMLogEntry:MaxLogFileSize"] = 1MB
$PSDefaultParameterValues["Write-CMLogEntry:MaxNumOfRotatedLogs"] = 2
$PSDefaultParameterValues["Write-CMLogEntry:Enable"] = $Logging
#endregion set function defaults

#region check deduplicatoin configuration
Write-CMLogEntry -Value $('-' * 50)

if ($null -ne $Dedup) {
    Write-CMLogEntry -Value "At least one drive has deduplication enabled"
    $Drives = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter }
    foreach ($D in $Drives) {
        $Include = @{ }
        $DrivePath = [string]::Format("{0}:", $D.DriveLetter)
        $No_SMS = Join-Path -Path $DrivePath -ChildPath 'No_SMS_On_Drive.sms'
        $No_SMS_Exists = Test-Path -Path $No_SMS
        Write-CMLogEntry -Value "Identified Volume $DrivePath"
        switch ($No_SMS_Exists) {
            $false {
                Write-CMLogEntry -Value "Found that the 'No_SMS_On_Drive.sms' does not exist on $DrivePath - will check for DP folders."
                $SMS_PackageShareFolder = [string]::Format('SMSPKG{0}$', $D.DriveLetter)
                $SMS_PackageShareFolderPath = Get-ChildItem -Path $DrivePath -Filter $SMS_PackageShareFolder
                if ($null -ne $SMS_PackageShareFolderPath) {
                    Write-CMLogEntry -Value "Adding $($SMS_PackageShareFolderPath.FullName) to inclusion list for $DrivePath"
                    $Include[$SMS_PackageShareFolderPath.FullName] = $true
                }
                $SCCMContentLibFolderPath = Get-ChildItem -Path $DrivePath -Filter 'SCCMContentLib'
                if ($null -ne $SCCMContentLibFolderPath) {
                    Write-CMLogEntry -Value "Adding $($SCCMContentLibFolderPath.FullName) to inclusion list for $DrivePath"
                    $Include[$SCCMContentLibFolderPath.FullName] = $true
                }
                if ($Include -ne @{ }) {
                    Write-CMLogEntry -Value "Found that DP/Content Library folders [$($Include.Keys -join '; ')] do exist - will process $DrivePath for deduplication"
                    $AllFolders = Get-ChildItem -Path $DrivePath -Directory
                    $Exclude = $AllFolders.FullName | Where-Object { $_ -notin $Include.Keys }
                    $Excludes = $Exclude -replace $DrivePath
                    if ($Dedup.Volume -contains $DrivePath) {
                        Write-CMLogEntry -Value "Verified that deduplication is enabled for $DrivePath"
                        Write-CMLogEntry -Value "Validating deduplication configuration for $DrivePath"
                        $Settings = Get-DedupVolume -Volume $DrivePath
                        try {
                            $Dedup_ExcludeSetting = Compare-Object -ReferenceObject $Excludes -DifferenceObject $Settings.ExcludeFolder
                        }
                        catch {
                            $NoExclusions = $true
                        }        
                        if ($null -eq $Dedup_ExcludeSetting -and -not $NoExclusions) {
                            Write-CMLogEntry -Value "Deduplication folder exclusions are valid for $DrivePath"
                            $DriveCompliance['Exclusions'] = $true
                        }
                        else {
                            Write-CMLogEntry -Value "Failed to validate deduplication folder exclusion for $DrivePath" -Severity 3
                            foreach ($Exclusion in $Dedup_ExcludeSetting) {
                                if ($Exclusion.SideIndicator -eq '<=') {
                                    Write-CMLogEntry -Value "Exclusion list for $DrivePath is missing $($Exclusion.InputObject) which should be added" -Severity 3
                                }
                                elseif ($Exclusion.SideIndicator -eq '=>') {
                                    Write-CMLogEntry -Value "Exclusion list for $DrivePath has an additional exclusion of $($Exclusion.InputObject) which should be removed" -Severity 3
                                }
                            }
                            $DriveCompliance['Exclusions'] = $false
                        }
                        if ($Settings.MinimumFileAgeDays -eq $MinimumFileAgeDays) {
                            Write-CMLogEntry -Value "Deduplication [MinimumFileAgeDays=$MinimumFileAgeDays] configuration is valid for $DrivePath"
                            $DriveCompliance['MinimumFileAgeDays'] = $true
                        }
                        else {
                            Write-CMLogEntry -Value "Failed to validate MinimumFileAgeDays configuration for $DrivePath" -Severity 3
                            $DriveCompliance['MinimumFileAgeDays'] = $false
                        }
                    }
                    else {
                        Write-CMLogEntry -Value "Failed to verify that deduplication is enabled for $DrivePath" -Severity 3
                        $DriveCompliance['Deduplication'] = $false
                    }
                }
                else {
                    Write-CMLogEntry -Value "Found that no Distribution Point or Content Library folders exists on $DrivePath - will NOT process for deduplication." -Severity 2
                }
            }
            $true {
                Write-CMLogEntry -Value "Found that the 'No_SMS_On_Drive.sms' exists on $DrivePath - will NOT process for deduplication." -Severity 2
            }
        }
    }
    $Compliance = [bool]($DriveCompliance.Values -notcontains $false)
    Write-CMLogEntry -Value "Finished deduplication configuration validation [Compliance=$Compliance]"
    Write-CMLogEntry -Value $('-' * 50)
    return $Compliance
}
else {
    Write-CMLogEntry -Value "No drives found to have deduplication enabled" -Severity 3
    Write-CMLogEntry -Value $('-' * 50)
    return $false
}
#endregion check deduplicatoin configuration
#endregion Deduplication configuration detection

#region Deduplication configuration remediation
#region variables
$Logging = $true
$LogPath = "$env:SystemDrive\temp"
$LogFile = 'Set-CMDPDedupConfiguration.log'
$MinimumFileAgeDays = 1
#endregion variables

$Drives = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter}

#region functions
Function Write-CMLogEntry {
    <#
    .DESCRIPTION
        Write CMTrace friendly log files with options for log rotation
    .EXAMPLE
        $Bias = Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias
        $FileName = "myscript_" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + ".log"
        Write-CMLogEntry -Value "Writing text to log file" -Severity 1 -Component "Some component name" -FileName $FileName -Folder "C:\Windows\temp" -Bias $Bias -Enable -MaxLogFileSize 1MB -MaxNumOfRotatedLogs 3
    #>
    param (
        [parameter(Mandatory = $true, HelpMessage = 'Value added to the log file.')]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $false, HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('1', '2', '3')]
        [string]$Severity = 1,
        [parameter(Mandatory = $false, HelpMessage = "Stage that the log entry is occuring in, log refers to as 'component'.")]
        [ValidateNotNullOrEmpty()]
        [string]$Component,
        [parameter(Mandatory = $true, HelpMessage = 'Name of the log file that the entry will written to.')]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,
        [parameter(Mandatory = $true, HelpMessage = 'Path to the folder where the log will be stored.')]
        [ValidateNotNullOrEmpty()]
        [string]$Folder,
        [parameter(Mandatory = $false, HelpMessage = 'Set timezone Bias to ensure timestamps are accurate.')]
        [ValidateNotNullOrEmpty()]
        [int32]$Bias,
        [parameter(Mandatory = $false, HelpMessage = 'Maximum size of log file before it rolls over. Set to 0 to disable log rotation.')]
        [ValidateNotNullOrEmpty()]
        [int32]$MaxLogFileSize = 5MB,
        [parameter(Mandatory = $false, HelpMessage = 'Maximum number of rotated log files to keep. Set to 0 for unlimited rotated log files.')]
        [ValidateNotNullOrEmpty()]
        [int32]$MaxNumOfRotatedLogs = 0,
        [parameter(Mandatory = $false, HelpMessage = 'A switch that enables the use of this function.')]
        [ValidateNotNullOrEmpty()]
        [switch]$Enable
    )
    If ($Enable) {
        # Determine log file location
        $LogFilePath = Join-Path -Path $Folder -ChildPath $FileName

        If ((([System.IO.FileInfo]$LogFilePath).Exists) -And ($MaxLogFileSize -ne 0)) {

            # Get log size in bytes
            $LogFileSize = [System.IO.FileInfo]$LogFilePath | Select-Object -ExpandProperty Length

            If ($LogFileSize -ge $MaxLogFileSize) {

                # Get log file name without extension
                $LogFileNameWithoutExt = $FileName -replace ([System.IO.Path]::GetExtension($FileName))

                # Get already rolled over logs
                $AllLogs = Get-ChildItem -Path $Folder -Name "$($LogFileNameWithoutExt)_*" -File

                # Sort them numerically (so the oldest is first in the list)
                $AllLogs = $AllLogs | Sort-Object -Descending { $_ -replace '_\d+\.lo_$' }, { [Int]($_ -replace '^.+\d_|\.lo_$') } -ErrorAction Ignore
            
                ForEach ($Log in $AllLogs) {
                    # Get log number
                    $LogFileNumber = [int32][Regex]::Matches($Log, "_([0-9]+)\.lo_$").Groups[1].Value
                    switch (($LogFileNumber -eq $MaxNumOfRotatedLogs) -And ($MaxNumOfRotatedLogs -ne 0)) {
                        $true {
                            # Delete log if it breaches $MaxNumOfRotatedLogs parameter value
                            [System.IO.File]::Delete("$($Folder)\$($Log)")
                        }
                        $false {
                            # Rename log to +1
                            $NewFileName = $Log -replace "_([0-9]+)\.lo_$","_$($LogFileNumber+1).lo_"
                            [System.IO.File]::Copy("$($Folder)\$($Log)", "$($Folder)\$($NewFileName)", $true)
                        }
                    }
                }

                # Copy main log to _1.lo_
                [System.IO.File]::Copy($LogFilePath, "$($Folder)\$($LogFileNameWithoutExt)_1.lo_", $true)

                # Blank the main log
                $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, $false)
                $StreamWriter.Close()
            }
        }

        # Construct time stamp for log entry
        switch -regex ($Bias) {
            '-' {
                $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), $Bias)
            }
            Default {
                $Time = [string]::Concat($(Get-Date -Format 'HH:mm:ss.fff'), '+', $Bias)
            }
        }
        # Construct date for log entry
        $Date = (Get-Date -Format 'MM-dd-yyyy')
    
        # Construct context for log entry
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    
        # Construct final log entry
        $LogText = [string]::Format('<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">', $Value, $Time, $Date, $Component, $Context, $Severity, $PID)
    
        # Add value to log file
        try {
            $StreamWriter = [System.IO.StreamWriter]::new($LogFilePath, 'Append')
            $StreamWriter.WriteLine($LogText)
            $StreamWriter.Close()
        }
        catch [System.Exception] {
            Write-Warning -Message "Unable to append log entry to $FileName file. Error message: $($_.Exception.Message)"
        }
    }
}
#endregion functions

#region set function defaults
$Bias = Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias
$PSDefaultParameterValues["Write-CMLogEntry:Bias"] = $Bias
$PSDefaultParameterValues["Write-CMLogEntry:Component"] = 'Remediation'
$PSDefaultParameterValues["Write-CMLogEntry:FileName"] = $LogFile
$PSDefaultParameterValues["Write-CMLogEntry:Folder"] = $LogPath
$PSDefaultParameterValues["Write-CMLogEntry:MaxLogFileSize"] = 1MB
$PSDefaultParameterValues["Write-CMLogEntry:MaxNumOfRotatedLogs"] = 2
$PSDefaultParameterValues["Write-CMLogEntry:Enable"] = $Logging
#endregion set function defaults

#region configure deduplication
Write-CMLogEntry -Value $('-' * 50)

foreach ($D in $Drives) {    
    $Include = @{ }
    $DrivePath = [string]::Format("{0}:", $D.DriveLetter)
    $No_SMS = Join-Path -Path $DrivePath -ChildPath 'No_SMS_On_Drive.sms'
    $No_SMS_Exists = Test-Path -Path $No_SMS
    Write-CMLogEntry -Value "Identified Volume $DrivePath"
    switch ($No_SMS_Exists) {
        $false {
            Write-CMLogEntry -Value "Found that the 'No_SMS_On_Drive.sms' does not exist on $DrivePath - will check for DP folders."

            $SMS_PackageShareFolder = [string]::Format('SMSPKG{0}$', $D.DriveLetter)
            $SMS_PackageShareFolderPath = Get-ChildItem -Path $DrivePath -Filter $SMS_PackageShareFolder
            if ($null -ne $SMS_PackageShareFolderPath) {
                Write-CMLogEntry -Value "Adding $($SMS_PackageShareFolderPath.FullName) to inclusion list for $DrivePath"
                $Include[$SMS_PackageShareFolderPath.FullName] = $true
            }
            $SCCMContentLibFolderPath = Get-ChildItem -Path $DrivePath -Filter 'SCCMContentLib'
            if ($null -ne $SCCMContentLibFolderPath) {
                Write-CMLogEntry -Value "Adding $($SCCMContentLibFolderPath.FullName) to inclusion list for $DrivePath"
                $Include[$SCCMContentLibFolderPath.FullName] = $true
            }
            if ($Include -ne @{ }) {
                Write-CMLogEntry -Value "Found that DP/Content Library folders [$($Include.Keys -join '; ')] do exist - will process $DrivePath for deduplication"

                $DedupVolume = $D | Get-DedupVolume
                if ($null -eq $DedupVolume) {
                    Write-CMLogEntry -Value "Deduplication is not enabled on $DrivePath - attempting to enable" -Severity 2
                    $D | Enable-DedupVolume -UsageType Default -ErrorAction Stop
                    New-CMNLogEntry -enry "Deduplication enabled on $DrivePath succesfully" -Severity 2
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
                            Write-CMLogEntry -Value "Exclusion list for $DrivePath is missing $($Exclusion.InputObject) which will be added" -Severity 2
                        }
                        elseif ($Exclusion.SideIndicator -eq '=>') {
                            Write-CMLogEntry -Value "Exclusion list for $DrivePath has an additional exclusion of $($Exclusion.InputObject) which will be removed" -Severity 2
                        }
                    }
                    $DedupVolume | Set-DedupVolume -ExcludeFolder $Excludes
                }
                if ($DedupVolume.MinimumFileAgeDays -ne $MinimumFileAgeDays) {
                    Write-CMLogEntry -Value "Deduplication MinimumFileAgeDays configuration is invalid for $DrivePath and will be configured" -Severity 2
                    $DedupVolume | Set-DedupVolume  -MinimumFileAgeDays $MinimumFileAgeDays -ErrorAction Stop
                    Write-CMLogEntry -Value "Deduplication MinimumFileAgeDays configuration set to $MinimumFileAgeDays for $DrivePath" -Severity 2
                }
            }
            else {
                Write-CMLogEntry -Value "Found that no Distribution Point or Content Library folders exists on $DrivePath - will NOT process for deduplication." -Severity 2
            }
        }
        $true {
            Write-CMLogEntry -Value "Found that the 'No_SMS_On_Drive.sms' exists on $DrivePath - will NOT process for deduplication." -Severity 2
        }
    }
}
Write-CMLogEntry -Value $('-' * 50)
#endregion configure deduplication
#endregion Deduplication configuration remediation
