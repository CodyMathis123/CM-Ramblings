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
function Get-CMOfficeGlobalCondition {
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

    return $GC

}
#endregion GC Office Product function

Set-Location -Path $SiteCodePath
$VisStandard_GC = Get-CMOfficeGlobalCondition -Application 'Visio Standard' -Bitness $Bitness
$VisPro_GC = Get-CMOfficeGlobalCondition -Application 'Visio Professional' -Bitness $Bitness
$ProjPro_GC = Get-CMOfficeGlobalCondition -Application 'Project Professional' -Bitness $Bitness
$ProjStandard_GC = Get-CMOfficeGlobalCondition -Application 'Project Standard' -Bitness $Bitness
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
#endregion generate variable for XML friendly bitness

#region generate PSCustomObject that we will loop through to create DeploymentTypes
$DeploymentTypes = foreach ($XML in $AllXML_Options) {
    $Config = $XML.Name
    $ConfigXML = [xml]::new()
    $ConfigXML.PreserveWhitespace = $true
    $ConfigXML.Load($XML.FullName)
    $ConfigXML.Configuration.AppSettings.Setup.Value = $Company
    $ConfigXML.Configuration.Add.OfficeClientEdition = $XML_Bitness
    $ConfigXML.Save($XML.FullName)
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
