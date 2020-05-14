#region detection/remediation
#region define variables
$Remediate = $false
#endregion define variables

try {
    $WSUS_Server = Get-WsusServer -ErrorAction Stop
}
catch {
    # This is not a WSUS server, or it is in an error state. Return compliant.
    return $true
}

switch ($WSUS_Server -is [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]) {
    $true {
        #region Determine WSUS Port Numbers
        <#
            Note: The script accounts for all custom port scenarios. 
            If WSUS is set to use any custom port other than 80/443 it 
            automatically determines the HTTP as noted in the link below
            https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/2-configure-wsus#configure-ssl-on-the-wsus-server
                ... if you use any port other than 443 for HTTPS traffic, 
                WSUS will send clear HTTP traffic over the port that numerically 
                comes before the port for HTTPS. For example, if you use port 8531 for HTTPS, 
                WSUS will use port 8530 for HTTP.
        #>
        $WSUS_Port1 = $WSUS_Server.PortNumber
        $Wsus_IsSSL = $WSUS_Server.UseSecureConnection

        switch ($Wsus_IsSSL) {
            $true {
                switch ($WSUS_Port1) {
                    443 {
                        $WSUS_Port2 = 80
                    }
                    default {
                        $WSUS_Port2 = $WSUS_Port1 - 1
                    }
                }
            }
            $false {
                $Wsus_Port2 = $null
            }
        }
        #endregion Determine WSUS Port Numbers

        $LEDBAT_Enabled = [bool](Get-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction SilentlyContinue)
        $CustomPort1Set = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port1 -LocalPortEnd $WSUS_Port1 -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction SilentlyContinue)
        if ($null -ne $Wsus_Port2) {
            $CustomPort2Set = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port2 -LocalPortEnd $WSUS_Port2 -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction SilentlyContinue)
        }
        else {
            $CustomPort2Set = $true
        }
        switch ($LEDBAT_Enabled -and $CustomPort1Set -and $CustomPort2Set) {
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
                switch ($CustomPort1Set) {
                    $false {
                        switch ($Remediate) {
                            $true {
                                try {
                                    New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port1 -LocalPortEnd $WSUS_Port1 -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
                                }
                                catch {
                                    return $false
                                }
                            }
                        }
                    }
                }
                switch ($CustomPort2Set) {
                    $false {
                        switch ($Remediate) {
                            $true {
                                try {
                                    New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port2 -LocalPortEnd $WSUS_Port2 -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
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
#endregion detection/remediation
