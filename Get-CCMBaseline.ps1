function Get-CCMBaseline {
    [CmdletBinding(SupportsShouldProcess = $true)]
    <#
.SYNOPSIS
    Get SCCM Configuration Baselines on the specified computer(s)
.DESCRIPTION
    This function is used to identify baselines on computers. You can provide an array of computer names, and configuration baseline names which will be 
    search for. If you do not specify a baseline name, then there will be no filter applied. A [PSCustomObject] is returned that
    outlines the findings.
.PARAMETER ComputerName
    Provides computer names to find the configuration baselines on.
.PARAMETER BaselineName
    Provides the configuration baseline names that you wish to search for.
.PARAMETER Credential
    Provides optional credentials to use for the WMI cmdlets.
.EXAMPLE
    C:\PS> Get-CCMBaseline
        Gets all baselines identified in WMI on the local computer.
.EXAMPLE
    C:\PS> Get-CCMBaseline -ComputerName 'Workstation1234','Workstation4321' -BaselineName 'Check Computer Compliance','Double Check Computer Compliance'
        Gets the two baselines on the computers specified. This demonstrates that both ComputerName and BaselineName accept string arrays.
.EXAMPLE
    C:\PS> Get-CCMBaseline -ComputerName 'Workstation1234','Workstation4321'
        Gets all baselines identified in WMI for the computers specified. 
.NOTES
    FileName:    Get-CCMBaseline.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     2019-07-24
    Updated:     2019-10-16

    It is important to note that if a configuration baseline has user settings, the only way to search for it is if the user is logged in, and you run this script
    with those credentials. An example would be if Workstation1234 has user Jim1234 logged in, with a configuration baseline 'FixJimsStuff' that has user settings,

    This command would successfully find FixJimsStuff
    Get-CCMBaseline.ps1 -ComputerName 'Workstation1234' -BaselineName 'FixJimsStuff' -Credential $JimsCreds

    This command would not find the baseline FixJimsStuff
    Get-CCMBaseline.ps1 -ComputerName 'Workstation1234' -BaselineName 'FixJimsStuff'

    You could remotely query for that baseline AS Jim1234, with either a runas on PowerShell, or providing Jim's credentials to the function's -Credential param.
    If you try to query for this same baseline without Jim's credentials being used in some way you will see that the baseline is not found.
#>
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Computer', 'PSComputerName', 'IPAddress', 'ServerName', 'HostName', 'DNSHostName')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]]$BaselineName,
        [parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    begin {
        #region Setup our *-WMI* parameters that will apply to the WMI cmdlets in use based on input parameters
        $getWmiObjectSplat = @{
            Namespace   = 'root\ccm\dcm'
            ErrorAction = 'Stop'
        }
        switch ($PSBoundParameters.ContainsKey('Credential')) {
            $true {
                $getWmiObjectSplat.Add('Credential', $Credential)
            }
        }
        #endregion Setup our common *-WMI* parameters that will apply to the WMI cmdlets in use based on input parameters
    }
    process {
        foreach ($Computer in $ComputerName) {
            $getWmiObjectSplat['ComputerName'] = $Computer
            foreach ($BLName in $BaselineName) {
                #region Query WMI for Configuration Baselines based off DisplayName
                $BLQuery = switch ($PSBoundParameters.ContainsKey('BaselineName')) {
                    $true {
                        [string]::Format("SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName = '{0}'", $BLName)
                    }
                    $false {
                        "SELECT * FROM SMS_DesiredConfiguration"
                    }
                }
                Write-Verbose "Checking for Configuration Baselines on [ComputerName='$Computer'] with [Query=`"$BLQuery`"]"
                $getWmiObjectSplat['Query'] = $BLQuery
                try {
                    $Baselines = Get-WmiObject @getWmiObjectSplat
                }
                catch {
                    # need to improve this - should catch access denied vs RPC, and need to do this on ALL WMI related queries across the module. 
                    # Maybe write a function???
                    Write-Error "Failed to query for baselines on $Computer"
                    continue
                }
                #endregion Query WMI for Configuration Baselines based off DisplayName

                #region Based on results of WMI Query, return additional information around compliance and eval time
                switch ($null -eq $Baselines) {
                    $false {
                        foreach ($BL in $Baselines) {
                            $Return = @{ }
                            $Return['ComputerName'] = $Computer
                            $Return['BaselineName'] = $BL.DisplayName
                            $Return['Version'] = $BL.Version
                            
                            #region convert LastComplianceStatus to readable value
                            $Return['LastComplianceStatus'] = switch ($BL.LastComplianceStatus) {
                                4 {
                                    'Error'
                                }
                                2 {
                                    'Non-Compliant'
                                }
                                1 {
                                    'Compliant'
                                }
                                0 {
                                    'Compliance State Unknown'
                                }
                            }
                            #endregion convert LastComplianceStatus to readable value

                            #region convert LastEvalTime to local time zone DateTime object
                            if ($null -ne $BL.LastEvalTime) {
                                try {
                                    $LastEvalTimeUTC = [DateTime]::ParseExact((($BL.LastEvalTime).Split('+|-')[0]), 'yyyyMMddHHmmss.ffffff', [System.Globalization.CultureInfo]::InvariantCulture)
                                    $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById([system.timezone]::CurrentTimeZone.StandardName)
                                    $Return['LastEvalTime'] = [System.TimeZoneInfo]::ConvertTimeFromUtc($LastEvalTimeUTC, $TimeZone)
                                }
                                catch {
                                    Write-Verbose "[BL.LastEvalTime = '$($BL.LastEvalTime)'] [LastEvalTimeUTC = '$LastEvalTimeUTC'] [TimeZone = '$TimeZone'] [LastEvalTime = '$LastEvalTime']"
                                    $Return['LastEvalTime'] = 'No Data'
                                }
                            }
                            else {
                                $Return['LastEvalTime'] = 'No Data'
                            }
                            #endregion convert LastEvalTime to local time zone DateTime object

                            [pscustomobject]$Return
                        }
                    }
                    $true {
                        Write-Warning "Failed to identify any Configuration Baselines on [ComputerName='$Computer'] with [Query=`"$BLQuery`"]"
                    }
                }
                #endregion Based on results of WMI Query, return additional information around compliance and eval time
            }
        }
    }
}