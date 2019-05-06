<#
.SYNOPSIS
    Generate an Office 365 application for use in Configuration Manager that has a deployment type per app combination
.DESCRIPTION
    This script will take your desired input parameters to generate an application with various deployment types.
    The use case is an upgrade from an older version of Microsoft Office to Office 365. The correct combination of
    applications will be selected and installed based on Global Conditions assinged as requirements for the various
    deployment types. You also can select your desired Update Channe, Bitness, license type, Company Name, as well as
    other options.
.PARAMETER SMSProvider
    Provides the name for the SMSProvider for the environment you want to create the application in.
.PARAMETER ApplicationName
    Provides the name which you want assigned to the application that is created by this script.
.PARAMETER Company
    Provides the company name you want specified in all of the XML files.
.PARAMETER AppRoot
    Provides the root directory for the application to be created. This should be pre-populated with the provided XML files,
    and it will be used as the source directory for all the deployment types.
.PARAMETER Bitness
    Provides the desired architecture for the deployment types. All of the XML will be updated with this value.
    'x86', 'x64'
.PARAMETER VisioLicense
    Allows you to select the license type which you are licensed for. This will be either 'Online' or 'Volume'
    Note that if 'Volume' is selected, you will see that Visio 2016 as well as 2019 deployment types are created, and have requirements
    for Windows 7 or 8/8.1 attached to them. Visio 2019 deployment types are targeted at Windows 10.
.PARAMETER ProjectLicense
    Allows you to select the license type which you are licensed for. This will be either 'Online' or 'Volume'
    Note that if 'Volume' is selected, you will see that Project 2016 as well as 2019 deployment types are created, and have requirements
    for Windows 7 or 8/8.1 attached to them. Project 2019 deployment types are targeted at Windows 10.
.PARAMETER UpdateChannel
    Provides the desired Update Channel for the deployment types. All of the XML will be updated with this value.
    'Semi-Annual', 'Semi-AnnualTargeted', 'Monthly', 'MonthlyTargeted'
.PARAMETER Version
    Provides the desired Version for the Office 365 installation. All of the XML will be updated with this value.
    By default, we attempt to gather the latest deployed patch version based on the Update Channel selected.
.PARAMETER AllowCdnFallback
    A boolean value that will be set in the XML files. This will allow your clients to fallback to the Content Delivery Network (CDN)
    aka 'the cloud.'
.PARAMETER DisplayLevel
    Provides the desired display level for the Office 365 installer. This can be either 'Full' or 'None. All of the XML will be updated
    with this value. 
.EXAMPLE
    C:\PS> $new365DynamicApp = @{
        SMSProvider         = 'SCCM'
        AppRoot             = '\\sccm\sources\O365-Dynamic'
        ApplicationName     = 'Office 365 - Dynamic'
        VisioLicense        = 'Volume'
        ProjectLicense      = 'Volume'
        Company             = 'Contoso'
        Bitness             = 'x64'
        UpdateChannel       = 'Semi-Annual'
        DisplayLevel        = 'None'
    }
    New-365DynamicApp.ps1 @new365DynamicApp
.EXAMPLE
    C:\PS> $new365DynamicApp = @{
        SMSProvider         = 'SCCM'
        AppRoot             = '\\sccm\sources\O365-Dynamic'
        ApplicationName     = 'Office 365 - Dynamic'
        VisioLicense        = 'Online'
        ProjectLicense      = 'Online'
        Company             = 'Contoso'
        Bitness             = 'x64'
        UpdateChannel       = 'Monthly'
        AllowCdnFallback    = $false
    }
    New-365DynamicApp.ps1 @new365DynamicApp
.EXAMPLE
    C:\PS> $new365DynamicApp = @{
        SMSProvider         = 'SCCM'
        AppRoot             = '\\sccm\sources\O365-Dynamic'
        ApplicationName     = 'Office 365 - Dynamic'
        VisioLicense        = 'Volume'
        ProjectLicense      = 'Online'
        Company             = 'Contoso'
        Bitness             = 'x64'
        UpdateChannel       = 'Monthly'
        AllowCdnFallback    = 'true'
        DisplayLevel        = 'Full'
    }
    New-365DynamicApp.ps1 @new365DynamicApp
