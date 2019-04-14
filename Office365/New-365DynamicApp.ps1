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
    [string]$Bitness
)
$SiteCodePath = "$(((Get-WmiObject -namespace "root\sms" -class "__Namespace" -ComputerName $SMSProvider).Name).substring(8 - 3)):"
Set-Location -Path C:
$AllXML_Options = Get-ChildItem -Path $AppRoot -Filter *.xml

#region create global conditions if they don't exist and find OS GC
#region GC Office Product function
function New-GCOfficeProductScript {
    param (
        [parameter(Mandatory = $true)]
        [validateset('ProjectPro', 'ProjectStandard', 'VisioPro', 'VisioStandard')]
        [string]$Application,
        [parameter(Mandatory = $true)]
        [validateset('x86', 'x64')]
        [string]$Bitness
    )
    switch ($Application) {
        'ProjectPro' {
            $MSI_App = 'PRJPRO'
            $C2R_App = 'PROJECTPRO'
        }
        'ProjectStandard' {
            $MSI_App = 'PRJSTD'
            $C2R_App = 'PROJECTSTD'
        }
        'VisioPro' {
            $MSI_App = 'VISPRO'
            $C2R_App = 'VISIOPRO'
        }
        'VisioStandard' {
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

    @"
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
}
#endregion GC Office Product function

$PrjProScript = New-GCOfficeProductScript -Application ProjectPro -Bitness $Bitness
$PrjStdScript = New-GCOfficeProductScript -Application ProjectStandard -Bitness $Bitness
$VisProScript = New-GCOfficeProductScript -Application VisioPro -Bitness $Bitness
$VisStdScript = New-GCOfficeProductScript -Application VisioStandard -Bitness $Bitness

Set-Location -Path $SiteCodePath
$PrjProGC_Name = "Condition Detection - Microsoft Project Pro $Bitness"
if (-not ($ProjPro_GC = Get-CMGlobalCondition -Name $PrjProGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$PrjProGC_Name'"
    $ProjPro_GC = New-CMGlobalConditionScript -DataType Boolean -ScriptText $PrjProScript -ScriptLanguage PowerShell -Name $PrjProGC_Name
}
$PrjStdGC_Name = "Condition Detection - Microsoft Project Standard $Bitness"
if (-not ($ProjStandard_GC = Get-CMGlobalCondition -Name $PrjStdGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$PrjStdGC_Name'"
    $ProjStandard_GC = New-CMGlobalConditionScript -DataType Boolean -ScriptText $PrjStdScript -ScriptLanguage PowerShell -Name $PrjStdGC_Name
}
$VisProGC_Name = "Condition Detection - Microsoft Visio Pro $Bitness"
if (-not ($VisPro_GC = Get-CMGlobalCondition -Name $VisProGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$VisProGC_Name'"
    $VisPro_GC = New-CMGlobalConditionScript -DataType Boolean -ScriptText $VisProScript -ScriptLanguage PowerShell -Name $VisProGC_Name
}
$VisStdGC_Name = "Condition Detection - Microsoft Visio Standard $Bitness"
if (-not ($VisStandard_GC = Get-CMGlobalCondition -Name $VisStdGC_Name)) {
    Write-Warning "Global condition not found: Creating GC '$VisStdGC_Name'"
    $VisStandard_GC = New-CMGlobalConditionScript -DataType Boolean -ScriptText $VisStdScript -ScriptLanguage PowerShell -Name $VisStdGC_Name
}
$OS_GC = Get-CMGlobalCondition -Name 'Operating System' | Where-Object { $_.ModelName -eq 'GLOBAL/OperatingSystem' }
#endregion create global conditions if they don't exist and find OS GC

#region create our requirements for use in the DeploymentTypes
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
#region generate variable for XML friendly bitness

#region generate PSCustomObject that we will loop through to create DeploymentTypes
$DeploymentTypes = foreach ($XML in $AllXML_Options) {
    $Config = $XML.Name
    $ConfigXML = [xml]$(Get-Content -Path $XML.FullName)
    $ConfigXML.Configuration.AppSettings.Setup.Value = $Company
    $ConfigXML.Configuration.Add.OfficeClientEdition = $XML_Bitness
    Set-Content -Path $XML.FullName -Value $ConfigXml.OuterXml -Force
    $AppName = $ConfigXML.Configuration.Info.Description
    $ProductIDs = $ConfigXML.Configuration.Add.Product.ID

    [PSCustomObject]@{
        Config     = $Config
        AppName    = $AppName
        AppSource  = $AppRoot
        ProductIDs = $ProductIDs
        NameLength = $($AppName.Length)
    }
}

# We sort the deployment types so that the priority order ensures proper installation
$DeploymentTypes = $DeploymentTypes | Sort-Object -Property NameLength, AppName -Descending

#endregion generate PSCustomObject that we will loop through to create DeploymentTypes
#endregion parse all XML and return custom object with info we need, and sort the list, also update company and bitness in XML

try {
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
    $BaseApp = New-CMApplication @newCMApplicationSplat
    Write-Output "Successfully created Application [Name=$ApplicationName]"
    foreach ($DT in $DeploymentTypes) {
        Write-Output $('-' * 50)
        Write-Output "Creating DeploymentType [Name=$($DT.AppName)] using [Config=$($DT.Config)] with [Architecture=$($Bitness)]"
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

        #region determine which Requirements we need to add for this deployment type based on ProductIDs
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

        $addCMScriptDeploymentTypeSplat.AddRequirement = $Requirements | Select-Object -Unique
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
}
catch {
    $_
    Write-Error -Message "Failed to create Application [Name=$ApplicationName]"
}
