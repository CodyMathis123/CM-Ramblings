# define all the protocols available
$ProtocolList = @('SSL 2.0', 'SSL 3.0', 'TLS 1.0', 'TLS 1.1', 'TLS 1.2')
# specify all the protocols that should remain enabled
$EnableList = @('TLS 1.2')

$SetKeyParams = @{
    DataType              = 'Integer'
    Hive                  = 'LocalMachine'
    ReportNoncompliance   = $true
    ExpressionOperator    = 'IsEquals'
    Remediate             = $true
    ValueRule             = $true
    NoncomplianceSeverity = 'Warning'
    RemediateDword        = $true
    Is64Bit               = $true
}

$GetKeyExistanceParams = @{
    Existence             = 'MustExist'
    Hive                  = 'LocalMachine'
    DataType              = 'Integer'
    ExistentialRule       = $true
    NoncomplianceSeverity = 'Warning'
    RemediateDword        = $true
    Is64Bit               = $true
}

$EnabledListString = $EnableList -join ', '
$BL = New-CMBaseline -Name "Enforce $EnabledListString" -Description "Configures the machine to only use $EnabledListString"
foreach ($Protocol in $ProtocolList) {
    if ($Protocol -in $EnableList) {
        $Name = "Registry - Enable $Protocol"
        $Description = "Forces $Protocol to be enabled"
    }
    else {
        $Name = "Registry - Disable $Protocol"
        $Description = "Forces $Protocol to be disabled"
    }
    $CI = New-CMConfigurationItem -Name $Name -Description $Description -CreationType WindowsOS

    $SetKeyParams['InputObject'] = $CI
    $GetKeyExistanceParams['InputObject'] = $CI


    foreach ($key in @('Client', 'Server')) {
        $currentRegPath = [string]::Format('SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\{1}', $Protocol, $key)
        $SetKeyParams['KeyName'] = $currentRegPath
        $GetKeyExistanceParams['KeyName'] = $currentRegPath

        if ($Protocol -in $EnableList) {
            $SetKeyParams['Name'] = "Set $Protocol DisabledByDefault for $key to 0"
            $SetKeyParams['ExpectedValue'] = 0
            $SetKeyParams['RuleName'] = "Set $Protocol DisabledByDefault for $key to 0"
            $SetKeyParams['ValueName'] = 'DisabledByDefault'
            $SetKeyParams['Description'] = "Set $Protocol DisabledByDefault for $key to 0 to ensure $Protocol is enabled"
            $SetKeyParams['RuleDescription'] = "Set $Protocol DisabledByDefault for $key to 0 to ensure $Protocol is enabled"
            Add-CMComplianceSettingRegistryKeyValue @SetKeyParams

            $SetKeyParams['Name'] = "Set $Protocol Enabled for $key to 1"
            $SetKeyParams['ExpectedValue'] = 1
            $SetKeyParams['RuleName'] = "Set $Protocol Enabled for $key to 1"
            $SetKeyParams['ValueName'] = 'Enabled'
            $SetKeyParams['Description'] = "Set $Protocol Enabled for $key to 1 to ensure $Protocol is enabled"
            $SetKeyParams['RuleDescription'] = "Set $Protocol Enabled for $key to 1 to ensure $Protocol is enabled"
            Add-CMComplianceSettingRegistryKeyValue @SetKeyParams

            $GetKeyExistanceParams['Name'] = "Validate $Protocol $Key Enabled exists"
            $GetKeyExistanceParams['RuleName'] = "Validate $Protocol $Key Enabled exists"
            $GetKeyExistanceParams['ValueName'] = 'Enabled'
            Add-CMComplianceSettingRegistryKeyValue @GetKeyExistanceParams

            $GetKeyExistanceParams['Name'] = "Validate $Protocol $Key DisabledByDefault exists"
            $GetKeyExistanceParams['RuleName'] = "Validate $Protocol $Key DisabledByDefault exists"
            $GetKeyExistanceParams['ValueName'] = 'DisabledByDefault'
            Add-CMComplianceSettingRegistryKeyValue @GetKeyExistanceParams
        }
        else {
            $SetKeyParams['Name'] = "Set $Protocol DisabledByDefault for $key to 1"
            $SetKeyParams['ExpectedValue'] = 1
            $SetKeyParams['RuleName'] = "Set $Protocol DisabledByDefault for $key to 1"
            $SetKeyParams['ValueName'] = 'DisabledByDefault'
            $SetKeyParams['Description'] = "Set $Protocol DisabledByDefault for $key to 1 to ensure $Protocol is disabled"
            $SetKeyParams['RuleDescription'] = "Set $Protocol DisabledByDefault for $key to 1 to ensure $Protocol is disabled"
            Add-CMComplianceSettingRegistryKeyValue @SetKeyParams

            $SetKeyParams['Name'] = "Set $Protocol Enabled for $key to 0"
            $SetKeyParams['ExpectedValue'] = 0
            $SetKeyParams['RuleName'] = "Set $Protocol Enabled for $key to 0"
            $SetKeyParams['ValueName'] = 'Enabled'
            $SetKeyParams['Description'] = "Set $Protocol Enabled for $key to 0 to ensure $Protocol is disabled"
            $SetKeyParams['RuleDescription'] = "Set $Protocol Enabled for $key to 0 to ensure $Protocol is disabled"
            Add-CMComplianceSettingRegistryKeyValue @SetKeyParams

            $GetKeyExistanceParams['Name'] = "Validate $Protocol $Key Enabled exists"
            $GetKeyExistanceParams['RuleName'] = "Validate $Protocol $Key Enabled exists"
            $GetKeyExistanceParams['ValueName'] = 'Enabled'
            Add-CMComplianceSettingRegistryKeyValue @GetKeyExistanceParams

            $GetKeyExistanceParams['Name'] = "Validate $Protocol $Key DisabledByDefault exists"
            $GetKeyExistanceParams['RuleName'] = "Validate $Protocol $Key DisabledByDefault exists"
            $GetKeyExistanceParams['ValueName'] = 'DisabledByDefault'
            Add-CMComplianceSettingRegistryKeyValue @GetKeyExistanceParams
        }
    }
    Set-CMBaseline -Id $BL.CI_ID -AddOSConfigurationItem $CI.CI_ID
}
