param(
    # WQL formatted query to perform
    [Parameter(Mandatory = $true, ParameterSetName = 'CustomQuery')]
    [string]
    $Query,
    # SMS Provider to query against
    [Parameter(Mandatory = $true)]
    [string]
    $SMSProvider,
    # Optional PSCredential (unfortunately I can't figure out how to use this cred in the DynamicParam WMI queries without providing info outside the function)
    [Parameter(Mandatory = $false, ParameterSetName = 'CustomQuery')]
    [pscredential]
    $Credential
)
DynamicParam {
    if (($SMSProvider = $PSBoundParameters['SMSProvider'])) {
        $ParameterName = 'SCCMQuery'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = 'ExistingQuery'
        $ParameterAttribute.HelpMessage = 'Specify the name of a query that already exists in your ConfigMgr environment'
        $AttributeCollection.Add($ParameterAttribute)
        $SiteCode = (Get-WmiObject -Namespace "root\sms" -ClassName "__Namespace" -ComputerName $SMSProvider).Name.Substring(5, 3)
        $Namespace = [string]::Format("root\sms\site_{0}", $SiteCode)
        $arrSet = Get-WmiObject -ComputerName $SMSProvider -Namespace $Namespace -Query "SELECT Name FROM SMS_Query WHERE Expression not like '*##PRM:*'" | Select-Object -ExpandProperty Name
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }
}
Begin {
    $SCCMQuery = $PsBoundParameters[$ParameterName]
    if ($PSBoundParameters.ContainsKey('Credential') -and -not $PSDefaultParameterValues.ContainsKey("Get-WmiObject:Credential")) {
        $AddedDefaultParam = $true
        $PSDefaultParameterValues.Add("Get-WmiObject:Credential", $Credential)
    }
    $SiteCode = (Get-WmiObject -Namespace "root\sms" -ClassName "__Namespace" -ComputerName $SMSProvider).Name.Substring(5, 3)
    $Namespace = [string]::Format("root\sms\site_{0}", $SiteCode)
    if ($PSCmdlet.ParameterSetName -eq 'ExistingQuery') {
        $Query = Get-WmiObject -ComputerName $SMSProvider -Namespace $Namespace -Query "SELECT Expression FROM SMS_Query WHERE Name ='$SCCMQuery'" | Select-Object -ExpandProperty Expression
    }
}
Process {
    $RawResults = Get-WmiObject -ComputerName $SMSProvider -Namespace $Namespace -Query $Query
    $PropertySelectors = $RawResults | Get-Member -MemberType Property | Where-Object { -not $_.Name.StartsWith('__') } | Select-Object -ExpandProperty name | ForEach-Object {
        $Class = $_
        $Properties = $RawResults.$Class | Get-Member -MemberType Property | Where-Object { -not $_.Name.StartsWith('__') } | Select-Object -ExpandProperty name
        foreach ($Property in $Properties) {
            [string]::Format("@{{Label='{1}.{0}';Expression = {{`$_.{1}.{0}}}}}", $Property, $Class)
        }
    }
}
end {
    if ($AddedDefaultParam) {
        $PSDefaultParameterValues.Remove("Get-WmiObject:Credential")
    }
    $PropertySelector = [scriptblock]::Create($($PropertySelectors -join ','))
    $RawResults | Select-Object -Property $(. $PropertySelector)
}
