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
    Note that if 'Volume' is selected, you will see that Visio 2016 deployment types are created, and have requirements
    for Windows 7 or 8/8.1 attached to them. Visio 2019 deployment types are targeted at Windows 10.
.PARAMETER ProjectLicense
    Allows you to select the license type which you are licensed for. This will be either 'Online' or 'Volume'
    Note that if 'Volume' is selected, you will see that Project 2016 deployment types are created, and have requirements
    for Windows 7 or 8/8.1 attached to them. Project 2019 deployment types are targeted at Windows 10.
.PARAMETER UpdateChannel
    Provides the desired Update Channel for the deployment types. All of the XML will be updated with this value. 
    'Semi-Annual', 'Semi-AnnualTargeted', 'Monthly', 'MonthlyTargeted'
.PARAMETER Version
    Provides the desired Version for the Office 365 installation. All of the XML will be updated with this value.
    By default, we attempt to gather the latest deployed patch version based on the Update Channel selected. 
.EXAMPLE
    C:\PS> $new365DynamicApp = @{
        SMSProvider     = 'SCCM'
        AppRoot         = '\\sccm\sources\O365-Dynamic'
        ApplicationName = 'Office 365 - Dynamic'
        VisioLicense    = 'Volume'
        ProjectLicense  = 'Volume'
        Company         = 'Contoso'
        Bitness         = 'x64'
        UpdateChannel   = 'Semi-Annual'
    }
    New-365DynamicApp.ps1 @new365DynamicApp
.EXAMPLE
    C:\PS> $new365DynamicApp = @{
        SMSProvider     = 'SCCM'
        AppRoot         = '\\sccm\sources\O365-Dynamic'
        ApplicationName = 'Office 365 - Dynamic'
        VisioLicense    = 'Online'
        ProjectLicense  = 'Online'
        Company         = 'Contoso'
        Bitness         = 'x64'
        UpdateChannel   = 'Monthly'
    }
    New-365DynamicApp.ps1 @new365DynamicApp
.NOTES
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
    [string]$Version
)
$SiteCode = $(((Get-WmiObject -namespace "root\sms" -class "__Namespace" -ComputerName $SMSProvider).Name).substring(8 - 3))
Write-Verbose "Determined SiteCode to be $SiteCode based on an SMS Provider of $SMSProvider"
$SiteCodePath = "$SiteCode`:"
Set-Location -Path C:
$AllXML_Options = Get-ChildItem -Path $AppRoot -Filter *.xml

