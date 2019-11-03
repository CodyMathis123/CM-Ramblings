#region detection/remediation
#region define variables
$Remediate = $false
#endregion define variables

try {
    $WSUS_Server = Get-WsusServer -ErrorAction Stop
    switch ($WSUS_Server -is [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]) {
        $true {
            $WSUS_Port = $WSUS_Server | Select-Object -ExpandProperty PortNumber
            try {
                $LEDBAT_Enabled = [bool](Get-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction Stop)
                $CustomPortSet = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port -LocalPortEnd $WSUS_Port -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop)
            }
            catch {
                return $false
            }
            switch ($LEDBAT_Enabled -and $CustomPortSet) {
                $true {
                    return $true
                }
                $false {
                    switch ($LEDBAT_Enabled) {
                        $false {
                            switch ($Remediate) {
                                $true {
                                    try {
                                        Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction Stop
                                    }
                                    catch {
                                        return $false
                                    }
                                }
                            }
                        }
                    }
                    switch ($CustomPortSet) {
                        $false {
                            switch ($Remediate) {
                                $true {
                                    try {
                                        New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port -LocalPortEnd $WSUS_Port -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
                                    }
                                    catch {
                                        return $false
                                    }
                                }
                            }
                        }
                    }
                    return $Remediate
                }
            }
        }
        $false {
            return $true
        }
    }    
}
catch {
    return $false
}
#endregion detection/remediation