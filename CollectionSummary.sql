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
