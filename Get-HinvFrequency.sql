SELECT map.DisplayName 
	, map.InvClassName AS 'Inventory View'
	, COUNT(HINV.RecordID) 
FROM HinvChangeLog hinv
	LEFT JOIN v_GroupMap map ON map.GroupID = hinv.GroupKey
GROUP BY map.DisplayName
	, map.InvClassName
ORDER BY 3 DESC
