param(
    $SMSProvider = 'SCCM.CONTOSO.COM',
    $ApplicationName = 'Office 365 with Visio/Project Pro/Standard 2016/2019 x86',
    $Company = 'Contoso',
    $AppRoot = "\\Contoso.com\apps\Office365Magic"
)
#region functions
function New-CMGlobalConditionsRule {
    [CmdletBinding(DefaultParameterSetName = "__AllParameterSets")]
    param (
        [parameter(Mandatory = $true)]
        [string]$SMSProvider
    )
    DynamicParam {
        function New-DynamicParam {
            <#
                .SYNOPSIS
                    Helper function to simplify creating dynamic parameters
                
                .DESCRIPTION
                    Helper function to simplify creating dynamic parameters
            
                    Example use cases:
                        Include parameters only if your environment dictates it
                        Include parameters depending on the value of a user-specified parameter
                        Provide tab completion and intellisense for parameters, depending on the environment
            
                    Please keep in mind that all dynamic parameters you create will not have corresponding variables created.
                       One of the examples illustrates a generic method for populating appropriate variables from dynamic parameters
                       Alternatively, manually reference $PSBoundParameters for the dynamic parameter value
            
                .NOTES
                    Credit to http://jrich523.wordpress.com/2013/05/30/powershell-simple-way-to-add-dynamic-parameters-to-advanced-function/
                        Added logic to make option set optional
                        Added logic to add RuntimeDefinedParameter to existing DPDictionary
                        Added a little comment based help
            
                    Credit to BM for alias and type parameters and their handling
            
                .PARAMETER Name
                    Name of the dynamic parameter
            
                .PARAMETER Type
                    Type for the dynamic parameter.  Default is string
            
                .PARAMETER Alias
                    If specified, one or more aliases to assign to the dynamic parameter
            
                .PARAMETER ValidateSet
                    If specified, set the ValidateSet attribute of this dynamic parameter
            
                .PARAMETER Mandatory
                    If specified, set the Mandatory attribute for this dynamic parameter
            
                .PARAMETER ParameterSetName
                    If specified, set the ParameterSet attribute for this dynamic parameter
            
                .PARAMETER Position
                    If specified, set the Position attribute for this dynamic parameter
            
                .PARAMETER ValueFromPipelineByPropertyName
                    If specified, set the ValueFromPipelineByPropertyName attribute for this dynamic parameter
            
                .PARAMETER HelpMessage
                    If specified, set the HelpMessage for this dynamic parameter
                
                .PARAMETER DPDictionary
                    If specified, add resulting RuntimeDefinedParameter to an existing RuntimeDefinedParameterDictionary (appropriate for multiple dynamic parameters)
                    If not specified, create and return a RuntimeDefinedParameterDictionary (appropriate for a single dynamic parameter)
            
                    See final example for illustration
            
                .EXAMPLE
                    
                    function Show-Free
                    {
                        [CmdletBinding()]
                        Param()
                        DynamicParam {
                            $options = @( gwmi win32_volume | %{$_.driveletter} | sort )
                            New-DynamicParam -Name Drive -ValidateSet $options -Position 0 -Mandatory
                        }
                        begin{
                            #have to manually populate
                            $drive = $PSBoundParameters.drive
                        }
                        process{
                            $vol = gwmi win32_volume -Filter "driveletter='$drive'"
                            "{0:N2}% free on {1}" -f ($vol.Capacity / $vol.FreeSpace),$drive
                        }
                    } #Show-Free
            
                    Show-Free -Drive <tab>
            
                # This example illustrates the use of New-DynamicParam to create a single dynamic parameter
                # The Drive parameter ValidateSet populates with all available volumes on the computer for handy tab completion / intellisense
            
                .EXAMPLE
            
                # I found many cases where I needed to add more than one dynamic parameter
                # The DPDictionary parameter lets you specify an existing dictionary
                # The block of code in the Begin block loops through bound parameters and defines variables if they don't exist
            
                    Function Test-DynPar{
                        [cmdletbinding()]
                        param(
                            [string[]]$x = $Null
                        )
                        DynamicParam
                        {
                            #Create the RuntimeDefinedParameterDictionary
                            $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    
                            New-DynamicParam -Name AlwaysParam -ValidateSet @( gwmi win32_volume | %{$_.driveletter} | sort ) -DPDictionary $Dictionary
            
                            #Add dynamic parameters to $dictionary
                            if($x -eq 1)
                            {
                                New-DynamicParam -Name X1Param1 -ValidateSet 1,2 -mandatory -DPDictionary $Dictionary
                                New-DynamicParam -Name X1Param2 -DPDictionary $Dictionary
                                New-DynamicParam -Name X3Param3 -DPDictionary $Dictionary -Type DateTime
                            }
                            else
                            {
                                New-DynamicParam -Name OtherParam1 -Mandatory -DPDictionary $Dictionary
                                New-DynamicParam -Name OtherParam2 -DPDictionary $Dictionary
                                New-DynamicParam -Name OtherParam3 -DPDictionary $Dictionary -Type DateTime
                            }
                    
                            #return RuntimeDefinedParameterDictionary
                            $Dictionary
                        }
                        Begin
                        {
                            #This standard block of code loops through bound parameters...
                            #If no corresponding variable exists, one is created
                                #Get common parameters, pick out bound parameters not in that set
                                Function _temp { [cmdletbinding()] param() }
                                $BoundKeys = $PSBoundParameters.keys | Where-Object { (get-command _temp | select -ExpandProperty parameters).Keys -notcontains $_}
                                foreach($param in $BoundKeys)
                                {
                                    if (-not ( Get-Variable -name $param -scope 0 -ErrorAction SilentlyContinue ) )
                                    {
                                        New-Variable -Name $Param -Value $PSBoundParameters.$param
                                        Write-Verbose "Adding variable for dynamic parameter '$param' with value '$($PSBoundParameters.$param)'"
                                    }
                                }
            
                            #Appropriate variables should now be defined and accessible
                                Get-Variable -scope 0
                        }
                    }
            
                # This example illustrates the creation of many dynamic parameters using New-DynamicParam
                    # You must create a RuntimeDefinedParameterDictionary object ($dictionary here)
                    # To each New-DynamicParam call, add the -DPDictionary parameter pointing to this RuntimeDefinedParameterDictionary
                    # At the end of the DynamicParam block, return the RuntimeDefinedParameterDictionary
                    # Initialize all bound parameters using the provided block or similar code
            
                .FUNCTIONALITY
                    PowerShell Language
            
            #>
            param(
                
                [string]
                $Name,
                
                [System.Type]
                $Type = [string],
            
                [string[]]
                $Alias = @(),
            
                [string[]]
                $ValidateSet,
                
                [switch]
                $Mandatory,
                
                [string[]]
                $ParameterSetName = "__AllParameterSets",
                
                [int]
                $Position,
                
                [switch]
                $ValueFromPipelineByPropertyName,
                
                [string]
                $HelpMessage,
            
                [validatescript( {
                        if (-not ( $_ -is [System.Management.Automation.RuntimeDefinedParameterDictionary] -or -not $_) ) {
                            Throw "DPDictionary must be a System.Management.Automation.RuntimeDefinedParameterDictionary object, or not exist"
                        }
                        $True
                    })]
                $DPDictionary = $false
             
            )
            #Create attribute object, add attributes, add to collection   
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'

            foreach ($Set in $ParameterSetName) {
                $ParamAttr = New-Object System.Management.Automation.ParameterAttribute
                $ParamAttr.ParameterSetName = $Set
                if ($mandatory) {
                    $ParamAttr.Mandatory = $True
                }
                if ($null -ne $Position) {
                    $ParamAttr.Position = $Position
                }
                if ($ValueFromPipelineByPropertyName) {
                    $ParamAttr.ValueFromPipelineByPropertyName = $True
                }
                if ($HelpMessage) {
                    $ParamAttr.HelpMessage = $HelpMessage
                }
                 
                $AttributeCollection.Add($ParamAttr)    
                #param validation set if specified
                if ($ValidateSet) {
                    $ParamOptions = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $ValidateSet
                    $AttributeCollection.Add($ParamOptions)
                }
            
                #Aliases if specified
                if ($Alias.count -gt 0) {
                    $ParamAlias = New-Object System.Management.Automation.AliasAttribute -ArgumentList $Alias
                    $AttributeCollection.Add($ParamAlias)
                }
            }
                
            
             
            #Create the dynamic parameter
            $Parameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)
                
            #Add the dynamic parameter to an existing dynamic parameter dictionary, or create the dictionary and add it
            if ($DPDictionary) {
                $DPDictionary.Add($Name, $Parameter)
            }
            else {
                $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $Dictionary.Add($Name, $Parameter)
                $Dictionary
            }
        }

        $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $SiteCode = $(((Get-WmiObject -Namespace "root\sms" -Class "__Namespace" -ComputerName $SMSProvider).Name).Substring(8 - 3))

        $newDynamicParamSplat = @{
            Mandatory        = $true
            ParameterSetName = 'ValueBased'
            DPDictionary     = $Dictionary
            Name             = 'Value'
            Type             = [object[]]
        }
        New-DynamicParam @newDynamicParamSplat

        $newDynamicParamSplat = @{
            Mandatory        = $true
            Type             = [string]
            ValidateSet      = @('Exists', 'NotExists')
            DPDictionary     = $Dictionary
            Name             = 'Existential'
            ParameterSetName = 'Existential'
        }
        New-DynamicParam @newDynamicParamSplat

        $getWmiObjectSplat = @{
            Property     = 'LocalizedDisplayName'
            ComputerName = $SMSProvider
            Namespace    = "root\sms\site_$SiteCode"
            Class        = 'SMS_GlobalCondition'
        }
        $GlobalConditions = Get-WmiObject @getWmiObjectSplat | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object
        $newDynamicParamSplat = @{
            Mandatory        = $true
            DPDictionary     = $Dictionary
            Name             = 'GlobalConditionName'
            Type             = [string]
            ValidateSet      = $GlobalConditions
            ParameterSetName = 'ValueBased', 'Existential'
        }
        New-DynamicParam @newDynamicParamSplat
        
        $SettingSourceTypeSet = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingSourceType] | Get-Member -Static -MemberType Properties | Select-Object -ExpandProperty Name
        $newDynamicParamSplat = @{
            DPDictionary     = $Dictionary
            Name             = 'SettingSourceType'
            Type             = [string]
            ValidateSet      = $SettingSourceTypeSet
            ParameterSetName = 'ValueBased', 'Existential'
        }
        New-DynamicParam @newDynamicParamSplat

        $getWmiObjectSplat = @{
            Filter       = "ModelName NOT LIKE 'ScopeID_%'"
            ComputerName = $SMSProvider
            Namespace    = "root\sms\site_$SiteCode"
            Property     = 'ModelName'
            Class        = 'SMS_ConfigurationItemRules'
        }
        $OSValues = Get-WmiObject @getWmiObjectSplat | Select-Object -ExpandProperty ModelName | Where-Object { $_ -match "Windows/" }
        $newDynamicParamSplat = @{
            Mandatory        = $true
            DPDictionary     = $Dictionary
            Name             = 'OperatingSystem'
            Type             = [string[]]
            ValidateSet      = $OSValues
            ParameterSetName = 'OperatingSystem'
        }
        New-DynamicParam @newDynamicParamSplat

        $Operators = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator] | Get-Member -Static -MemberType Properties | Select-Object -ExpandProperty Name
        $newDynamicParamSplat = @{
            Mandatory        = $true
            DPDictionary     = $Dictionary
            Name             = 'Operator'
            Type             = [string]
            ValidateSet      = $Operators
            ParameterSetName = 'ValueBased', 'OperatingSystem'
        }
        New-DynamicParam @newDynamicParamSplat
        $Dictionary
    }
    begin {
        #region Get common parameters, pick out bound parameters not in that set
        Function _temp {
            [cmdletbinding()] param() 
        }
        $BoundKeys = $PSBoundParameters.keys | Where-Object { (Get-Command _temp | Select-Object -ExpandProperty parameters).Keys -notcontains $_}
        foreach ($param in $BoundKeys) {
            if (-not ( Get-Variable -name $param -scope 0 -ErrorAction SilentlyContinue ) ) {
                New-Variable -Name $Param -Value $PSBoundParameters.$param
                Write-Verbose "Adding variable for dynamic parameter '$param' with value '$($PSBoundParameters.$param)'"
            }
        }
        #endregion Get common parameters, pick out bound parameters not in that set
        #region simply set the name to 'Operating System' if that is global condition we are targeting
        if ($PSCmdlet.ParameterSetName -eq 'OperatingSystem') {
            $GlobalConditionName = 'Operating System'
        }
        #endregion simply set the name to 'Operating System' if that is global condition we are targeting
    }
    process {
        $SiteCode = $(((Get-WmiObject -namespace "root\sms" -class "__Namespace" -ComputerName $SMSProvider).Name).substring(8 - 3))

        #region gather GlobalCondition from WMI based on the name provided, object is used to generate the Rule and populate informational fields
        $getWmiObjectSplat = @{
            ComputerName = $SMSProvider
            Namespace    = "root\sms\site_$SiteCode"
            Class        = 'SMS_GlobalCondition'
        }
        if ($GlobalConditionName -eq 'Operating System') {
            $getWmiObjectSplat.Filter = "LocalizedDisplayName = '$GlobalConditionName' and ModelName = 'GLOBAL/OperatingSystem'"
        }
        else {
            $getWmiObjectSplat.Filter = "LocalizedDisplayName = '$GlobalConditionName'"
        }
        $GlobalCondition = Get-WmiObject @getWmiObjectSplat

        $TempGC = $GlobalCondition.ModelName.Split("/")
        $GlobalConditionScope = $TempGC[0]
        $GlobalConditionLogicalName = $TempGC[1]
        #endregion gather GlobalCondition from WMI based on the name provided, object is used to generate the Rule and populate informational fields

        #region if we are creating an Existential rule then we default to an Int64 DataType, otherwise we use our 'found' data type based on the GC
        if ($PSCmdlet.ParameterSetName -eq 'Existential') {
            $GlobalConditionExpressionDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::Int64
        }
        else {
            $GlobalConditionDataType = $GlobalCondition.DataType
            $GlobalConditionExpressionDataType = [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.DataType]::GetDataTypeFromTypeName($GlobalConditionDataType)
        }
        #endregion if we are creating an Existential rule then we default to an Int64 DataType, otherwise we use our 'found' data type based on the GC
                
        #region determine logical name of setting
        $GlobaclConditionSDMPackageXML = [xml] ([wmi]$GlobalCondition.__PATH).SDMPackageXML
        if ($GlobaclConditionSDMPackageXML.DesiredConfigurationDigest.GlobalSettings.AuthoringScopeId -eq "GLOBAL") {
            $SettingLogicalName = "$($GlobalConditionLogicalName)_Setting_LogicalName"
        }
        else {
            $SettingLogicalName = $GlobaclConditionSDMPackageXML.DesiredConfigurationDigest.GlobalSettings.Settings.FirstChild.FirstChild.LogicalName
        }
        if (-not $SettingLogicalName) {
            $SettingLogicalName = $GlobaclConditionSDMPackageXML.DesiredConfigurationDigest.GlobalExpression.LogicalName
        }
        #endregion determine logical name of setting

        #Checking for ConfigurationItemSetting
        if ($PSBoundParameters.ContainsKey('SettingSourceType')) {
            $CISettingSourceType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingSourceType]::$SettingSourceType
        }
        else {
            $CISettingSourceType = [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ConfigurationItemSettingSourceType]::CIM
        }

        $arg = @($GlobalConditionScope,
            $GlobalConditionLogicalName
            $GlobalConditionExpressionDataType,
            $SettingLogicalName,
            $CISettingSourceType
        )
        $reqSetting = New-Object  Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.GlobalSettingReference -ArgumentList $arg

        #custom properties Existential
        if ($Existential -eq "NotExists") {
            $operator = "Equals"
            $Value = 0
            $reqSetting.MethodType = "Count"
        }
        if ($Existential -eq "Exists") {
            $operator = "NotEquals"
            $Value = 0
            $reqSetting.MethodType = "Count"
        }

        $arg = @($value,
            $GlobalConditionExpressionDataType
        )
        $reqValue = New-Object Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ConstantValue -ArgumentList $arg

        $Operands = New-Object "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.ExpressionBase]]"
        $Operands.Add($reqSetting) | Out-Null
        $Operands.Add($reqValue) | Out-Null

        $ExpressionOperator = Invoke-Expression [Microsoft.ConfigurationManagement.DesiredConfigurationManagement.ExpressionOperators.ExpressionOperator]::$Operator
        if ($PSCmdlet.ParameterSetName -eq "OperatingSystem") {
            $Operands = New-Object "Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]"
            foreach ($OS in $OperatingSystem) {
                $Operands.Add($OS)
            }
            $arg = @($ExpressionOperator,
                $Operands
            )
            $Expression = New-Object Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.OperatingSystemExpression -ArgumentList $arg
            $Annotation = [string]::Format("{0} {1} {2}", $($GlobalCondition.LocalizedDisplayName), $Operator, $($OperatingSystem -join ';'))
        }
        else {
            $Args_Expression = @($ExpressionOperator,
                $Operands
            )
            $Expression = New-Object Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.Expression -ArgumentList $Args_Expression
            $Annotation = [string]::Format("{0} {1} {2}", $($GlobalCondition.LocalizedDisplayName), $Operator, $($Value -join ';'))
        }

        #region set the 'Annotation' or description for the Global Condition Rule
        $DCM_Annotation = New-Object Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Annotation
        $Args_Annotation = @(
            "DisplayName",
            $Annotation,
            $null
        )
        $DCM_Annotation.DisplayName = New-Object Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.LocalizableString -ArgumentList $Args_Annotation
        #endregion set the 'Annotation' or description for the Global Condition Rule

        $Args_Rule = @(
            ("Rule_" + [Guid]::NewGuid().ToString()),
            [Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.NoncomplianceSeverity]::None,
            $DCM_Annotation,
            $Expression
        )
        $Rule = New-Object "Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Rules.Rule" -ArgumentList $Args_Rule
    }
    end {
        return $Rule
    }
}
#endregion functions

