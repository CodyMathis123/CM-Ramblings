<#
.SYNOPSIS
    Allows you to toggle maintenance mode on a distribution point
.DESCRIPTION
    This function allows you to select a distribution point and set whether the 'Maintenance Mode' feature introduced in ConfigMgr 1902
        is toggled on or off.
.PARAMETER SMSProvider
    Define the SMS Provider which the WMI queries will execute against.
.PARAMETER DistributionPoint
    Provides the Distribution Point which you want to change the maintenance mode of. This should be provided as a FQDN,
        but if you provide the shortname we will also attempt a search with a wildcard.
.PARAMETER MaintenanceMode
    The desired state of of Maintenance Mode for the distribution point. This is either 'On' or 'Off'
.EXAMPLE
    C:\PS> Set-CMDistributionPointMaintenanceMode -SMSProvider SCCM.CONTOSO.COM -DistributionPoint DP.CONTOSO.COM -MaintenanceMode On
.NOTES
    The account you run this as must have the proper permissions to perform the maintenance mode action
#>
function Set-CMDistributionPointMaintenanceMode {
    [CmdletBinding(SupportsShouldProcess = $true)]
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
        Write-Verbose "Identified Distribution point with [NALPath=$($DP.NALPath)]"
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
        if ($PSCmdlet.ShouldProcess($DistributionPoint, "MaintenanceMode $MaintenanceMode")) {
            $Return = Invoke-CimMethod @invokeCimMethodSplat
            if ($Return.ReturnValue -ne 0) {
                Write-Error "Failed to set [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
            }
            elseif ($Return.ReturnValue -eq 0) {
                Write-Verbose "Set [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode]"
            }
        }
    }
    catch {
        Write-Error "Failed to invoke maintenance mode change for [DistributionPoint=$DistributionPoint] [MaintenanceMode=$MaintenanceMode] against [SMSProvider=$SMSProvider]" -ErrorAction Stop
    }
}
