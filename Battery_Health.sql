SELECT DISTINCT s.Netbios_Name0
       , os.InstallDate0
       , csp.Version0
       , csp.Name0
       , cycle.CycleCount0
       , batcapac.FullChargedCapacity0
       , batstat.DesignedCapacity0
       , CASE
              WHEN batcapac.FullChargedCapacity0 <= batstat.DesignedCapacity0 THEN CAST((100 * batcapac.FullChargedCapacity0 / batstat.DesignedCapacity0) AS FLOAT)
              ELSE 100
       END AS [BatteryHealth]
       , cycle.InstanceName0
       , bat.Name0 AS [BatteryName]
       , bat.DesignVoltage0
       , bat.Status0
       , portbat.Location0
       , portbat.Manufacturer0
FROM v_R_System_Valid s
       JOIN v_GS_OPERATING_SYSTEM os ON os.ResourceID = s.ResourceID
       JOIN v_GS_COMPUTER_SYSTEM_PRODUCT csp ON csp.ResourceID = s.ResourceID
       JOIN v_GS_BATTERYCYCLECOUNT cycle ON cycle.ResourceID = s.ResourceID
       JOIN v_GS_BATTERYSTATICDATA batstat ON batstat.ResourceID = s.ResourceID AND batstat.InstanceName0 = cycle.InstanceName0
       JOIN v_GS_BATTERYFULLCHARGEDCAPACI batcapac ON batcapac.ResourceID = s.ResourceID AND batcapac.InstanceName0 = cycle.InstanceName0
       LEFT JOIN v_GS_BATTERY bat ON bat.ResourceID = s.ResourceID AND bat.Name0 = batstat.DeviceName0
       LEFT JOIN v_GS_PORTABLE_BATTERY portbat ON portbat.ResourceID = s.ResourceID AND portbat.Name0 = batstat.DeviceName0
ORDER BY 1