$SiteCodePath = "$(((Get-WmiObject -namespace "root\sms" -class "__Namespace" -ComputerName $PrimarySiteServer).Name).substring(8 - 3)):"
Set-Location -Path C:
$AllXML_Options = Get-ChildItem -Path $AppRoot -Filter *.xml

#region create global conditions if they don't exist
$PrjProScript = @'
$MSI_App = 'PRJPRO'
$C2R_App = 'PROJECTPRO'
$32 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
$64 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
$MSI32 = $32 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$MSI64 = $64 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$C2R = $64 | Where-Object { $_.PSChildName -match "^$C2R_App.+Volume.+$"}
if ($MSI32 -or $C2R) {
    $true
}
else {
    $false
}
'@
$PrjStdScript = @'
$MSI_App = 'PRJSTD'
$C2R_App = 'PROJECTSTD'
$32 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
$64 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
$MSI32 = $32 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$MSI64 = $64 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$C2R = $64 | Where-Object { $_.PSChildName -match "^$C2R_App.+Volume.+$"}
if ($MSI32 -or $C2R) {
    $true
}
else {
    $false
}
'@
$VisProScript = @'
$MSI_App = 'VISPRO'
$C2R_App = 'VISIOPRO'
$32 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
$64 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
$MSI32 = $32 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$MSI64 = $64 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$C2R = $64 | Where-Object { $_.PSChildName -match "^$C2R_App.+Volume.+$"}
if ($MSI32 -or $C2R) {
    $true
}
else {
    $false
}
'@
$VisStdScript = @'
$MSI_App = 'VISSTD'
$C2R_App = 'VISIOSTD'
$32 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
$64 = Get-ChildItem -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
$MSI32 = $32 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$MSI64 = $64 | Where-Object { $_.PSChildName -match "^OFFICE[0-9]{2}\.$MSI_App$" }
$C2R = $64 | Where-Object { $_.PSChildName -match "^$C2R_App.+Volume.+$"}
if ($MSI32 -or $C2R) {
    $true
}
else {
    $false
}
'@

