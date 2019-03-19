IF OBJECT_ID('tempdb..#colrefresh') IS NOT NULL DROP TABLE #colrefresh
GO
SELECT colref.SiteID AS CollectionID
, MAX(EvaluationLength) AS EvaluationLength
, MAX(IncrementalEvaluationLength) AS IncrementalEvaluationLength
INTO #colrefresh
FROM [dbo].[v_Collections] as colref
    LEFT JOIN [dbo].[Collections_L] col ON col.CollectionID = colref.CollectionID
GROUP BY colref.SiteID

IF OBJECT_ID('tempdb..#coldep') IS NOT NULL DROP TABLE #coldep
GO
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

IF OBJECT_ID('tempdb..#coldeploy') IS NOT NULL DROP TABLE #coldeploy
GO
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
, CASE WHEN coldeploy.CountOfAppDeployments >= 0 THEN coldeploy.CountOfAppDeployments ELSE 0 END AS CountOfAppDeployments
, CASE WHEN coldeploy.CountOfPackageDeployments >= 0 THEN coldeploy.CountOfPackageDeployments ELSE 0 END AS CountOfPackageDeployments
, CASE WHEN coldeploy.CountOfUpdateDeployments >= 0 THEN coldeploy.CountOfUpdateDeployments ELSE 0 END AS CountOfUpdateDeployments
, CASE WHEN coldeploy.CountOfBaselineDeployments >= 0 THEN coldeploy.CountOfBaselineDeployments ELSE 0 END AS CountOfBaselineDeployments
, CASE WHEN coldeploy.CountOfTSDeployments >= 0 THEN coldeploy.CountOfTSDeployments ELSE 0 END AS CountOfTSDeployments
, CASE WHEN coldeploy.CountOfPolicyDeployments >= 0 THEN coldeploy.CountOfPolicyDeployments ELSE 0 END AS CountOfPolicyDeployments
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
