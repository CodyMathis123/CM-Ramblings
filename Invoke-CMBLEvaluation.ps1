function Invoke-CMBLEvaluation {
    <#
.SYNOPSIS
    Invoke SCCM Configuration Baselines on the specified computers
.DESCRIPTION
    This function will allow you to provide an array of computer names, and configuration baseline names which will be invoked.
    If you do not specify a baseline name, then ALL baselines on the machine will be invoked. A [PSCustomObject] is returned that
    outlines the results, including the last time the baseline was ran, and if the previous run returned compliant or non-compliant.
.PARAMETER ComputerName
    Provides computer names to invoke the configuration baselines on.
.PARAMETER BaselineName
    Provides the configuration baseline names that you wish to invoke.
.PARAMETER Credential
    Provides optional credentials to use for the WMI cmdlets.
.EXAMPLE
    C:\PS> Invoke-CMBLEvaluation
        Invoke all baselines identified in WMI on the local computer.
.EXAMPLE
    C:\PS> Invoke-CMBLEvaluation -ComputerName 'Workstation1234','Workstation4321' -BaselineName 'Check Computer Compliance','Double Check Computer Compliance'
        Invoke the two baselines on the computers specified. This demonstrates that both ComputerName and BaselineName accept string arrays.
.EXAMPLE
    C:\PS> Invoke-CMBLEvaluation -ComputerName 'Workstation1234','Workstation4321'
        Invoke all baselines identified in WMI for the computers specified. 
.NOTES
    FileName:    Invoke-CMBLEvaluation.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     2019-07-24
    Updated:     2019-07-24

    It is important to note that if a configuration baseline has user settings, the only way to invoke it is if the user is logged in, and you run this script
    with those credentials. An example would be if Workstation1234 has user Jim1234 logged in, with a configuration baseline 'FixJimsStuff' that has user settings,

    This command would successfully invoke FixJimsStuff
    Invoke-CMBLEvaluation.ps1 -ComputerName 'Workstation1234' -BaselineName 'FixJimsStuff' -Credential $JimsCreds

    This command would not find the baseline FixJimsStuff, and be unable to invoke it
    Invoke-CMBLEvaluation.ps1 -ComputerName 'Workstation1234' -BaselineName 'FixJimsStuff'

    You could remotely invoke that baseline AS Jim1234, with either a runas on PowerShell, or providing Jim's credentials to the function's -Credential param.
    If you try to invoke this same baseline without Jim's credentials being used in some way you will see that the baseline is not found.

    Outside of that, it will dynamically generate the arguments to pass to the TriggerEvaluation method. I found a handful of examples on the internet for
    invoking SCCM Configuration Baselines, and there were always comments about certain scenarios not working. This implementation has been consistent in
    invoking Configuration Baselines, including those with user settings, as long as the context is correct.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory = $false)]
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
        $invokeWmiMethodSplat = @{
            Namespace   = 'root\ccm\dcm'
            Class       = 'SMS_DesiredConfiguration'
            ErrorAction = 'Stop'
            Name        = 'TriggerEvaluation'
        }
        switch ($PSBoundParameters.ContainsKey('Credential')) {
            $true {
                $getWmiObjectSplat.Add('Credential', $Credential)
                $invokeWmiMethodSplat.Add('Credential', $Credential)
            }
        }
        switch ($PSBoundParameters.ContainsKey('BaselineName')) {
            $false {
                $BaselineName = 'NotSpecified'
            }
        }
        #endregion Setup our common *-WMI* parameters that will apply to the WMI cmdlets in use based on input parameters

        <#
            Not all Properties are on all Configuration Baseline instances, this is the list of possible options
            We will compare this list to the $ValidParams identified per Configuration Baseline found with the Get-WMIObject query
        #>
        $PropertyOptions = 'IsEnforced', 'IsMachineTarget', 'Name', 'PolicyType', 'Version'
    }
    process {
        $Return = foreach ($Computer in $ComputerName) {
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
                $Baselines = Get-WmiObject @getWmiObjectSplat
                #endregion Query WMI for Configuration Baselines based off DisplayName

                #region Based on results of WMI Query, identify arguments and invoke TriggerEvaluation
                switch ($null -eq $Baselines) {
                    $false {
                        foreach ($BL in $Baselines) {
                            #region generate a property ordered list of existing arguments to pass to the TriggerEvaluation method. Order is important!
                            $ValidParams = $BL.GetMethodParameters('TriggerEvaluation').Properties.Name
                            $compareObjectSplat = @{
                                ReferenceObject  = $PropertyOptions
                                DifferenceObject = $ValidParams
                                ExcludeDifferent = $true
                                IncludeEqual     = $true
                                PassThru         = $true
                            }
                            $Select = Compare-Object @compareObjectSplat
                            $BaselineArguments = foreach ($Property in $Select) {
                                $BL.$Property
                            }
                            #endregion generate a property ordered list of existing arguments to pass to the TriggerEvaluation method. Order is important!

                            #region Trigger the Configuration Baseline to run
                            $invokeWmiMethodSplat['ComputerName'] = $Computer
                            $invokeWmiMethodSplat['ArgumentList'] = $BaselineArguments
                            Write-Verbose "Identified the Configuration Baseline [BaselineName='$($BL.DisplayName)'] on [ComputerName='$Computer'] will trigger via the 'TriggerEvaluation' WMI method"
                            try {
                                $Invocation = Invoke-WmiMethod @invokeWmiMethodSplat
                                switch ($Invocation.ReturnValue) {
                                    0 {
                                        $Invoked = $true
                                    }
                                    default {
                                        $Invoked = $false
                                    }
                                }
                            }
                            catch {
                                $Invoked = $false
                            }

                            #region convert LastComplianceStatus to readable value
                            $LastComplianceStatus = switch ($BL.LastComplianceStatus) {
                                1 {
                                    'Compliant'
                                }
                                0 {
                                    'Non-Compliant'
                                }
                            }
                            #endregion convert LastComplianceStatus to readable value

                            #region convert LastEvalTime to local time zone DateTime object
                            if ($null -ne $BL.LastEvalTime) {
                                $LastEvalTimeUTC = [DateTime]::ParseExact((($BL.LastEvalTime).Split('+|-')[0]), 'yyyyMMddHHmmss.ffffff', [System.Globalization.CultureInfo]::InvariantCulture)
                                $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById([system.timezone]::CurrentTimeZone.StandardName)
                                $LastEvalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($LastEvalTimeUTC, $TimeZone)
                            }
                            else {
                                $LastEvalTime = 'No Data'
                            }
                            #endregion convert LastEvalTime to local time zone DateTime object

                            [pscustomobject] @{
                                ComputerName         = $Computer
                                Baseline             = $BL.DisplayName
                                Invoked              = $Invoked
                                LastComplianceStatus = $LastComplianceStatus
                                LastEvalTime         = $LastEvalTime
                            }
                            #endregion Trigger the Configuration Baseline to run
                        }
                    }
                    $true {
                        Write-Warning "Failed to identify any Configuration Baselines on [ComputerName='$Computer'] with [Query=`"$BLQuery`"]"
                        [pscustomobject] @{
                            ComputerName         = $Computer
                            Baseline             = $BLName
                            Invoked              = 'Not Found'
                            LastComplianceStatus = $null
                            LastEvalTime         = $null
                        }
                    }
                }
                #endregion Based on results of WMI Query, identify arguments and invoke TriggerEvaluation
            }
        }
    }
    end {
        return $Return
    }
}