.NOTES
    FileName:    New-365DynamicApp.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     2019-05-01
    Updated:     2019-05-02

    It is a good idea to run 'setup.exe /download O365.xml' once. The good news is, every single application combination uses the exact
    same Office 365 binaries. These XML by default do have AllowCdnFallback="True" set, so they will download directly from Microsoft
    if deployed with no binaries, or ones which do not represent the XML.

    This will create an application with quite a few deployment types. These deployment types all revolve around the global conditions
    that get created. It is always a smart idea to test something such as this in your environment before a large scale rollout.
    It has been working great for us, but no two environments are the same. You will need to manipulate the XML files to add
    languages or customs settings if you need those.
#>
[CmdletBinding()]
param(
    [parameter(Mandatory = $true)]
    [string]$SMSProvider,
    [parameter(Mandatory = $true)]
    [string]$ApplicationName,
    [parameter(Mandatory = $true)]
    [string]$Company,
    [parameter(Mandatory = $true)]
    [string]$AppRoot,
    [parameter(Mandatory = $true)]
    [validateset('x86', 'x64')]
    [string]$Bitness,
    [parameter(Mandatory = $true)]
    [validateset('Online', 'Volume')]
    [string]$VisioLicense,
    [parameter(Mandatory = $true)]
    [validateset('Online', 'Volume')]
    [string]$ProjectLicense,
    [parameter(Mandatory = $false)]
    [validateset('Semi-Annual', 'Semi-AnnualTargeted', 'Monthly', 'MonthlyTargeted')]
    [string]$UpdateChannel = 'Semi-Annual',
    [parameter(Mandatory = $false)]
    [string]$Version,
    [parameter(Mandatory = $false)]
    [bool]$AllowCdnFallback = $true,
    [parameter(Mandatory = $false)]
    [validateset('Full', 'None')]
    [string]$DisplayLevel = 'Full'
)
$SiteCode = $(((Get-WmiObject -Namespace "root\sms" -Class "__Namespace" -ComputerName $SMSProvider).Name).substring(8 - 3))
Write-Verbose "Determined SiteCode to be $SiteCode based on an SMS Provider of $SMSProvider"
$SiteCodePath = "$SiteCode`:"
Set-Location -Path C:

#region Gather all the relevant XML files and filter based on the license type
$AllXML_Configs = Get-ChildItem -Path $AppRoot -Filter *.xml
switch ($VisioLicense) {
    'Online' {
        $VisKeepFilter = "`$_.Name -match 'VisOnline'"
        $VisIgnoreFilter = "`$_.Name -notmatch 'VisStd|VisPro'"
    }
    'Volume' {
        $VisKeepFilter = "`$_.Name -match 'VisStd|VisPro'"
        $VisIgnoreFilter = "`$_.Name -notmatch 'VisOnline'"
    }
}
switch ($ProjectLicense) {
    'Online' {
        $PrjKeepFilter = "`$_.Name -match 'PrjOnline'"
        $PrjIgnoreFilter = "`$_.Name -notmatch 'PrjStd|PrjPro'"
    }
    'Volume' {
        $PrjKeepFilter = "`$_.Name -match 'PrjStd|PrjPro'"
        $PrjIgnoreFilter = "`$_.Name -notmatch 'PrjOnline'"
    }
}
$Filter = [string]::Format("({0} -or {1} -or `$_.Name -eq 'O365.xml') -and {2} -and {3}", $VisKeepFilter, $PrjKeepFilter, $VisIgnoreFilter, $PrjIgnoreFilter)
$FilteredXML_Configs = $AllXML_Configs | Where-Object { & ([scriptblock]::Create($Filter)) }
foreach ($File in $FilteredXML_Configs) {
    Write-Verbose "$($File.Name) selected based on [VisioLicense=$VisioLicense] [ProjectLicense=$ProjectLicense]"
}
#endregion Gather all the relevant XML files and filter based on the license type

