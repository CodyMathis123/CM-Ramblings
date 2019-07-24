function Invoke-BLEvaluation {
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
                            $LastEvalTimeUTC = [DateTime]::ParseExact((($BL.LastEvalTime).Split('+|-')[0]), 'yyyyMMddHHmmss.ffffff', [System.Globalization.CultureInfo]::InvariantCulture)
                            $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById([system.timezone]::CurrentTimeZone.StandardName)
                            $LastEvalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($LastEvalTimeUTC, $TimeZone)
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
