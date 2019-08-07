/*
	This query will show you the count of records per Hardware Inventory class in your HinvChangeLog table.
	This can help you identify a class that is create a lot of hardware inventory 'traffic' and potentially bloating
	your database.
*/
SELECT map.DisplayName 
	, map.InvClassName AS 'Inventory View'
	, COUNT(HINV.RecordID)
FROM HinvChangeLog hinv
    LEFT JOIN v_GroupMap map ON map.GroupID = hinv.GroupKey
GROUP BY map.DisplayName
	, map.InvClassName
ORDER BY 3 DESC
