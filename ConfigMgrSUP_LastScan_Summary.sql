SELECT s.Netbios_Name0 AS 'Name'
	, s.ResourceID
	, srn.Resource_Names0 AS 'FQDN'
	, s.Resource_Domain_OR_Workgr0 AS 'DOMAIN'
	, v_GS_OPERATING_SYSTEM.Caption0 AS 'Operating System'
	, sn.StateDescription AS 'LastScanState'
	, scan.LastScanTime
	, scan.LastErrorCode
	, scan. LastScanPackageLocation
	, wsStatus.LastHWScan AS 'Last Hardware Scan'	
FROM v_R_System s
JOIN v_RA_System_ResourceNames srn ON s.ResourceID = srn.ResourceID
JOIN v_UpdateScanStatus scan ON s.ResourceID = scan.ResourceID
JOIN v_GS_WORKSTATION_STATUS wsStatus ON s.ResourceID = wsStatus.ResourceID
JOIN v_GS_OPERATING_SYSTEM ON s.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
JOIN v_StateNames sn ON sn.StateID = scan.LastScanState AND sn.TopicType = 501