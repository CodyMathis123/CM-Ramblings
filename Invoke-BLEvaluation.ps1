function Invoke-BLEvaluation {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ComputerName,
        [Parameter(Mandatory = $False)]
        [string]$BLName,
        [parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    $getWmiObjectSplat = @{
        Namespace = 'root\ccm\dcm'
    }
    if ($PSBoundParameters.ContainsKey('ComputerName')) {
        $getWmiObjectSplat.Add('ComputerName', $ComputerName)
    }
    if ($PSBoundParameters.ContainsKey('Credential')) {
        $getWmiObjectSplat.Add('Credential', $Credential)
    }

    $BLQuery = switch ($PSBoundParameters.ContainsKey('BLName')) {
        $true {
            [string]::Format("SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName = '{0}'", $BLName)
        }
        $false {
            [string]::Format("SELECT * FROM SMS_DesiredConfiguration", $BLName)
        }
    }
    $getWmiObjectSplat.Add('Query', $BLQuery)
    $Baselines = Get-WmiObject @getWmiObjectSplat
    $PropertyOptions = 'IsEnforced', 'IsMachineTarget', 'Name', 'PolicyType', 'Version'
    foreach ($BL in $Baselines) {
        $ValidParams = $BL.GetMethodParameters('TriggerEvaluation').Properties.Name
        $Select = Compare-Object -ReferenceObject $PropertyOptions -DifferenceObject $ValidParams -IncludeEqual -ExcludeDifferent -PassThru
        $BaselineArguments = foreach ($Property in $Select) {
            $BL.$Property
        }
        $invokeWmiMethodSplat = @{
            Namespace    = 'root\ccm\dcm'
            Class        = 'SMS_DesiredConfiguration'
            ErrorAction  = 'Stop'
            Name         = 'TriggerEvaluation'
            ArgumentList = $BaselineArguments
        }
        switch ($PSBoundParameters.ContainsKey('ComputerName')) {
            $true {
                $invokeWmiMethodSplat.Add('ComputerName', $ComputerName)
            }
            $false {
                $invokeWmiMethodSplat.Add('ComputerName', $env:COMPUTERNAME)
            }
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $invokeWmiMethodSplat.Add('Credential', $Credential)
        }
        Write-Verbose "Triggering a $($BL.Name) Cycle on $ComputerName via the 'TriggerEvaluation' WMI method"
        Invoke-WmiMethod @invokeWmiMethodSplat
    }
}
