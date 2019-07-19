#region detection/remediation
#region define variables
$Remediate = $false
$LogFile = "$env:SystemDrive\temp\Set-LedbatWSUS.log"
$Component = switch ($Remediate) {
    $true {
        'Remediation'
    }
    $false {
        'Detection'
    }
}
#endregion define variables

try {
    $WSUS_Server = Get-WsusServer -ErrorAction Stop
}
catch {
}

$PSDefaultParameterValues["New-CMNLogEntry:Component"] = $Component
$PSDefaultParameterValues["New-CMNLogEntry:LogFile"] = $LogFile
New-CMNLogEntry -Entry $('-' * 50) -Type 1
if ($null -ne $WSUS_Server) {
    New-CMNLogEntry -Entry "$env:ComputerName is configured as a WSUS server - will validate Port and LEDBAT Configuration" -Type 1
    $WSUS_Port = $WSUS_Server | Select-Object -ExpandProperty PortNumber
    New-CMNLogEntry -Entry "WSUS Port identified as $WSUS_Port" -Type 1
    try {
        $LEDBAT_Enabled = [bool](Get-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction SilentlyContinue)
        New-CMNLogEntry -Entry "Status of LEDBAT [Enabled=$LEDBAT_Enabled]" -Type 1
        $CustomPortSet = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port -LocalPortEnd $WSUS_Port -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction SilentlyContinue)
        New-CMNLogEntry -Entry "Status of LEDBAT Port [Set=$CustomPortSet]" -Type 1
    }
    catch {
    }
    if ($LEDBAT_Enabled -and $CustomPortSet) {
        New-CMNLogEntry -Entry "LEDBAT for WSUS is configured correctly" -Type 1
        New-CMNLogEntry -Entry $('-' * 50) -Type 1
        return $true
    }
    else {
        if (-not $LEDBAT_Enabled) {
            New-CMNLogEntry -Entry "LEDBAT is not enabled on this machine" -Type 3
            if ($Remediate) {
                New-CMNLogEntry -Entry "Marked for remediation - will enable LEDBAT" -Type 2
                Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction Stop
            }
        }
        if ( -not $CustomPortSet) {
            New-CMNLogEntry -Entry "Custom Port $WSUS_Port is not correctly configured" -Type 3
            if ($Remediate) {
                New-CMNLogEntry -Entry "Marked for remediation - will configure LEDBAT custom port to $WSUS_Port" -Type 2
                New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port -LocalPortEnd $WSUS_Port -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
            }
        }
        New-CMNLogEntry -Entry $('-' * 50) -Type 1
        return $Remediate
    }
}
else {
    New-CMNLogEntry -Entry "This machine is not a WSUS server - exiting" -Type 3
    New-CMNLogEntry -Entry $('-' * 50) -Type 1
    return $false
}
#endregion detection/remediation
