function Set-CMDistributionPointMaintenanceMode {
    param(
        [parameter(Mandatory = $true)]
        [string]$SMSProvider,
        [parameter(Mandatory = $true)]
        [string]$DistributionPoint,
        [parameter(Mandatory = $true)]
        [ValidateSet('On', 'Off')]
        [string]$MaintenanceMode
    )
    $SiteCode = $(((Get-CimInstance -Namespace "root\sms" -ClassName "__Namespace" -ComputerName $SMSProvider).Name).substring(8 - 3))
    $Namespace = [string]::Format('root\sms\site_{0}', $SiteCode)
    try {
        $Filter = [string]::Format("Name = '{0}'", $DistributionPoint)
        $getCimInstanceSplat = @{
            Filter       = $Filter
            ComputerName = $SMSProvider
            Namespace    = $Namespace
            ClassName    = 'SMS_DistributionPointInfo'
        }
        $DP = Get-CimInstance @getCimInstanceSplat
        if ($null -eq $DP) {
            $Filter = [string]::Format("Name LIKE '{0}%'", $DistributionPoint)
            Write-Warning "Falling back to a wildcard filter [Filter `"$Filter`"]"
            $getCimInstanceSplat['Filter'] = $Filter
            $DP = Get-WmiObject @getCimInstanceSplat
            if ($null -eq $DP) {
                Write-Error "WMI query for a distribution point succeded, but no object was returned. [Filter = `"$Filter`"] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
            }
        }
        Write-Output "Identified Distribution point with [NALPath=$($DP.NALPath)]"
    }
    catch {
        Write-Error "Failed to query for a distribution point with [Filter `"$Filter`"] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
    }

    $Mode = switch ($MaintenanceMode) {
        'On' {
            1
        }
        'Off' {
            0
        }
    }

    try {
        $invokeCimMethodSplat = @{
            ClassName    = 'SMS_DistributionPointInfo'
            ComputerName = $SMSProvider
            Namespace    = $Namespace
            MethodName   = 'SetDPMaintenanceMode'
            Arguments    = @{
                NALPath = $DP.NALPath
                Mode    = [uint32]$Mode
            }
        }
        $Return = Invoke-CimMethod @invokeCimMethodSplat
        if ($Return.ReturnValue -ne 0) {
            Write-Error "Failed to set [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
        }
        elseif ($Return.ReturnValue -eq 0) {
            Write-Output "Set [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode]"
        }
    }
    catch {
        Write-Error "Failed to invoke maintenance mode change for [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
    }
}