#region create global conditions if they don't exist and find OS GC
#region GC Office Product function
function Get-CMOfficeGlobalCondition {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [validateset('Project Professional', 'Project Standard', 'Project', 'Visio Professional', 'Visio Standard', 'Visio')]
        [string]$Application
    )
    $GC_Name = [string]::Format('Condition Detection - Microsoft {0}', $Application)

    switch ($Application) {
        'Project Professional' {
            $MSI_App = 'PRJPRO'
            $C2R_App = 'PROJECTPRO'
        }
        'Project Standard' {
            $MSI_App = 'PRJSTD'
            $C2R_App = 'PROJECTSTD'
        }
        'Project' {
            if (-not ($GC = Get-CMGlobalCondition -Name $GC_Name)) {
                Write-Warning "Global condition not found: Creating GC '$GC_Name'"
                $ruleProjPro = Get-CMOfficeGlobalCondition -Application 'Project Professional' | New-CMRequirementRuleBooleanValue -Value $true
                $ruleProjStd = Get-CMOfficeGlobalCondition -Application 'Project Standard' | New-CMRequirementRuleBooleanValue -Value $true
                $expressionProject = New-CMRequirementRuleExpression -AddRequirementRule $ruleProjPro, $ruleProjStd -ClauseOperator Or
                $GC = New-CMGlobalConditionExpression -Name $GC_Name -DeviceType Windows -RootExpression $expressionProject
            }
            else {
                Write-Verbose "Using existing Global Condition with name $($GC.LocalizedDisplayName)"
            }

            return $GC
        }
        'Visio Professional' {
            $MSI_App = 'VISPRO'
            $C2R_App = 'VISIOPRO'
        }
        'Visio Standard' {
            $MSI_App = 'VISSTD'
            $C2R_App = 'VISIOSTD'
        }
        'Visio' {
            if (-not ($GC = Get-CMGlobalCondition -Name $GC_Name)) {
                Write-Warning "Global condition not found: Creating GC '$GC_Name'"
                $ruleVisPro = Get-CMOfficeGlobalCondition -Application 'Visio Professional' | New-CMRequirementRuleBooleanValue -Value $true
                $ruleVisStd = Get-CMOfficeGlobalCondition -Application 'Visio Standard' | New-CMRequirementRuleBooleanValue -Value $true
                $expressionVisio = New-CMRequirementRuleExpression -AddRequirementRule $ruleVisPro, $ruleVisStd -ClauseOperator Or
                $GC = New-CMGlobalConditionExpression -Name $GC_Name -DeviceType Windows -RootExpression $expressionVisio
            }
            else {
                Write-Verbose "Using existing Global Condition with name $($GC.LocalizedDisplayName)"
            }

            return $GC
        }
    }

    $GC_Script = @"
    `$MSI_App = '$MSI_App'
    `$C2R_App = '$C2R_App'
    `$RegMSIx86Uninstall = Get-ChildItem -Path 'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
    `$RegMSIx64Uninstall = Get-ChildItem -Path 'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
    `$RegC2R = Get-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration
    `$MSIx86 = `$RegMSIx86Uninstall | Where-Object { `$_.PSChildName -match "^OFFICE[0-9]{2}\.`$MSI_App`$" }
    `$MSIx64 = `$RegMSIx64Uninstall | Where-Object { `$_.PSChildName -match "^OFFICE[0-9]{2}\.`$MSI_App`$" }
    `$C2R = `$RegC2R | Where-Object { `$_.ProductReleaseIDs -match `$C2R_App }
    if (`$MSIx86 -or `$MSIx64 -or `$C2R) {
        `$true
    }
    else {
        `$false
    }
"@

    if (-not ($GC = Get-CMGlobalCondition -Name $GC_Name)) {
        Write-Warning "Global condition not found: Creating GC '$GC_Name'"
        $GC = New-CMGlobalConditionScript -DataType Boolean -ScriptText $GC_Script -ScriptLanguage PowerShell -Name $GC_Name
    }
    else {
        Write-Verbose "Using existing Global Condition with name $($GC.LocalizedDisplayName)"
    }

    return $GC
}
#endregion GC Office Product function

Set-Location -Path $SiteCodePath
Write-Output $('-' * 50)
Write-Output "Identifying and creating global conditions as needed for detection of Visio/Project Pro/Standard"
$VisStandard_GC = Get-CMOfficeGlobalCondition -Application 'Visio Standard'
$VisPro_GC = Get-CMOfficeGlobalCondition -Application 'Visio Professional'
$Vis_GC = Get-CMOfficeGlobalCondition -Application Visio
$ProjPro_GC = Get-CMOfficeGlobalCondition -Application 'Project Professional'
$ProjStandard_GC = Get-CMOfficeGlobalCondition -Application 'Project Standard'
$Proj_GC = Get-CMOfficeGlobalCondition -Application Project
$OS_GC = Get-CMGlobalCondition -Name 'Operating System' | Where-Object { $_.ModelName -eq 'GLOBAL/OperatingSystem' }
Write-Output "All global conditions identified or created"
#endregion create global conditions if they don't exist and find OS GC

