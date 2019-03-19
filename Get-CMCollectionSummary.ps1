function Get-CMCollectionSummary {
    [CmdletBinding(DefaultParameterSetName = "__AllParameterSets")]
    #Requires -Modules DBATools
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SQLServer,
        [parameter(Mandatory = $true, Position = 1)]
        [string]$Database
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

        #region Generate dynamic parameters
        $Position = 2
        foreach ($Var in @('CollectionID', 'CollectionName', 'LimitToCollectionID', 'LimitToCollectionName')) {
            $newDynamicParamSplat = @{
                Position         = $Position++
                HelpMessage      = "Filter collection summary results by the $Var field"
                ParameterSetName = [string]::Format('FilterBy{0}', $Var)
                DPDictionary     = $Dictionary
                Mandatory        = $true
                Type             = [string[]]
                ValidateSet      = $(@($CollectionInfo.$Var) | Where-Object { if ($null -ne $PSItem) {
                            $PSItem.ToString().Trim() 
                        }} | Select-Object -Unique)
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
                Position     = $Position++
                HelpMessage  = "Filter collection summary results based on $Var being `$true or `$false"
                DPDictionary = $Dictionary
                Mandatory    = $false
                Type         = [bool]
                Name         = $Var
            }
            New-DynamicParam @newDynamicParamSplat
        }
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'WithNoDeployments'
            Type         = [switch]
            HelpMessage  = "Return all collections which have no deployments"
        }
        New-DynamicParam @newDynamicParamSplat
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'Unused'
            Type         = [switch]
            HelpMessage  = "Return all collections which have no deployments, and are not included in, ecluded from, or limiting other collecitons"
        }
        New-DynamicParam @newDynamicParamSplat
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'Empty'
            Type         = [switch]
            HelpMessage  = "Returns all collections with 0 members"
        }
        New-DynamicParam @newDynamicParamSplat

        $RefreshTypeValidationSet = @('Any Incremental', 'Periodic Updates Only', 'Non-Recurring Schedule'
            , 'Non-Recurring Schedule and Incremental', 'Manual Updates Only'
            , 'Incremental and Periodic Updates', 'Incremental Updates Only')
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'RefreshType'
            Type         = [string[]]
            ValidateSet  = $RefreshTypeValidationSet
        }
        New-DynamicParam @newDynamicParamSplat

        $MWTypeValidationSet = @('General', 'Updates', 'OSD')
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'MWType'
            Type         = [string[]]
            ValidateSet  = $MWTypeValidationSet
        }
        New-DynamicParam @newDynamicParamSplat
        #endregion Generate dynamic parameters
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

        #region function Get-CollectionWhereFilter - Generate a where filter, either IN (<array>) or = 'InputData'
        function Get-CollectionWhereFilter {
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
        #endregion function Get-CollectionWhereFilter - Generate a where filter, either IN (<array>) or = 'InputData'

        #region generate WHERE filter for SQL
        $WhereFilter = switch ($PsBoundParameters.Keys) {
            'CollectionID' {
                Get-CollectionWhereFilter -InputData $CollectionID -ColumnName SiteID
            }
            'CollectionName' {
                Get-CollectionWhereFilter -InputData $CollectionName -ColumnName $PSItem
            }
            'LimitToCollectionID' {
                Get-CollectionWhereFilter -InputData $LimitToCollectionID -ColumnName $PSItem
            }
            'LimitToCollectionName' {
                Get-CollectionWhereFilter -InputData $LimitToCollectionName -ColumnName $PSItem
            }
            'RefreshType' {
                $RefreshTypeFilters = foreach ($RefreshType in (Get-Variable -Name $PSItem -ValueOnly)) {
                    switch ($RefreshType) {
                        'Any Incremental' {
                            "OR (col.RefreshType IN ('4','6'))"
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
            'MWType' {
                $MWTypeFilters = foreach ($MWType in (Get-Variable -Name $PSItem -ValueOnly)) {
                    switch ($MWType) {
                        'General' {
                            "OR mw.ServiceWindowType = 1"
                        }
                        'Updates' {
                            "OR mw.ServiceWindowType = 4"
                        }
                        'OSD' {
                            "OR mw.ServiceWindowType = 5"
                        }
                    }
                }
                [string]::Format("AND ({0})", ($($MWTypeFilters -join "`n").Trim().TrimStart('OR')))
            }
            'HasAppDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfAppDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfAppDeployments = 0"
                }
            }
            'HasBaselineDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfBaselineDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfBaselineDeployments = 0"
                }
            }
            'HasPackageDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfPackageDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfPackageDeployments = 0"
                }
            }
            'HasPolicyDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfPolicyDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfPolicyDeployments = 0"
                }
            }
            'HasTaskSequenceDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfTSDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfTSDeployments = 0"
                }
            }
            'HasUpdateDeployment' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldeploy.CountOfUpdateDeployments > 0"
                }
                else {
                    "AND coldeploy.CountOfUpdateDeployments = 0"
                }
            }
            'MW_Enabled' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND mw.Enabled = 1"
                }
                else {
                    "AND mw.Enabled = 0"
                }
            }
            'HasExcludes' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldep.CountOfExcludes > 0"
                }
                else {
                    "AND coldep.CountOfExcludes = 0"
                }
            }
            'HasIncludes' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldep.CountOfIncludes > 0"
                }
                else {
                    "AND coldep.CountOfIncludes = 0"
                }
            }
            'UsedAsExclude' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldep.CountOfExcludedFrom > 0"
                }
                else {
                    "AND coldep.CountOfExcludedFrom = 0"
                }
            }
            'UsedAsInclude' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldep.CountOfIncludedIn > 0"
                }
                else {
                    "AND coldep.CountOfIncludedIn = 0"
                }
            }
            'UsedAsLimitingCollection' {
                if (Get-Variable -Name $PSItem -ValueOnly) {
                    "AND coldep.CountOfLimitedBy > 0"
                }
                else {
                    "AND coldep.CountOfLimitedBy = 0"
                }
            }
            default {
                switch ($true) {
                    $WithNoDeployments {
                        @"
                        AND CountOfAppDeployments = 0
                        AND CountOfPackageDeployments = 0
                        AND CountOfUpdateDeployments = 0
                        AND CountOfBaselineDeployments = 0
                        AND CountOfTSDeployments = 0
                        AND CountOfPolicyDeployments = 0
"@
                    }
                    $Unused {
                        @"
                        AND CountOfAppDeployments = 0
                        AND CountOfPackageDeployments = 0
                        AND CountOfUpdateDeployments = 0
                        AND CountOfBaselineDeployments = 0
                        AND CountOfTSDeployments = 0
                        AND CountOfPolicyDeployments = 0
                        AND mw.ServiceWindowType IS NULL
                        AND CountOfExcludedFrom = 0
                        AND CountOfIncludedIn = 0
                        AND CountOfLimitedBy = 0
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
        SELECT colref.SiteID AS CollectionID
        , MAX(EvaluationLength) AS EvaluationLength
        , MAX(IncrementalEvaluationLength) AS IncrementalEvaluationLength
        INTO #colrefresh
        FROM [dbo].[v_Collections] as colref
            LEFT JOIN [dbo].[Collections_L] col ON col.CollectionID = colref.CollectionID
        GROUP BY colref.SiteID
        
        SELECT CAST(col.SiteID AS varchar) AS CollectionID
        , SUM(CASE WHEN coldep.DependentCollectionID = col.SiteID AND coldep.RelationshipType = 3 THEN 1 ELSE 0 END) AS CountOfExcludes
        , SUM(CASE WHEN coldep.DependentCollectionID = col.SiteID AND coldep.RelationshipType = 2 THEN 1 ELSE 0 END) AS CountOfIncludes
        , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 3 THEN 1 ELSE 0 END) AS CountOfExcludedFrom
        , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 2 THEN 1 ELSE 0 END) AS CountOfIncludedIn
        , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 1 THEN 1 ELSE 0 END) AS CountOfLimitedBy
        INTO #coldep
        FROM [dbo].[v_Collections] as col
            LEFT JOIN [dbo].[vSMS_CollectionDependencies] coldep ON (coldep.DependentCollectionID = col.SiteID OR coldep.SourceCollectionID = col.SiteID)
        GROUP BY col.SiteID
        
        SELECT col.SiteID AS CollectionID
        , SUM(CASE WHEN FeatureType = 1 THEN 1 ELSE 0 END) AS CountOfAppDeployments
        , SUM(CASE WHEN FeatureType = 2 THEN 1 ELSE 0 END) AS CountOfPackageDeployments
        , SUM(CASE WHEN FeatureType = 5 THEN 1 ELSE 0 END) AS CountOfUpdateDeployments
        , SUM(CASE WHEN FeatureType = 6 THEN 1 ELSE 0 END) AS CountOfBaselineDeployments
        , SUM(CASE WHEN FeatureType = 7 THEN 1 ELSE 0 END) AS CountOfTSDeployments
        , SUM(CASE WHEN deppol.CollectionID IS NOT NULL THEN 1 ELSE 0 END) AS CountOfPolicyDeployments
        INTO #coldeploy
        FROM [dbo].[v_Collections] as col
            LEFT JOIN [dbo].[vDeploymentSummary] deployments on deployments.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vSMS_ClientSettingsAssignments] deppol ON deppol.CollectionID = col.SiteID
        GROUP BY col.SiteID
        
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
        , coldep.CountOfExcludes
        , coldep.CountOfExcludedFrom
        , coldep.CountOfIncludes
        , coldep.CountOfIncludedIn
        , coldep.CountOfLimitedBy
        , coldeploy.CountOfAppDeployments
        , coldeploy.CountOfPackageDeployments
        , coldeploy.CountOfUpdateDeployments
        , coldeploy.CountOfBaselineDeployments
        , coldeploy.CountOfTSDeployments
        , coldeploy.CountOfPolicyDeployments
        , mw.Name AS 'MW Name'
        , mw.Description AS 'MW Description'
        , mw.Schedules AS 'MW ScheduleString'
        , mw.StartTime AS 'MW StartTime'
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
        END AS 'MW Recurrence Type'
        , mw.Enabled AS 'MW Enabled'
        , mw.UseGMTTimes AS 'MW IsGMT'
        , col.LimitToCollectionName
        , col.LimitToCollectionID
        , col.LastMemberChangeTime
        FROM [dbo].[v_Collections] AS col
            LEFT JOIN [dbo].[vSMS_ClientSettingsAssignments] clients ON clients.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vDeploymentSummary] deploys ON deploys.CollectionID = col.SiteID
            LEFT JOIN #coldeploy AS coldeploy ON coldeploy.CollectionID = col.SiteID
            LEFT JOIN #colrefresh AS colrefresh ON colrefresh.CollectionID = col.SiteID
            LEFT JOIN #coldep AS coldep ON coldep.CollectionID = col.SiteID
            LEFT JOIN [dbo].[vSMS_ServiceWindow] mw ON mw.CollectionID = col.CollectionID
            {0}
"@, $WhereFilter)
        Invoke-DBAQuery -SqlInstance $SQLServer -Database $Database -Query $CollectionSummaryQuery
    }
    end {

    }
}