#region create global conditions if they don't exist and find OS GC
#region GC Office Product function
function Get-CMOfficeGlobalCondition {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [validateset('Project Professional', 'Project Standard', 'Visio Professional', 'Visio Standard')]
        [string]$Application,
        [parameter(Mandatory = $true)]
        [validateset('x86', 'x64')]
        [string]$Bitness
    )
    switch ($Application) {
        'Project Professional' {
            $MSI_App = 'PRJPRO'
            $C2R_App = 'PROJECTPRO'
        }
        'Project Standard' {
            $MSI_App = 'PRJSTD'
            $C2R_App = 'PROJECTSTD'
        }
        'Visio Professional' {
            $MSI_App = 'VISPRO'
            $C2R_App = 'VISIOPRO'
        }
        'Visio Standard' {
            $MSI_App = 'VISSTD'
            $C2R_App = 'VISIOSTD'
        }
    }
    $GC_RegPath = switch ($Bitness) {
        'x86' {
            'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        }
        'x64' {
            'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
        }
    }

    $GC_Name = [string]::Format('Condition Detection - Microsoft {0} {1}', $Application, $Bitness)

    $GC_Script = @"
    `$MSI_App = '$MSI_App'
    `$C2R_App = '$C2R_App'
    `$RegMSIUninstall = Get-ChildItem -Path $GC_RegPath
    `$RegC2R = Get-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\ClickToRun\Configuration
    `$MSI = `$RegMSIUninstall | Where-Object { `$_.PSChildName -match "^OFFICE[0-9]{2}\.`$MSI_App`$" }
    `$C2R = `$RegC2R | Where-Object { `$_.ProductReleaseIDs -match `$C2R_App -and `$_.Platform -eq '$Bitness' }
    if (`$MSI -or `$C2R) {
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
Write-Verbose "Identifying and creating global conditions as needed for detection of Visio / Project Pro / Standard"
$VisStandard_GC = Get-CMOfficeGlobalCondition -Application 'Visio Standard' -Bitness $Bitness
$VisPro_GC = Get-CMOfficeGlobalCondition -Application 'Visio Professional' -Bitness $Bitness
$ProjPro_GC = Get-CMOfficeGlobalCondition -Application 'Project Professional' -Bitness $Bitness
$ProjStandard_GC = Get-CMOfficeGlobalCondition -Application 'Project Standard' -Bitness $Bitness
$OS_GC = Get-CMGlobalCondition -Name 'Operating System' | Where-Object { $_.ModelName -eq 'GLOBAL/OperatingSystem' }
#endregion create global conditions if they don't exist and find OS GC

#region create our requirements for use in the DeploymentTypes
Write-Verbose "Creating CMRequirementRules that can be applied to deployment types based on our global conditions"
$2016_Rule = $OS_GC | New-CMRequirementRuleOperatingSystemValue -PlatformString Windows/All_x64_Windows_7_Client, Windows/All_x64_Windows_8_Client, Windows/All_x64_Windows_8.1_Client -RuleOperator OneOf
$2019_Rule = $OS_GC | New-CMRequirementRuleOperatingSystemValue -PlatformString Windows/All_x64_Windows_10_and_higher_Clients -RuleOperator OneOf
$VisStandard_Rule = $VisStandard_GC | New-CMRequirementRuleBooleanValue -Value $true
$VisPro_Rule = $VisPro_GC | New-CMRequirementRuleBooleanValue -Value $true
$ProjStandard_Rule = $ProjStandard_GC | New-CMRequirementRuleBooleanValue -Value $true
$ProjPro_Rule = $ProjPro_GC | New-CMRequirementRuleBooleanValue -Value $true
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
    Write-Verbose "Based on input paramater [UpdateChannel=$UpdateChannel] a value of [Channel=$Channel] will be used to search SCCM for the latest deployed O365 update"
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
        Write-Verbose "Identified O365 [Version=$FullBuildNumber] as the latest deployed version for [Channel=$Channel] - This value will be used to update all XML"
    }
    else {
        Write-Error -Message "Failed to identify Office 365 version based on the input." -ErrorAction Stop
    }
}
else {
    $FullBuildNumber = $Version
    Write-Verbose "[Version=$FullBuildNumber] will be used based on input parameter."
}
#endregion determine version based on deployed updates, or from input parameter

#region generate PSCustomObject that we will loop through to create DeploymentTypes
$DeploymentTypes = foreach ($XML in $AllXML_Options) {
    #region Load XML and manipulate based on input parameters, and gather information
    $Config = $XML.Name
    $ConfigXML = [xml]::new()
    $ConfigXML.PreserveWhitespace = $true
    $ConfigXML.Load($XML.FullName)
    $ConfigXML.Configuration.AppSettings.Setup.Value = $Company
    $ConfigXML.Configuration.Add.OfficeClientEdition = $XML_Bitness
    $ConfigXML.Configuration.Add.Version = $FullBuildNumber
    $ConfigXML.Configuration.Add.Channel = $XML_Channel
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
    #endregion application creation

    #region DeploymentType creation
    foreach ($DT in $DeploymentTypes) {
        Set-Location -Path $SiteCodePath
        Write-Output $('-' * 50)
        Write-Output "Creating DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($Bitness)]"

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
            'VisioPro' {
                $null = $Requirements.Add($VisPro_Rule)
            }
            'VisioStd' {
                $null = $Requirements.Add($VisStandard_Rule)
            }
            'ProjectPro' {
                $null = $Requirements.Add($ProjPro_Rule)
            }
            'ProjectStd' {
                $null = $Requirements.Add($ProjStandard_Rule)
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
            Write-Output "Successfully created DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($Bitness)]"
        }
        catch {
            $_
            Write-Error -Message "Failed to create DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($Bitness)]"
        }
        Write-Output $('-' * 50)
    }
    #endregion DeploymentType creation
}
catch {
    $_
    Write-Error -Message "Failed to create Application [Name=$ApplicationName]"
}
#endregion application and DeploymentType creation