#region create our requirements for use in the DeploymentTypes
Write-Output $('-' * 50)
Write-Output "Creating CMRequirementRules that can be applied to deployment types based on our global conditions"
$2016_Rule = $OS_GC | New-CMRequirementRuleOperatingSystemValue -PlatformString Windows/All_x64_Windows_7_Client, Windows/All_x64_Windows_8_Client, Windows/All_x64_Windows_8.1_Client -RuleOperator OneOf
$2019_Rule = $OS_GC | New-CMRequirementRuleOperatingSystemValue -PlatformString Windows/All_x64_Windows_10_and_higher_Clients -RuleOperator OneOf
$VisStandard_Rule = $VisStandard_GC | New-CMRequirementRuleBooleanValue -Value $true
$VisPro_Rule = $VisPro_GC | New-CMRequirementRuleBooleanValue -Value $true
$Vis_Rule = $Vis_GC | New-CMRequirementRuleBooleanValue -Value $true
$ProjStandard_Rule = $ProjStandard_GC | New-CMRequirementRuleBooleanValue -Value $true
$ProjPro_Rule = $ProjPro_GC | New-CMRequirementRuleBooleanValue -Value $true
$Proj_Rule = $Proj_GC | New-CMRequirementRuleBooleanValue -Value $true
Write-Output "CMRequirementRules created"
#endregion create our requirements for use in the DeploymentTypes

#region parse all XML and return custom object with info we need, and sort the list, also update company and bitness in XML
Set-Location -Path C:
#region generate variable for XML friendly bitness
$XML_Bitness = switch ($Bitness) {
    'x86' {
        '32'
    }
    'x64' {
        '64'
    }
}
#endregion generate variable for XML friendly bitness

#region determine version based on deployed update, or from input parameter
switch ($UpdateChannel) {
    'Semi-Annual' {
        $Channel = 'Semi-Annual Channel'
        $XML_Channel = 'Broad'
    }
    'Semi-AnnualTargeted' {
        $Channel = 'Semi-Annual Channel (Targeted)'
        $XML_Channel = 'Targeted'
    }
    'Monthly' {
        $Channel = 'Monthly Channel'
        $XML_Channel = $_
    }
    'MonthlyTargeted' {
        $Channel = 'Monthly Channel (Targeted)'
        $XML_Channel = 'Insiders'
    }
}
Write-Verbose "Based on input paramater [UpdateChannel=$UpdateChannel] a value of [Channel=$XML_Channel] will be used for all XML"

if (-not $PSBoundParameters.ContainsKey('Version')) {
    Write-Output $('-' * 50)
    Write-Output "Based on input paramater [UpdateChannel=$UpdateChannel] a value of [Channel=$Channel] will be used to search SCCM for the latest deployed O365 update"
    $getWmiObjectSplat = @{
        Query        = "SELECT LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName LIKE 'Office 365 Client Update - $Channel%$Bitness%' AND IsDeployed = '1' AND IsLatest = '1'"
        ComputerName = $SMSProvider
        Namespace    = "root\sms\site_$SiteCode"
    }
    $365Patches = Get-WmiObject @getWmiObjectSplat | Select-Object -ExpandProperty LocalizedDisplayName
    if ($365Patches.Count -gt 0) {
        $Regex = "\(Build ([0-9]+\.[0-9]+)\)"
        [double[]]$Builds = foreach ($Value in $365Patches) {
            [regex]::Match($Value, $Regex).Groups[1].Value
        }
        $LatestBuild = ($Builds | Sort-Object | Select-Object -Last 1).ToString()
        $FullBuildNumber = [string]::Format('16.0.{0}', $LatestBuild)
        Write-Output "Identified O365 [Version=$FullBuildNumber] as the latest deployed version for [Channel=$Channel] - This value will be used to update all XML"
    }
    else {
        Write-Error -Message "Failed to identify Office 365 version based on the input. This likely means you are not deploying updates for the specified architecture and update channel." -ErrorAction Stop
    }
}
else {
    $FullBuildNumber = $Version
    Write-Verbose "[Version=$FullBuildNumber] will be used based on input parameter."
}
#endregion determine version based on deployed updates, or from input parameter

