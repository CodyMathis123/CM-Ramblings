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
        $CollectionInfo = Invoke-DBAQuery -SqlInstance $SQLServer -Database $Database -Query $RBAC_CollectionQuery -ErrorAction SilentlyContinue
        #endregion RBAC enforced query to retrieve CollectionID and CollectionName

        #region Generate dynamic parameters
        $Position = 2
        foreach ($Var in @('CollectionID', 'CollectionName', 'LimitToCollectionID', 'LimitToCollectionName')) {
            $Set = $(@($CollectionInfo.$Var) | Where-Object { if ($null -ne $PSItem) {
                        $PSItem.ToString().Trim()
                    } } | Select-Object -Unique)
            $newDynamicParamSplat = @{
                Position         = $Position++
                DPDictionary     = $Dictionary
                ParameterSetName = [string]::Format('FilterBy{0}', $Var)
                Mandatory        = $true
                Name             = $Var
                Type             = [string[]]
                ValidateSet      = $Set
                HelpMessage      = "Filter collection summary results by the $Var field"
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
                DPDictionary = $Dictionary
                Name         = $Var
                Type         = [bool]
                HelpMessage  = "Filter collection summary results based on $Var being `$true or `$false"
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
            HelpMessage  = "Return all collections which have no deployments, and are not included in, excluded from, or limiting other collections"
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
            HelpMessage  = "Return only collections which have the specified collection refresh type(s)"
        }
        New-DynamicParam @newDynamicParamSplat

        $MWTypeValidationSet = @('General', 'Updates', 'OSD')
        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'MWType'
            Type         = [string[]]
            ValidateSet  = $MWTypeValidationSet
            HelpMessage  = "Return only collections which have the specified MW type(s)"
        }
        New-DynamicParam @newDynamicParamSplat

        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'GenerateWhereFilter'
            Type         = [switch]
        }
        New-DynamicParam @newDynamicParamSplat

        $newDynamicParamSplat = @{
            DPDictionary = $Dictionary
            Position     = $Position++
            Name         = 'GenerateFilter'
            Type         = [switch]
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
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfAppDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfAppDeployments = 0"
                    }
                }
            }
            'HasBaselineDeployment' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfBaselineDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfBaselineDeployments = 0"
                    }
                }
            }
            'HasPackageDeployment' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfPackageDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfPackageDeployments = 0"
                    }
                }
            }
            'HasPolicyDeployment' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfPolicyDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfPolicyDeployments = 0"
                    }
                }
            }
            'HasTaskSequenceDeployment' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfTSDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfTSDeployments = 0"
                    }
                }
            }
            'HasUpdateDeployment' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldeploy.CountOfUpdateDeployments > 0"
                    }
                    $false {
                        "AND coldeploy.CountOfUpdateDeployments = 0"
                    }
                }
            }
            'MW_Enabled' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND mw.Enabled = 1"
                    }
                    $false {
                        "AND mw.Enabled = 0"
                    }
                }
            }
            'HasExcludes' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldep.CountOfExcludes > 0"
                    }
                    $false {
                        "AND coldep.CountOfExcludes = 0"
                    }
                }
            }
            'HasIncludes' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldep.CountOfIncludes > 0"
                    }
                    $false {
                        "AND coldep.CountOfIncludes = 0"
                    }
                }
            }
            'UsedAsExclude' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldep.CountOfExcludedFrom > 0"
                    }
                    $false {
                        "AND coldep.CountOfExcludedFrom = 0"
                    }
                }
            }
            'UsedAsInclude' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldep.CountOfIncludedIn > 0"
                    }
                    $false {
                        "AND coldep.CountOfIncludedIn = 0"
                    }
                }
            }
            'UsedAsLimitingCollection' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND coldep.CountOfLimitedBy > 0"
                    }
                    $false {
                        "AND coldep.CountOfLimitedBy = 0"
                    }
                }
            }
            'WithNoDeployments' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        @"
                        AND CountOfAppDeployments = 0
                        AND CountOfPackageDeployments = 0
                        AND CountOfUpdateDeployments = 0
                        AND CountOfBaselineDeployments = 0
                        AND CountOfTSDeployments = 0
                        AND CountOfPolicyDeployments = 0
"@
                    }
                }
            }
            'Unused' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
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
                        AND LEFT(col.SiteID,3) != 'SMS'
