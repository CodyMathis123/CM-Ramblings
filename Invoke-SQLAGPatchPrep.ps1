param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Drain', 'Resume')]
    [string]$Purpose = 'Resume'
)
$AvailabilityGroups = Get-DbaAvailabilityGroup -SqlInstance $env:COMPUTERNAME
foreach ($AG in $AvailabilityGroups) {
    $DatabaseName = $AG.AvailabilityDatabases.Name
    $AGName = $AG.AvailabilityGroup
    $AGListener = $AG.AvailabilityGroupListeners.Name
    $PrimaryNode = $AG.PrimaryReplica

    $CheckAG = @"
		SELECT name AS [AGname]
			, replica_server_name AS [ServerName]
			, CASE
				WHEN replica_server_name=ag.primary_replica THEN 'PRIMARY'
				ELSE 'SECONDARY'
			END AS [Status]
			, synchronization_health_desc AS [SynchronizationHealth]
			, failover_mode_desc AS [FailoverMode]
			, availability_mode AS [Synchronous]
			, secondary_role_allow_connections_desc [ReadableSecondary]
		FROM sys.availability_replicas r
			INNER JOIN sys.availability_groups g ON r.group_id = g.group_id
			LEFT JOIN master.sys.dm_hadr_availability_group_states ag ON r.group_id = ag.group_id
"@


    switch ($Purpose) {
        'Drain' {
            try {
                $StartStateAG = Invoke-DbaQuery -SqlInstance $AGListener -Query $CheckAG -ErrorAction Stop
                $SecondaryNode = $StartStateAG | Where-Object { $_.Status -eq 'SECONDARY' } | Select-Object -ExpandProperty ServerName
            }
            catch {
                Write-Error 'Failed to query for Availability Group status'
                exit 1
            }

            switch ($StartStateAG.SynchronizationHealth) {
                'HEALTHY' {
                    continue;
                }
                default {
                    Write-Error 'At least one node has unhealthy SynchronizationHealth'
                    exit 1
                }
            }
        
            switch ($StartStateAG) {
                { $_.FailoverMode -ne 'MANUAL' } {
                    Set-DbaAgReplica -SqlInstance $PrimaryNode -AvailabilityGroup $_.AGname -Replica $_.ServerName -FailoverMode Manual
                }
            }

            switch ($PrimaryNode -eq $env:COMPUTERNAME) {
                $true {
                    Invoke-DbaAgFailover -SqlInstance $SecondaryNode -AvailabilityGroup $AGName -Force
                }
            }

            Suspend-DbaAgDbDataMovement -SqlInstance $env:COMPUTERNAME -AvailabilityGroup $AGName -Database $DatabaseName -Confirm:$false

            $ClusterStatus = Get-ClusterNode -Name $env:COMPUTERNAME
            switch ($ClusterStatus.State) {
                'Up' {
                    Suspend-ClusterNode -Wait -Drain
                }
            }
        }
        'Resume' {
            $PrimaryNode = $AG.PrimaryReplica
            $ClusterStatus = Get-ClusterNode -Name $env:COMPUTERNAME
            switch ($ClusterStatus.State) {
                'Up' {
                    continue
                }
                default {
                    Resume-ClusterNode -Name $env:COMPUTERNAME
                }
            }
            foreach ($Node in $AG.AvailabilityReplicas.Name) {
                Set-DbaAgReplica -SqlInstance $PrimaryNode -AvailabilityGroup $AG.AvailabilityGroup -Replica $Node -FailoverMode Automatic
            }

            Resume-DbaAgDbDataMovement -SqlInstance $env:COMPUTERNAME -AvailabilityGroup $AG.AvailabilityGroup -Database $AG.AvailabilityDatabases.Name -Confirm:$false
        }
    }
}