Set-Location -Path $SiteCodePath
$PrjProGC_Name = 'Condition Detection - Microsoft Project Pro x86'
if (-not (Get-CMGlobalCondition -Name $PrjProGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$PrjProGC_Name'"
    New-CMGlobalConditionScript -DataType Boolean -ScriptText $PrjProScript -ScriptLanguage PowerShell -Name $PrjProGC_Name
}
$PrjStdGC_Name = 'Condition Detection - Microsoft Project Standard x86'
if (-not (Get-CMGlobalCondition -Name $PrjStdGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$PrjStdGC_Name'"
    New-CMGlobalConditionScript -DataType Boolean -ScriptText $PrjStdScript -ScriptLanguage PowerShell -Name $PrjStdGC_Name
}
$VisProGC_Name = 'Condition Detection - Microsoft Visio Pro x86'
if (-not (Get-CMGlobalCondition -Name $VisProGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$VisProGC_Name'"
    New-CMGlobalConditionScript -DataType Boolean -ScriptText $VisProScript -ScriptLanguage PowerShell -Name $VisProGC_Name
}
$VisStdGC_Name = 'Condition Detection - Microsoft Visio Standard x86'
if (-not (Get-CMGlobalCondition -Name $VisStdGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$VisStdGC_Name'"
    New-CMGlobalConditionScript -DataType Boolean -ScriptText $VisStdScript -ScriptLanguage PowerShell -Name $VisStdGC_Name
}
#endregion create global conditions if they don't exist

#region create 'SCCMGlobalConditionsRule' which is actually a 'requirement' in our case
$Win7 = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -OperatingSystem Windows/All_x64_Windows_7_Client -Operator OneOf
$Win10 = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -OperatingSystem Windows/All_x64_Windows_10_and_higher_Clients -Operator OneOf
$VisStandard = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -GlobalConditionName 'Condition Detection - Microsoft Visio Standard x86' -Operator IsEquals -Value $true -SettingSourceType Script
$VisPro = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -GlobalConditionName 'Condition Detection - Microsoft Visio Pro x86' -Operator IsEquals -Value $true -SettingSourceType Script
$ProjStandard = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -GlobalConditionName 'Condition Detection - Microsoft Project Standard x86' -Operator IsEquals -Value $true -SettingSourceType Script
$ProjPro = New-CMGlobalConditionsRule -SMSProvider $PrimarySiteServer -GlobalConditionName 'Condition Detection - Microsoft Project Pro x86' -Operator IsEquals -Value $true -SettingSourceType Script
#endregion create 'SCCMGlobalConditionsRule' which is actually a 'requirement' in our case

#region parse all XML and return custom object with info we need, and sort the list, also update company in XML
Set-Location -Path C:
$DeploymentTypes = foreach ($XML in $AllXML_Options) {
    $Config = $XML.Name
    $ConfigXML = [xml]$(Get-Content -Path $XML.FullName)
    $ConfigXML.Configuration.AppSettings.Setup.Value = $Company
    Set-Content -Path $XML.FullName -Value $ConfigXml.OuterXml
    $AppName = $ConfigXML.Configuration.Info.Description
    $ProductIDs = $ConfigXML.Configuration.Add.Product.ID
    $Bitness = $ConfigXML.Configuration.Add.OfficeClientEdition.ToString()
    $Bitness = switch ($Bitness) {
        '32' {
            'x86'
        }
        '64' {
            'x64'
        }
    }

    [PSCustomObject]@{
        Config     = $Config
        AppName    = $AppName
        AppSource  = $AppRoot
        ProductIDs = $ProductIDs
        Bitness    = $Bitness
        NameLength = $($AppName.Length)
    }
}

$DeploymentTypes = $DeploymentTypes | Sort-Object -Property NameLength, AppName -Descending
#endregion parse all XML and return custom object with info we need, and sort the list, also update company in XML

Set-Location -Path $SiteCodePath
Write-Output "Creating Application [Name=$ApplicationName]"
$newCMApplicationSplat = @{
    ErrorAction    = 'Stop'
    ReleaseDate    = $(Get-Date)
    SupportContact = $env:USERNAME
    Owner          = $env:USERNAME
    Name           = $ApplicationName
    Publisher      = 'Microsoft'
    Confirm        = $false
}
try { 
    $BaseApp = New-CMApplication @newCMApplicationSplat
    Write-Output "Successfully created Application [Name=$ApplicationName]"
}
catch {
    Write-Error -Message "Failed to create Application [Name=$ApplicationName]"
}

foreach ($DT in $DeploymentTypes) {
    Write-Output $('-' * 50)
    Write-Output "Creating DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($DT.Bitness)]"
    $DetectionClauses = [System.Collections.ArrayList]::new()
    $Requirements = [System.Collections.ArrayList]::new()

    Set-Location -Path $SiteCodePath
    foreach ($ProductID in $($DT.ProductIDs)) {
        $newCMDetectionClauseRegistryKeyValueSplat = @{
            Is64Bit            = $true
            ValueName          = 'ProductReleaseIds'
            PropertyType       = 'String'
            ExpressionOperator = 'Contains'
            Value              = $false
            ExpectedValue      = $ProductID
            KeyName            = 'SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
            Hive               = 'LocalMachine'
        }
        $null = $DetectionClauses.Add($(New-CMDetectionClauseRegistryKeyValue @newCMDetectionClauseRegistryKeyValueSplat))
    }

    $newCMDetectionClauseRegistryKeyValueSplat = @{
        Is64Bit            = $true
        ValueName          = 'Platform'
        PropertyType       = 'String'
        ExpressionOperator = 'IsEquals'
        Value              = $false
        ExpectedValue      = $($DT.Bitness)
        KeyName            = 'SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
        Hive               = 'LocalMachine'
    }
    $null = $DetectionClauses.Add($(New-CMDetectionClauseRegistryKeyValue @newCMDetectionClauseRegistryKeyValueSplat))

    $newCMDetectionClauseRegistryKeyValueSplat = @{
        Is64Bit      = $true
        ValueName    = 'VersionToReport'
        Hive         = 'LocalMachine'
        Existence    = $true
        PropertyType = 'Version'
        KeyName      = 'Software\Microsoft\Office\ClickToRun\Configuration'
    }
    $null = $DetectionClauses.Add($(New-CMDetectionClauseRegistryKeyValue @newCMDetectionClauseRegistryKeyValueSplat))

    $newCMDetectionClauseFileSplat = @{
        Is64Bit   = $true
        Existence = $true
        Path      = '%ProgramFiles%\Common Files\microsoft shared\ClickToRun'
        FileName  = 'OfficeClickToRun.exe'
    }
    $null = $DetectionClauses.Add($(New-CMDetectionClauseFile @newCMDetectionClauseFileSplat))

    $addCMScriptDeploymentTypeSplat = @{
        ErrorAction              = 'Stop'
        Force32Bit               = $false
        MaximumRuntimeMins       = 90
        AddDetectionClause       = $DetectionClauses
        EstimatedRuntimeMins     = 30
        ContentLocation          = $($DT.AppSource)
        RebootBehavior           = 'NoAction'
        InstallCommand           = "setup.exe /configure $($DT.Config)"
        InstallationBehaviorType = 'InstallForSystem'
        DeploymentTypeName       = $($DT.AppName)
        LogonRequirementType     = 'WhetherOrNotUserLoggedOn'
        InputObject              = $BaseApp
        UserInteractionMode      = 'Normal'
    }

    if ($DT.AppName -match 'Visio Standard') {
        $null = $Requirements.Add($VisStandard)
    }
    if ($DT.AppName -match 'Visio Pro') {
        $null = $Requirements.Add($VisPro)
    }

    if ($DT.AppName -match 'Project Pro') {
        $null = $Requirements.Add($ProjPro)
    }
    if ($DT.AppName -match 'Project Standard') {
        $null = $Requirements.Add($ProjStandard)
    }

    if ($DT.AppName -match '2019') {
        $null = $Requirements.Add($Win10)
    }
    if ($DT.AppName -match '2016') {
        $null = $Requirements.Add($Win7)
    }
    $addCMScriptDeploymentTypeSplat.AddRequirement = $Requirements
    try {
        $null = Add-CMScriptDeploymentType @addCMScriptDeploymentTypeSplat -
        Write-Output "Successfully created DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($DT.Bitness)]"
    }
    catch {
        Write-Error -Message "Failed to create DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($DT.Bitness)]"
    }
    Write-Output $('-' * 50)
}