"@
                    }
                }
            }
            'Empty' {
                switch (Get-Variable -Name $PSItem -ValueOnly) {
                    $true {
                        "AND col.MemberCount = 0"
                    }
                }
            }
            default {
                [string]::Empty
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($WhereFilter)) {
            $WhereFilter = [string]::Format("WHERE{0}", $($WhereFilter -join "`n").Trim().TrimStart('AND'))
        }
        #endregion generate WHERE filter for SQL
    }
    process {
        $CollectionSummaryQuery = [string]::Format(@"
DECLARE @CollectionPath TABLE
		(
	CollectionID varchar(8)
	,
	CollectionPath varchar(MAX)
		)
INSERT INTO @CollectionPath
	(CollectionID, CollectionPath)
SELECT col.SiteID AS 'Collection ID'
	, f.FolderPath AS [CollectionPath]
FROM [dbo].[v_Collections] col
INNER JOIN FolderMembers fm ON fm.InstanceKey = col.SiteID
INNER JOIN folders f ON f.ContainerNodeID = fm.ContainerNodeID

DECLARE @StateMessages TABLE
		(
	CollectionID varchar(8)
	,
	CreatedBy varchar(50)
	,
	Created datetime
		)
INSERT INTO @StateMessages
	(CollectionID, CreatedBy, Created)
SELECT smwis.InsString2 [CollectionID]
	, smwis.InsString1 [CreatedBy]
	, smsgs.Time [Created]
FROM v_StatMsgWithInsStrings smwis
LEFT JOIN v_StatusMessage smsgs ON smsgs.RecordID = smwis.RecordID
WHERE smsgs.MessageID = 30015

DECLARE @ColRefresh TABLE
        (
    CollectionID varchar(8),
    EvaluationLength int,
    IncrementalEvaluationLength int
        ) 
INSERT INTO @ColRefresh
    (CollectionID, EvaluationLength, IncrementalEvaluationLength)
SELECT col.SiteID AS CollectionID
    , MAX(EvaluationLength) AS EvaluationLength
    , MAX(IncrementalEvaluationLength) AS IncrementalEvaluationLength
FROM [dbo].[v_Collections] as col
    LEFT JOIN [dbo].[Collections_L] colref ON colref.CollectionID = col.CollectionID 
GROUP BY col.SiteID
DECLARE @ColDependencies TABLE
        (
    CollectionID varchar(8)
    ,
    CountOfExcludes int
    ,
    CountOfIncludes int
    ,
    CountOfExcludedFrom int
    ,
    CountOfIncludedIn int
    ,
    CountOfLimitedBy int
        )
INSERT INTO @ColDependencies
    (CollectionID, CountOfExcludes, CountOfIncludes, CountOfExcludedFrom, CountOfIncludedIn, CountOfLimitedBy)
SELECT CAST(col.SiteID AS varchar) AS CollectionID
    , SUM(CASE WHEN coldep.DependentCollectionID = col.SiteID AND coldep.RelationshipType = 3 THEN 1 ELSE 0 END) AS CountOfExcludes
    , SUM(CASE WHEN coldep.DependentCollectionID = col.SiteID AND coldep.RelationshipType = 2 THEN 1 ELSE 0 END) AS CountOfIncludes
    , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 3 THEN 1 ELSE 0 END) AS CountOfExcludedFrom
    , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 2 THEN 1 ELSE 0 END) AS CountOfIncludedIn
    , SUM(CASE WHEN coldep.SourceCollectionID = col.SiteID AND coldep.RelationshipType = 1 THEN 1 ELSE 0 END) AS CountOfLimitedBy
FROM [dbo].[v_Collections] as col
    LEFT JOIN [dbo].[vSMS_CollectionDependencies] coldep ON (coldep.DependentCollectionID = col.SiteID OR coldep.SourceCollectionID = col.SiteID)
GROUP BY col.SiteID
DECLARE @ColDeployments TABLE
(
    CollectionID varchar(8)
    ,
    CountOfAppDeployments int
    ,
    CountOfPackageDeployments int
    ,
    CountOfUpdateDeployments int
    ,
    CountOfBaselineDeployments int
    ,
    CountOfTSDeployments int
    ,
    CountOfPolicyDeployments int
)
INSERT INTO @ColDeployments
    (CollectionID, CountOfAppDeployments, CountOfPackageDeployments, CountOfUpdateDeployments, CountOfBaselineDeployments, CountOfTSDeployments, CountOfPolicyDeployments)
SELECT col.SiteID AS CollectionID
, SUM(CASE WHEN FeatureType = 1 THEN 1 ELSE 0 END) AS CountOfAppDeployments
, SUM(CASE WHEN FeatureType = 2 THEN 1 ELSE 0 END) AS CountOfPackageDeployments
, SUM(CASE WHEN FeatureType = 5 THEN 1 ELSE 0 END) AS CountOfUpdateDeployments
, SUM(CASE WHEN FeatureType = 6 THEN 1 ELSE 0 END) AS CountOfBaselineDeployments
, SUM(CASE WHEN FeatureType = 7 THEN 1 ELSE 0 END) AS CountOfTSDeployments
, SUM(CASE WHEN deppol.CollectionID IS NOT NULL THEN 1 ELSE 0 END) OVER (PARTITION BY deppol.ClientSettingsID, deppol.CollectionID) AS CountOfPolicyDeployments
FROM [dbo].[v_Collections] as col
    LEFT JOIN [dbo].[vDeploymentSummary] deployments on deployments.CollectionID = col.SiteID
    LEFT JOIN [dbo].[vSMS_ClientSettingsAssignments] deppol ON deppol.CollectionID = col.SiteID
GROUP BY col.SiteID, deppol.ClientSettingsID, deppol.CollectionID
SELECT DISTINCT col.CollectionName
    , col.SiteID AS CollectionID
	, colpath.CollectionPath
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
	, statmsg.CreatedBy
	, statmsg.Created
	FROM [dbo].[v_Collections] AS col
		LEFT JOIN [dbo].[vSMS_ServiceWindow] mw ON mw.CollectionID = col.CollectionID
		LEFT JOIN @ColDeployments AS coldeploy ON coldeploy.CollectionID = col.SiteID
		LEFT JOIN @ColRefresh AS colrefresh ON colrefresh.CollectionID = col.SiteID
		LEFT JOIN @ColDependencies AS coldep ON coldep.CollectionID = col.SiteID
		LEFT JOIN @StateMessages AS statmsg ON statmsg.CollectionID = col.SiteID
		LEFT JOIN @CollectionPath AS colpath ON colpath.CollectionID = col.SiteID
    {0}
"@, $WhereFilter)
        if (-not [string]::IsNullOrWhiteSpace($WhereFilter)) {
            Write-Verbose -Message "[WHERE Filter Generated]`n$WhereFilter"
        }
        else {
            Write-Verbose -Message "No WHERE Filter Generated"
        }
        switch($true) {
            $GenerateWhereFilter {
                $WhereFilter
            }
            $GenerateFilter {
                $CollectionSummaryQuery
            }
            default {
                Invoke-DBAQuery -SqlInstance $SQLServer -Database $Database -Query $CollectionSummaryQuery
            }
        }
    }
}