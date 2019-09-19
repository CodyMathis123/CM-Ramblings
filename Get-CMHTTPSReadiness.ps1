#region functions
Function Get-CMLogFile {
    <#
    .SYNOPSIS
        Parse Configuration Manager format logs
    .DESCRIPTION
        This function is used to take Configuration Manager formatted logs and turn them into a PSCustomObject so that it can be
        searched and manipulated easily with PowerShell
    .PARAMETER LogFilePath
        Path to the log file(s) you would like to parse.
    .EXAMPLE
        PS C:\> Get-CMLogFile -LogFilePath 'c:\windows\ccm\logs\ccmexec.log'
        Returns the CCMExec.log as a PSCustomObject
    .EXAMPLE
        PS C:\> Get-CMLogFile -LogFilePath 'c:\windows\ccm\logs\AppEnforce.log', 'c:\windows\ccm\logs\AppDiscovery.log'
        Returns the AppEnforce.log and the AppDiscovery.log as a PSCustomObject
    .OUTPUTS
        [pscustomobject]
    .NOTES
        I've done my best to test this against various SCCM log files. They are all generally 'formatted' the same, but do have some
        variance. I had to also balance speed and parsing. In particular, date parsing was problematic around MM vs M and dd vs d.
        The method of splitting the $LogLineArray on multiple fields also takes slightly longer than some alternatives.

        With that said, it can still parse a typical SCCM log VERY quickly. Smaller logs are parsed in milliseconds in my testing.
        Rolled over logs that are 5mb can be parsed in a couple seconds or less.

            FileName: Get-CMLogFile.ps1
            Author:   Cody Mathis
            Contact:  @CodyMathis123
            Created:  9/19/2019
            Updated:  9/19/2019
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$LogFilePath
    )
    begin {
        try {
            Add-Type -TypeDefinition @"
            public enum Severity
            {
                None,
                Informational,
                Warning,
                Error
            }
"@ -ErrorAction Stop
        }
        catch {
            Write-Debug "Severity enum already exists"
        }
    }
    process {
        $ReturnLog = Foreach ($LogFile in $LogFilePath) {
            #region ingest log file with StreamReader. Quick, and prevents locks
            $File = [System.IO.File]::Open($LogFile, 'Open', 'Read', 'ReadWrite')
            $StreamReader = New-Object System.IO.StreamReader($File)
            [string]$LogFileRaw = $StreamReader.ReadToEnd()
            $StreamReader.Close()
            $File.Close()
            #endregion ingest log file with StreamReader. Quick, and prevents locks

            #region perform a regex match to determine the 'type' of log we are working with and parse appropriately
            switch ($true) {
                #region parse a 'typical' SCCM log
                (([Regex]::Match($LogFileRaw, "LOG\[(.*?)\]LOG(.*?)time(.*?)date")).Success) {
                    # split on what we know is a line beginning
                    switch -regex ($LogFileRaw -split "<!\[LOG\[") {
                        '^\s*$' {
                            # ignore empty lines
                            continue
                        }
                        default {
                            <#
                                split Log line into an array on what we know is the end of the message section
                                first item contains the message which can be parsed
                                second item contains all the information about the message/line (ie. type, component, datetime, thread) which can be parsed
                            #>
                            $LogLineArray = $PSItem -split "]LOG]!><"

                            # Strip the log message out of our first array index
                            $Message = $LogLineArray[0].Trim()

                            # Split LogLineArray into a a sub array based on double quotes to pull log line information
                            $LogLineSubArray = $LogLineArray[1] -split 'time="' -split '" date="' -split '" component="' -split '" context="' -split '" type="' -split '" thread="' -split '" file="'

                            $LogLine = @{ }
                            # Rebuild the LogLine into a hash table
                            $LogLine.Message = $Message
                            $LogLine.Type = [Severity]$LogLineSubArray[5]
                            $LogLine.Component = $LogLineSubArray[3]
                            $LogLine.Thread = $LogLineSubArray[6]

                            #region determine timestamp for log line
                            $DateString = $LogLineSubArray[2]
                            $DateStringArray = $DateString -split "-"

                            $MonthParser = switch ($DateStringArray[0].Length) {
                                1 {
                                    'M'
                                }
                                2 {
                                    'MM'
                                }
                            }
                            $DayParser = switch ($DateStringArray[1].Length) {
                                1 {
                                    'd'
                                }
                                2 {
                                    'dd'
                                }
                            }

                            $DateTimeFormat = [string]::Format('{0}-{1}-yyyyHH:mm:ss.fff', $MonthParser, $DayParser)
                            $TimeString = ($LogLineSubArray[1]).Split("+|-")[0].ToString().Substring(0, 12)
                            $DateTimeString = [string]::Format('{0}{1}', $DateString, $TimeString)
                            $LogLine.TimeStamp = [datetime]::ParseExact($DateTimeString, $DateTimeFormat, $null)
                            #region determine timestamp for log line

                            [pscustomobject]$LogLine
                        }
                    }
                }
                #endregion parse a 'typical' SCCM log

                #region parse a 'simple' SCCM log, usually found on site systems
                (([Regex]::Match($LogFileRaw, '\$\$\<(.*?)\>\<thread=')).Success) {
                    switch -regex ($LogFileRaw -split [System.Environment]::NewLine) {
                        '^\s*$' {
                            # ignore empty lines
                            continue
                        }
                        default {
                            <#
                                split Log line into an array
                                first item contains the message which can be parsed
                                second item contains all the information about the message/line (ie. type, component, timestamp, thread) which can be parsed
                            #>
                            $LogLineArray = $PSItem -split '\$\$<'

                            # Strip the log message out of our first array index
                            $Message = $LogLineArray[0]

                            # Split LogLineArray into a a sub array based on double quotes to pull log line information
                            $LogLineSubArray = $LogLineArray[1] -split '><'

                            switch -regex ($Message) {
                                '^\s*$' {
                                    # ignore empty messages
                                    continue
                                }
                                default {
                                    $LogLine = @{ }
                                    # Rebuild the LogLine into a hash table
                                    $LogLine.Message = $Message.Trim()
                                    $LogLine.Type = [Severity]0
                                    $LogLine.Component = $LogLineSubArray[0].Trim()
                                    $LogLine.Thread = ($LogLineSubArray[2] -split " ")[0].Substring(7)

                                    #region determine timestamp for log line
                                    $DateTimeString = $LogLineSubArray[1]
                                    $DateTimeStringArray = $DateTimeString -split " "
                                    $DateString = $DateTimeStringArray[0]
                                    $DateStringArray = $DateString -split "-"

                                    $MonthParser = switch ($DateStringArray[0].Length) {
                                        1 {
                                            'M'
                                        }
                                        2 {
                                            'MM'
                                        }
                                    }
                                    $DayParser = switch ($DateStringArray[1].Length) {
                                        1 {
                                            'd'
                                        }
                                        2 {
                                            'dd'
                                        }
                                    }
                                    $DateTimeFormat = [string]::Format('{0}-{1}-yyyy HH:mm:ss.fff', $MonthParser, $DayParser)
                                    $TimeString = $DateTimeStringArray[1].ToString().Substring(0, 12)
                                    $DateTimeString = [string]::Format('{0} {1}', $DateString, $TimeString)
                                    $LogLine.TimeStamp = [datetime]::ParseExact($DateTimeString, $DateTimeFormat, $null)
                                    #endregion determine timestamp for log line

                                    [pscustomobject]$LogLine
                                }
                            }
                        }
                    }
                }
                #endregion parse a 'simple' SCCM log, usually found on site systems
            }
            #endregion perform a regex match to determine the 'type' of log we are working with and parse appropriately
        }
    }
    end {
        #region return our collected $ReturnLog object. We do a 'select' to maintain property order
        $ReturnLog | Select-Object -Property Message, Component, Type, TimeStamp, Thread
        #endregion return our collected $ReturnLog object. We do a 'select' to maintain property order
    }
}
#endregion functions

$StartedAt = Get-Date
$SMSClient = New-Object -ComObject Microsoft.SMS.Client
$LogPath = Get-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM\Logging\@Global" -Name 'LogDirectory'
$LogFilePath = Join-Path -Path $LogPath.LogDirectory -ChildPath CMHttpsReadiness.log
$CCMDir = Get-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties" -Name "Local SMS Path"
if ($LogPath -and $CCMDir) {
    $CMHTTPSReadiness = Get-Item -Path (Join-Path -Path $CCMDir.'Local SMS Path' -ChildPath 'CMHTTPSReadiness.exe')
    $null = Start-Process -FilePath $CMHTTPSReadiness.FullName -WindowStyle Hidden -Wait
    $Log = Get-CMLogFile -LogFilePath $LogFilePath
    $CompliantLogLine = $Log | Where-Object { $_.Message -match 'Client is ready for HTTPS communication.' -and $_.TimeStamp -ge $StartedAt }
    $null -ne $CompliantLogLine
}
else {
    $false
}
