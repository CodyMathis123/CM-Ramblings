function Get-CMCollectionSummary {
    <#
    .SYNOPSIS
        Gets a summary of information for specified collection(s)
    .DESCRIPTION
        Provides a large list of attributes for collections. Leverages DynamicParam to allow tab completion for filters.

        Note: Current Help implementation in PowerShell does not allow both Dynamic Parameter help and Comment based help.
            As an alternative, I'm populating this information in the Description area.

        DYNAMIC PARAMETERS
            -CollectionID <string[]>
                Filter the summary based on CollectionID - Dynamic Parameter that will validate on your existing Collections

                Required?                    false
                Accept pipeline input?       false
                Parameter set name           FilterByCollectionID
                Aliases                      None
                Dynamic?                     true

            -CollectionName <string[]>
                Filter the summary based on CollectionName - Dynamic Parameter that will validate on your existing Collections

                Required?                    false
                Accept pipeline input?       false
                Parameter set name           FilterByCollectionName
                Aliases                      None
                Dynamic?                     true

            -LimitToCollectionID <string[]>
                Filter the summary based on LimitToCollectionID, which would return all collections limited by the specified CollectionID

                Required?                    false
                Accept pipeline input?       false
                Parameter set name           FilterByLimitingCollectionID
                Aliases                      None
                Dynamic?                     true

            -LimitToCollectionName <string[]>
                Filter the summary based on LimitToCollectionName, which would return all collections limited by the specified CollectionName

                Required?                    false
                Accept pipeline input?       false
                Parameter set name           FilterByLimitingCollectionName
                Aliases                      None
                Dynamic?                     true
    .EXAMPLE
        C:\PS> Get-CMCollectionSummary -SQLServer LAB-SCCM01 -Database CM_LAB -LimitToCollectionName 'All Systems'
            Returns a summary for all collections limited by 'All Systems'
    .NOTES
        Initial DynamicParam load can take a second as it has to connect to SQL. Subsequent runs are much faster.
    #>
    [CmdletBinding(DefaultParameterSetName = "__AllParameterSets")]
    #Requires -Modules DBATools
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SQLServer,
        [parameter(Mandatory = $true, Position = 1)]
        [string]$Database,
        [parameter(Mandatory = $false)]
        [switch]$WithNoDeployments,
        [parameter(Mandatory = $false)]
        [switch]$Unused,
        [parameter(Mandatory = $false)]
        [switch]$Empty,
        [parameter(Mandatory = $false)]
        [ValidateSet('Any Incremental', 'Periodic Updates Only', 'Non-Recurring Schedule'
            , 'Non-Recurring Schedule and Incremental', 'Manual Updates Only'
            , 'Incremental and Periodic Updates', 'Incremental Updates Only')]
        [string[]]$RefreshType
    )
    DynamicParam {
        #region function New-DynamicParam - All credit to RamblingCookieMonster (https://github.com/RamblingCookieMonster/PowerShell/blob/master/New-DynamicParam.ps1)
        function New-DynamicParam {
            param (

                [string]$Name,
                [System.Type]$Type = [string],
                [string[]]$Alias = @(),
                [string[]]$ValidateSet,
                [switch]$Mandatory,
                [string]$ParameterSetName = "__AllParameterSets",
                [int]$Position,
                [switch]$ValueFromPipelineByPropertyName,
                [string]$HelpMessage,
                [validatescript( {
                        if (-not ($_ -is [System.Management.Automation.RuntimeDefinedParameterDictionary] -or -not $_)) {
                            Throw "DPDictionary must be a System.Management.Automation.RuntimeDefinedParameterDictionary object, or not exist"
                        }
                        $True
                    })]
                $DPDictionary = $false
            )
            #Create attribute object, add attributes, add to collection
            $ParamAttr = New-Object System.Management.Automation.ParameterAttribute
            $ParamAttr.ParameterSetName = $ParameterSetName
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
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            if ($ValidateSet) {
                $ParamOptions = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $ValidateSet
                $AttributeCollection.Add($ParamOptions)
            }
            if ($Alias.count -gt 0) {
                $ParamAlias = New-Object System.Management.Automation.AliasAttribute -ArgumentList $Alias
                $AttributeCollection.Add($ParamAlias)
            }
            $Parameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)
            if ($DPDictionary) {
                $DPDictionary.Add($Name, $Parameter)
            }
            else {
                $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $Dictionary.Add($Name, $Parameter)
                $Dictionary
            }
        }
        #endregion function New-DynamicParam - All credit to RamblingCookieMonster (https://github.com/RamblingCookieMonster/PowerShell/blob/master/New-DynamicParam.ps1)
        $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        #region RBAC enforced query to retrieve CollectionID and CollectionName
        $RBAC_CollectionQuery = @"
