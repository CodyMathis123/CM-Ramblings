param(
    [string]$BLName
)

$BLQuery = [string]::Format("SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName = '{0}'", $BLName)


$getBaselineSplat = @{
    Namespace   = 'root\ccm\dcm'
    ErrorAction = 'Stop'
    Query = $BLQuery
}

$invokeBaselineEvalSplat = @{
    Namespace   = 'root\ccm\dcm'
    ClassName   = 'SMS_DesiredConfiguration'
    ErrorAction = 'Stop'
    Name        = 'TriggerEvaluation'
}

$PropertyOptions = 'IsEnforced', 'IsMachineTarget', 'Name', 'PolicyType', 'Version'

$BL = Get-CimInstance @getBaselineSplat


$ArgumentList = @{ }
foreach ($Property in $PropertyOptions) {
    $PropExist = Get-Member -InputObject $BL -MemberType Properties -Name $Property -ErrorAction SilentlyContinue
    switch ($PropExist) {
        $null {
            continue
        }
        default {
            $TypeString = ($PropExist.Definition.Split(' '))[0]
            $Type = [scriptblock]::Create("[$TypeString]")
            $ArgumentList[$Property] = $BL.$Property -as (. $Type)
        }
    }
}
$invokeBaselineEvalSplat['Arguments'] = $ArgumentList

Invoke-CimMethod @invokeBaselineEvalSplat