#region generate PSCustomObject that we will loop through to create DeploymentTypes
$DeploymentTypes = foreach ($XML in $FilteredXML_Configs) {
    #region Load XML and manipulate based on input parameters, and gather information
    $Config = $XML.Name
    $ConfigXML = [xml]::new()
    $ConfigXML.PreserveWhitespace = $true
    $ConfigXML.Load($XML.FullName)
    $ConfigXML.Configuration.AppSettings.Setup.Value = $Company
    $ConfigXML.Configuration.Add.OfficeClientEdition = $XML_Bitness
    $ConfigXML.Configuration.Add.Version = $FullBuildNumber
    $ConfigXML.Configuration.Add.Channel = $XML_Channel
    $ConfigXml.Configuration.Add.AllowCdnFallback = "$($AllowCdnFallback | Out-String)"
    $ConfigXml.Configuration.Display.Level = $DisplayLevel
    $ConfigXML.Save($XML.FullName)
    $AppName = $ConfigXML.Configuration.Info.Description
    $ProductIDs = $ConfigXML.Configuration.Add.Product.ID
    #endregion Load XML and manipulate based on input parameters, and gather information

    [PSCustomObject]@{
        Config     = $Config
        AppName    = $AppName
        AppSource  = $AppRoot
        ProductIDs = $ProductIDs
        NameLength = $($AppName.Length)
    }
}

# We sort the deployment types so that the priority order ensures proper installation depending on existing apps
$DeploymentTypes = $DeploymentTypes | Sort-Object -Property NameLength, AppName -Descending
#endregion generate PSCustomObject that we will loop through to create DeploymentTypes
#endregion parse all XML and return custom object with info we need, and sort the list, also update company and bitness in XML

#region application and DeploymentType creation
try {
    Set-Location -Path $SiteCodePath
    #region application creation
    Write-Output $('-' * 50)
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
    $BaseApp = New-CMApplication @newCMApplicationSplat
    Write-Output "Successfully created Application [Name=$ApplicationName]"
    Write-Output $('-' * 50)
    #endregion application creation

    #region DeploymentType creation
    Write-Output "Beginning the creation of appropriate deployment types"
    Write-Output $('-' * 50)
    foreach ($DT in $DeploymentTypes) {
        Set-Location -Path $SiteCodePath

        #region generate Detection Clauses for the DeploymentType
        $DetectionClauses = [System.Collections.ArrayList]::new()
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
            ExpectedValue      = $($Bitness)
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
        #endregion generate Detection Clauses for the DeploymentType

        #region determine which Requirements we need to add for this deployment type based on ProductIDs
        $Requirements = [System.Collections.ArrayList]::new()
        switch -Regex ($DT.ProductIDs) {
            '^VisioPro(X|2019)Volume$' {
                $null = $Requirements.Add($VisPro_Rule)
            }
            '^VisioStd(X|2019)Volume$' {
                $null = $Requirements.Add($VisStandard_Rule)
            }
            '^VisioProRetail$' {
                $null = $Requirements.Add($Vis_Rule)
            }
            '^ProjectPro(X|2019)Volume$' {
                $null = $Requirements.Add($ProjPro_Rule)
            }
            '^ProjectStd(X|2019)Volume$' {
                $null = $Requirements.Add($ProjStandard_Rule)
            }
            '^ProjectProRetail$' {
                $null = $Requirements.Add($Proj_Rule)
            }
        }

        switch -Regex ($DT.ProductIDs) {
            '2019' {
                $null = $Requirements.Add($2019_Rule)
                break
            }
            'XVolume' {
                $null = $Requirements.Add($2016_Rule)
                break
            }
        }

        $addCMScriptDeploymentTypeSplat.AddRequirement = $Requirements
        #endregion determine which Requirements we need to add for this deployment type based on ProductIDs

        try {
            $null = Add-CMScriptDeploymentType @addCMScriptDeploymentTypeSplat
            [PSCustomObject]@{
                DeploymentType = $DT.AppName
                Config         = $DT.Config
                Architecture   = $Bitness
            }
        }
        catch {
            $_
            Write-Error -Message "Failed to create DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($Bitness)]"
        }
    }
    Write-Output $('-' * 50)
    Write-Output "Deployment type creation completed"
    #endregion DeploymentType creation

    #region cleanup revision from creating deployment types
    Write-Output $('-' * 50)
    Write-Output "Removing revision history caused by app generation"
    try {
        Get-CMApplicationRevisionHistory -Name $ApplicationName | Where-Object { -not $_.IsLatest } | Remove-CMApplicationRevisionHistory -Force -ErrorAction Stop
        Write-Output "All unneeded application revisions removed"
    }
    catch {
        Write-Warning "Application revision history cleanup failed. Consider manual cleanup."
    }
    Write-Output $('-' * 50)
    #endregion cleanup revision from creating deployment types
}
catch {
    $_
    Write-Error -Message "Failed to create Application [Name=$ApplicationName]"
}
#endregion application and DeploymentType creation