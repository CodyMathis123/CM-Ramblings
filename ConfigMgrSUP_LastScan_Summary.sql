Select v_R_System.name0 as 'Name'
        , v_R_System.ResourceID
       , v_RA_System_ResourceNames.Resource_Names0 as 'FQDN'
       , v_R_System.Resource_Domain_OR_Workgr0 as 'DOMAIN'
       , v_GS_OPERATING_SYSTEM.Caption0 as 'Operating System'
       , v_UpdateScanStatus.LastScanTime
       , v_UpdateScanStatus.LastErrorCode
       , v_GS_WORKSTATION_STATUS.LastHWScan as 'Last Hardware Scan'
       ,  CASE v_UpdateScanStatus.LastScanState
              When '0' THEN 'SCAN STATE UNKNOWN'
              when '1' THEN 'Scan is waiting for catalog location'
              when '2' then 'Scan is running'
              when '3' then 'Scan is completed'
              when '4' then 'Scan is pending retry' 
              when '5' then 'Scan failed'
              when '6' then 'Scan completed with errors'
              else 'broken'
         end as 'Last Scan State'
from v_R_System
full join v_RA_System_ResourceNames on v_R_System.ResourceID = v_RA_System_ResourceNames.ResourceID
Full join v_UpdateScanStatus on v_R_System.ResourceID = v_UpdateScanStatus.ResourceID
full join v_GS_WORKSTATION_STATUS on v_R_System.ResourceID = v_GS_WORKSTATION_STATUS.ResourceID
Full Join v_GS_OPERATING_SYSTEM on v_R_System.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