declare @SID varbinary(39), @Token nvarchar(max), @UserID nvarchar(max)
SET @SID = SUSER_SID()
Set @Token = 'S-1-5-21-'
+CAST(CAST(CAST(REVERSE(CONVERT(binary(4),'0x'+sys.fn_varbintohexsubstring(0,@SID,13,4),1)) as varbinary(4)) as bigint) as varchar(10))
+'-'+CAST(CAST(CAST(REVERSE(CONVERT(binary(4),'0x'+sys.fn_varbintohexsubstring(0,@SID,17,4),1)) as varbinary(4)) as bigint) as varchar(10))
+'-'+CAST(CAST(CAST(REVERSE(CONVERT(binary(4),'0x'+sys.fn_varbintohexsubstring(0,@SID,21,4),1)) as varbinary(4)) as bigint) as varchar(10))
+'-'+CAST(CAST(CAST(REVERSE(CONVERT(binary(4),'0x'+sys.fn_varbintohexsubstring(0,@SID,25,4),1)) as varbinary(4)) as bigint) as varchar(10))
set @UserID = dbo.fn_rbac_GetAdminIDsfromUserSIDs(@Token)
Select
        cols.SiteID AS CollectionID, cols.CollectionName, cols.LimitToCollectionID, cols.LimitToCollectionName
From
        dbo.fn_rbac_Collections(@UserID) cols
order by
        cols.CollectionName
