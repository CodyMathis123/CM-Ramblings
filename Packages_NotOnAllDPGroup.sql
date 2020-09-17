DECLARE @allDPgroupID uniqueidentifier  = (SELECT TOP 1 GroupID FROM v_SMS_DistributionPointGroup ORDER BY membercount DESC)
DECLARE @allDPgroupMemberCount int  = (SELECT TOP 1 MemberCount FROM v_SMS_DistributionPointGroup ORDER BY membercount DESC)

SELECT DISTINCT dpgp.PkgID
	, p.packagetype
	, bycount.TargeteddDPCount
	FROM v_DPGroupPackages dpgp
JOIN v_package p ON p.packageid = dpgp.PkgID
JOIN (
	SELECT cdss.pkgid
		, cdss.TargeteddDPCount 
	FROM v_ContDistStatSummary cdss
	WHERE TargeteddDPCount not in (@allDPgroupMemberCount,0)
 ) bycount ON bycount.PkgID = dpgp.PkgID
WHERE p.packageid not in (
	SELECT DISTINCT PkgID
	FROM v_DPGroupPackages 
	WHERE groupid = @allDPgroupID
)