"@
        $CollectionInfo = Invoke-DBAQuery -SqlInstance $SQLServer -Database $Database -Query $RBAC_CollectionQuery
        #endregion RBAC enforced query to retrieve CollectionID and CollectionName

        #region Generate dynamic parameters, each with their own ParamaterSetName
        foreach ($Var in @('CollectionID', 'CollectionName', 'LimitToCollectionID', 'LimitToCollectionName')) {
            $newDynamicParamSplat = @{
                HelpMessage      = "Filter collection summary results by the $Var field"
                ParameterSetName = [string]::Format('FilterBy{0}', $Var)
                DPDictionary     = $Dictionary
                Mandatory        = $true
                Type             = [string[]]
                ValidateSet      = $($CollectionInfo.$Var | Where-Object { $PSItem.ToString().Trim() } | Select-Object -Unique)
                Name             = $Var
            }
            New-DynamicParam @newDynamicParamSplat
        }

        foreach ($Var in @('HasAppDeployment', 'HasBaselineDeployment'
                , 'HasExcludes', 'HasIncludes'
                , 'HasPackageDeployment', 'HasPolicyDeployment'
                , 'HasTaskSequenceDeployment', 'HasUpdateDeployment'
                , 'MW_Enabled', 'UsedAsExclude'
                , 'UsedAsInclude', 'UsedAsLimitingCollection')) {
            $newDynamicParamSplat = @{
                DPDictionary = $Dictionary
                Mandatory    = $false
                Type         = [bool]
                Name         = $Var
            }
            New-DynamicParam @newDynamicParamSplat
        }
        #endregion Generate dynamic parameters, each with their own ParamaterSetName

        $Dictionary
    }
    begin {
        #region Assign DynamicParam results to variable - All credit to RamblingCookieMonster (https://github.com/RamblingCookieMonster/PowerShell/blob/master/New-DynamicParam.ps1)
        Function _temp {
            [cmdletbinding()]
            param ()
        }
        $BoundKeys = $PSBoundParameters.keys | Where-Object {
            (Get-Command _temp | Select-Object -ExpandProperty parameters).Keys -notcontains $_
        }
        foreach ($param in $BoundKeys) {
            if (-not (Get-Variable -name $param -scope 0 -ErrorAction SilentlyContinue)) {
                New-Variable -Name $Param -Value $PSBoundParameters.$param
                Write-Verbose "Adding variable for dynamic parameter '$param' with value '$($PSBoundParameters.$param)'"
            }
        }
        #endregion Assign DynamicParam results to variable - All credit to RamblingCookieMonster (https://github.com/RamblingCookieMonster/PowerShell/blob/master/New-DynamicParam.ps1)

        #region function Get-WhereFilter - Generate a where filter, either IN (<array>) or = 'InputData'
        function Get-WhereFilter {
            param (
                [string[]]$InputData,
                [string]$ColumnName
            )
            switch ($InputData.Count) {
                {
                    $PSItem -gt 1
                } {
                    $Inputs = $([string]::Format("('{0}')", [string]::Join("','", $InputData)))
                    [string]::Format(@"
AND col.{0} IN {1}
"@, $ColumnName, $Inputs)
                }
                {
                    $PSItem -eq 1
                } {
                    [string]::Format(@"
AND col.{0} = '{1}'
"@, $ColumnName, [string]$InputData)
                }
            }
        }
        #endregion function Get-WhereFilter - Generate a where filter, either IN (<array>) or = 'InputData'

        #region generate WHERE filter for SQL
        $WhereFilter = switch ($PsBoundParameters.Keys) {
            'CollectionID' {
                Get-WhereFilter -InputData $CollectionID -ColumnName SiteID
            }
            'CollectionName' {
                Get-WhereFilter -InputData $CollectionName -ColumnName $PSItem
            }
            'LimitToCollectionID' {
                Get-WhereFilter -InputData $LimitToCollectionID -ColumnName $PSItem
            }
            'LimitToCollectionName' {
                Get-WhereFilter -InputData $LimitToCollectionName -ColumnName $PSItem
            }
            'RefreshType' {
                $RefreshTypeFilters = foreach ($RefreshType in (Get-Variable -Name $PSItem -ValueOnly)) {
                    switch ($RefreshType) {
                        'Any Incremental' {
                            "OR (col.RefreshType IN ('4','6')"
                        }
                        'Periodic Updates Only' {
                            "OR (col.RefreshType = 2)"
                        }
                        'Non-Recurring Schedule' {
                            "OR (col.RefreshType = 2 AND RIGHT(col.Schedule,5) = '80000')"
                        }
                        'Non-Recurring Schedule and Incremental' {
                            "OR (col.RefreshType = 6 AND RIGHT(col.Schedule,5) = '80000')"
                        }
                        'Manual Updates Only' {
                            "OR (col.RefreshType = 1)"
                        }
                        'Incremental and Periodic Updates' {
                            "OR (col.RefreshType = 6)"
                        }
                        'Incremental Updates Only' {
                            "OR (col.RefreshType = 4)"
                        }
                    }
                }
                [string]::Format("AND ({0})", ($($RefreshTypeFilters -join "`n").Trim().TrimStart('OR')))
            }
            'HasAppDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasAppDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasAppDeployment.CollectionID IS NULL"
                }
            }
            'HasBaselineDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasBaselineDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasBaselineDeployment.CollectionID IS NULL"
                }
            }
            'HasExcludes' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasExcludes.DependentCollectionID IS NOT NULL"
                }
                else {
                    "AND HasExcludes.DependentCollectionID IS NULL"
                }
            }
            'HasIncludes' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasIncludes.DependentCollectionID IS NOT NULL"
                }
                else {
                    "AND HasIncludes.DependentCollectionID IS NULL"
                }
            }
            'HasPackageDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasPackageDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasPackageDeployment.CollectionID IS NULL"
                }
            }
            'HasPolicyDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasPolicyDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasPolicyDeployment.CollectionID IS NULL"
                }
            }
            'HasTaskSequenceDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasTaskSequenceDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasTaskSequenceDeployment.CollectionID IS NULL"
                }
            }
            'HasUpdateDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND HasUpdateDeployment.CollectionID IS NOT NULL"
                }
                else {
                    "AND HasUpdateDeployment.CollectionID IS NULL"
                }
            }
            'MW_Enabled' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND mw.ServiceWindowType IS NOT NULL"
                }
                else {
                    "AND mw.ServiceWindowType IS NULL"
                }
            }
            'UsedAsExclude' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND UsedAsExclude.SourceCollectionID IS NOT NULL"
                }
                else {
                    "AND UsedAsExclude.SourceCollectionID IS NULL"
                }
            }
            'UsedAsInclude' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND UsedAsInclude.DependentCollectionID IS NOT NULL"
                }
                else {
                    "AND UsedAsInclude.DependentCollectionID IS NULL"
                }
            }
            'UsedAsLimitingCollection' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND UsedAsLimitingCollection.DependentCollectionID IS NOT NULL"
                }
                else {
                    "AND UsedAsLimitingCollection.DependentCollectionID IS NULL"
                }
            }
            default {
                switch ($true) {
                    $WithNoDeployments {
                        @"
                    AND HasAppDeployment.CollectionID IS NULL
                    AND HasBaselineDeployment.CollectionID IS NULL
                    AND HasPackageDeployment.CollectionID IS NULL
                    AND HasPolicyDeployment.CollectionID IS NULL
                    AND HasTaskSequenceDeployment.CollectionID IS NULL
                    AND HasUpdateDeployment.CollectionID IS NULL
"@
                    }
                    $Unused {
                        @"
                    AND HasAppDeployment.CollectionID IS NULL
                    AND HasBaselineDeployment.CollectionID IS NULL
                    AND HasPackageDeployment.CollectionID IS NULL
                    AND HasPolicyDeployment.CollectionID IS NULL
                    AND HasTaskSequenceDeployment.CollectionID IS NULL
                    AND HasUpdateDeployment.CollectionID IS NULL
                    AND mw.ServiceWindowType IS NULL
                    AND UsedAsExclude.SourceCollectionID IS NULL
                    AND UsedAsInclude.DependentCollectionID IS NULL
                    AND UsedAsLimitingCollection.DependentCollectionID IS NULL
"@
                    }
                    $Empty {
                        "AND col.MemberCount = 0"
                    }
                    default {
                        [string]::Empty
                    }
                }
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($WhereFilter)) {
            $WhereFilter = [string]::Format("WHERE{0}", $($WhereFilter -join "`n").Trim().TrimStart('AND'))
        }
        #endregion generate WHERE filter for SQL
    }
    process {
        $CollectionSummaryQuery = [string]::Format(@"
        SELECT DISTINCT col.CollectionName
        , col.SiteID AS CollectionID
        , col.MemberCount
        , CASE
        WHEN (col.RefreshType = 1) THEN 'Manual Updates Only'
        WHEN (col.RefreshType = 2 AND RIGHT(col.Schedule,5) = '80000') THEN 'Non-Recurring Schedule'
        WHEN (col.RefreshType = 2) THEN 'Periodic Updates Only'
        WHEN (col.RefreshType = 4) THEN 'Incremental Updates Only'
        WHEN (col.RefreshType = 6 AND RIGHT(col.Schedule,5) = '80000') THEN 'Non-Recurring Schedule and Incremental'
        WHEN (col.RefreshType = 6) THEN 'Incremental and Periodic Updates'
        END AS RefreshType
        , col.Schedule AS 'Refresh ScheduleString'
        , (CAST(colrefresh.EvaluationLength AS Float)/1000.00) AS 'FullRefreshLength'
        , CASE
        WHEN (col.RefreshType IN (4,6)) THEN (CAST(colrefresh.IncrementalEvaluationLength AS Float)/1000)
        END AS 'IncrementalRefreshLength'
        , CASE WHEN HasExcludes.DependentCollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasExcludes'
        , STUFF((SELECT ','+ Excludes.SourceCollectionID
            FROM [dbo].[vSMS_CollectionDependencies] Excludes
            WHERE Excludes.DependentCollectionID = col.SiteID and Excludes.RelationshipType = 3
            FOR XML PATH('')),1,1,'') AS 'Excludes'
        , CASE WHEN UsedAsExclude.DependentCollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'UsedAsExclude'
        , STUFF((SELECT ','+ ExcludedFrom.DependentCollectionID
            FROM [dbo].[vSMS_CollectionDependencies] ExcludedFrom
            WHERE ExcludedFrom.SourceCollectionID = col.SiteID and ExcludedFrom.RelationshipType = 3
            FOR XML PATH('')),1,1,'') AS 'ExcludedFrom'
        , CASE WHEN HasIncludes.DependentCollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasIncludes'
        , STUFF((SELECT ','+ Includes.SourceCollectionID
            FROM [dbo].[vSMS_CollectionDependencies] Includes
            WHERE Includes.DependentCollectionID = col.SiteID and Includes.RelationshipType = 2
            FOR XML PATH('')),1,1,'') AS 'Includes'
        , CASE WHEN UsedAsInclude.DependentCollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'UsedAsInclude'
        , STUFF((SELECT ','+ IncludedIn.DependentCollectionID
            FROM [dbo].[vSMS_CollectionDependencies] IncludedIn
            WHERE IncludedIn.SourceCollectionID = col.SiteID and IncludedIn.RelationshipType = 2
            FOR XML PATH('')),1,1,'') AS 'IncludedIn'
        , CASE WHEN UsedAsLimitingCollection.DependentCollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'UsedAsLimitingCollection'
        , STUFF((SELECT ','+ Limits.DependentCollectionID
            FROM [dbo].[vSMS_CollectionDependencies] Limits
            WHERE Limits.SourceCollectionID = col.SiteID and Limits.RelationshipType = 1
            FOR XML PATH('')),1,1,'') AS 'Limits'
        , CASE WHEN HasPolicyDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasPolicyDeployment'
        , CASE WHEN HasAppDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasAppDeployment'
        , CASE WHEN HasPackageDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasPackageDeployment'
        , CASE WHEN HasBaselineDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasBaselineDeployment'
        , CASE WHEN HasTaskSequenceDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasTaskSequenceDeployment'
        , CASE WHEN HasUpdateDeployment.CollectionID IS NOT NULL THEN 1
        ELSE 0
        END AS 'HasUpdateDeployment'
        , mw.Name AS 'MW_Name'
        , mw.Description AS 'MW_Description'
        , mw.Schedules AS 'MW_ScheduleString'
        , mw.StartTime AS 'MW_StartTime'
        , CASE
        WHEN mw.ServiceWindowType = 1	Then 'General'
        WHEN mw.ServiceWindowType = 4	Then 'Updates'
        WHEN mw.ServiceWindowType = 5	Then 'OSD'
        END AS 'MW Type'
        , mw.Duration AS 'MW Duration in Minutes'
        , CASE
        WHEN mw.RecurrenceType = 1 THEN 'None'
        WHEN mw.RecurrenceType = 2 THEN 'Daily'
        WHEN mw.RecurrenceType = 3 THEN 'Weekly'
        WHEN mw.RecurrenceType = 4 THEN 'Monthly By Weekday'
        WHEN mw.RecurrenceType = 5 THEN 'Monthly By Date'
        END AS 'MW_Recurrence Type'
        , mw.Enabled AS 'MW_Enabled'
        , mw.UseGMTTimes AS 'MW_IsGMT'
        , col.LimitToCollectionName
        , col.LimitToCollectionID
        , col.LastMemberChangeTime
        FROM [dbo].[v_Collections] as col
            LEFT JOIN [dbo].[vSMS_ClientSettingsAssignments] clients ON clients.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vDeploymentSummary] deploys ON deploys.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] HasExcludes ON HasExcludes.DependentCollectionID = col.SiteID AND HasExcludes.RelationshipType = 3
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] UsedAsExclude ON UsedAsExclude.SourceCollectionID = col.SiteID AND UsedAsExclude.RelationshipType = 3
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] HasIncludes ON HasIncludes.DependentCollectionID = col.SiteID AND HasIncludes.RelationshipType = 2
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] UsedAsInclude ON UsedAsInclude.SourceCollectionID = col.SiteID AND UsedAsInclude.RelationshipType = 2
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] UsedAsLimitingCollection ON UsedAsLimitingCollection.SourceCollectionID = col.SiteID AND UsedAsLimitingCollection.RelationshipType = 1
            LEFT JOIN [dbo].[vSMS_ClientSettingsAssignments] HasPolicyDeployment ON HasPolicyDeployment.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vDeploymentSummary] HasAppDeployment ON HasAppDeployment.CollectionID = col.SiteID AND HasAppDeployment.FeatureType = 1
            LEFT JOIN [dbo].[vDeploymentSummary] HasPackageDeployment ON HasPackageDeployment.CollectionID = col.SiteID AND HasPackageDeployment.FeatureType = 2
            LEFT JOIN [dbo].[vDeploymentSummary] HasUpdateDeployment ON HasUpdateDeployment.CollectionID = col.SiteID AND HasUpdateDeployment.FeatureType = 5
            LEFT JOIN [dbo].[vDeploymentSummary] HasBaselineDeployment ON HasBaselineDeployment.CollectionID = col.SiteID AND HasBaselineDeployment.FeatureType = 6
            LEFT JOIN [dbo].[vDeploymentSummary] HasTaskSequenceDeployment ON HasTaskSequenceDeployment.CollectionID = col.SiteID AND HasTaskSequenceDeployment.FeatureType = 7
            LEFT JOIN [dbo].[Collections_L] colrefresh ON colrefresh.CollectionID = col.CollectionID
            LEFT JOIN [dbo].[vSMS_ServiceWindow] mw ON mw.CollectionID = col.CollectionID
            {0}
"@, $WhereFilter)
        Invoke-DBAQuery -SqlInstance $SQLServer -Database $Database -Query $CollectionSummaryQuery
    }
    end {

    }
}
