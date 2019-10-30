<#
    This script is meant to be used as a Configuration Item in SCCM
    It will configure the DefaultSecureProtocols property, which is a required edit for TLS1.1,TLS1.2 compatability on downlevel OS.
    You can specify which protocols you want to ensure are enabled, or disabled. You can also 'Ignore' a protocol so that it does not affect your output.
#>

try {
    # Simply switch this between $true and $false based on whether you want the script to remediate
    $Remediate = $true

    #region Preference per protocol. If you "don't care" about the enablement, you can specify 'Ignore'
    $ProtocolPreferece = @{
        'SSL2.0' = 'Ignore'
        'SSL3.0' = 'Ignore'
        'TLS1.0' = 'Ignore'
        'TLS1.1' = 'Ignore'
        'TLS1.2' = 'Enable'
    }
    #endregion Preference per protocol. If you "don't care" about the enablement, you can specify 'Ignore'

    #region Map readable protocol name to hexadecimal equivalent for bitmap comparison
    $ProtocolMap = @{
        'SSL2.0' = 0x00000008
        'SSL3.0' = 0x00000020
        'TLS1.0' = 0x00000080
        'TLS1.1' = 0x00000200
        'TLS1.2' = 0x00000800
    }
    #endregion Map readable protocol name to hexadecimal equivalent for bitmap comparison

    #region determine which paths are 'valid' which allows this to also work on 32-bit systems without issue
    $WinHTTP_PathsToValidate = 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp', 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    $WinHTTP_Paths = foreach ($Possibility in $WinHTTP_PathsToValidate) {
        if (Test-Path -Path (Split-Path -Path $Possibility -Parent) -ErrorAction SilentlyContinue) {
            Write-Output $Possibility
        }
    }
    #endregion determine which paths are 'valid' which allows this to also work on 32-bit systems without issue

    try {
        #region loop through each WinHTTP key found, and gather the current DefaultSecureProtocols
        foreach ($WinHTTP in $WinHTTP_Paths) {
            $DefaultSecureProtocols = Get-ItemProperty -Path $WinHTTP -Name DefaultSecureProtocols -ErrorAction Stop | Select-Object -ExpandProperty DefaultSecureProtocols

            #region loop through the ProtocolPreference hash table, switch operation on each preference to determine action
            foreach ($Protocol in $ProtocolPreferece.Keys) {
                switch ($ProtocolPreferece[$Protocol]) {
                    #region Enable Protocol - a -band with the current $DefaultSecureProtocols should not change the value, remediate using -bor to 'account for' the needed value
                    'Enable' {
                        switch (($DefaultSecureProtocols -band $ProtocolMap[$Protocol]) -eq $ProtocolMap[$Protocol]) {
                            $true {
                                continue;
                            }
                            $false {
                                switch ($Remediate) {
                                    $true {
                                        $DefaultSecureProtocols = $DefaultSecureProtocols -bor $ProtocolMap[$Protocol]
                                    }
                                    $false {
                                        return $false
                                    }
                                }
                            }
                        }
                    }
                    #endregion Enable Protocol - a -band with the current $DefaultSecureProtocols should not change the value, remediate using -bor to 'account for' the needed value

                    #region Disable Protocol - a -band with the current $DefaultSecureProtocols should not 'match' and return 0, remediate with -band and -bnot to reverse the 'add' if it has happened
                    'Disable' {
                        switch (($DefaultSecureProtocols -band $ProtocolMap[$Protocol]) -eq 0) {
                            $true {
                                continue;
                            }
                            $false {
                                switch ($Remediate) {
                                    $true {
                                        $DefaultSecureProtocols = $DefaultSecureProtocols -band (-bnot $ProtocolMap[$Protocol])
                                    }
                                    $false {
                                        return $false
                                    }
                                }
                            }
                        }
                    }
                    #endregion Disable Protocol - a -band with the current $DefaultSecureProtocols should not 'match' and return 0, remediate with -band and -bnot to reverse the 'add' if it has happened

                    #region if we don't care about the protocol we simply continue so the value is not taken into consideration
                    'Ignore' {
                        Continue
                    }
                    #endregion if we don't care about the protocol we simply continue so the value is not taken into consideration
                }
            }
            #endregion loop through the ProtocolPreference hash table, switch operation on each preference to determine action

            #region $DefaultSecureProtocols has been adjusted based on preference, and existing value in the registry. No we compare to the existing property. If not equal, set, else continue
            switch ($DefaultSecureProtocols -eq (Get-ItemProperty -Path $WinHTTP -Name DefaultSecureProtocols -ErrorAction Stop | Select-Object -ExpandProperty DefaultSecureProtocols)) {
                $true {
                    continue
                }
                $false {
                    switch ($Remediate) {
                        $true {
                            Set-ItemProperty -Path $WinHTTP -Name DefaultSecureProtocols -Value $DefaultSecureProtocols
                        }
                        $false {
                            return $false
                        }
                    }
                }
            }
            #endregion $DefaultSecureProtocols has been adjusted based on preference, and existing value in the registry. No we compare to the existing property. If not equal, set, else continue
        }

        #region return true if ALL of our checks in the above switch comparison are valid
        return $true
        #endregion return true if ALL of our checks in the above switch comparison are valid

        #endregion loop through each WinHTTP key found, and gather the current DefaultSecureProtocols
    }
    catch {
        #region a 'catch' all to simply create and set the value. This would account for if the DefaultSecureProtocols property does not exist
        switch ($Remediate) {
            $true {
                $Resultant = 0

                #region loop through ProtocolPreference hashtable and simple 'add' or 'subtract' as needed with -bor and -band -bnot
                foreach ($Protocol in $ProtocolPreferece.Keys) {
                    switch ($ProtocolPreferece[$Protocol]) {
                        'Enable' {
                            $Resultant = $Resultant -bor $ProtocolMap[$Protocol]
                        }
                        'Disable' {
                            if (($Resultant -band $ProtocolMap[$Protocol]) -ne 0) {
                                $Resultant = $Resultant -band (-bnot $ProtocolMap[$Protocol])
                            }
                        }
                        'Ignore' {
                            continue
                        }
                    }
                }
                #endregion loop through ProtocolPreference hashtable and simple 'add' or 'subtract' as needed with -bor and -band -bnot

                #region set the DefaultSecureProtocols property
                foreach ($WinHTTP in $WinHTTP_Paths) {
                    if(-not (Test-Path -Path $WinHTTP)) {
                        $null = New-Item -Path $WinHTTP -Force -ErrorAction Stop
                    }
                    Set-ItemProperty -Path $WinHTTP -Name DefaultSecureProtocols -Value $Resultant -ErrorAction Stop -Force
                }
                #endregion set the DefaultSecureProtocols property
            }
            $false {
                return $false
            }
        }
            #endregion a 'catch' all to simply create and set the value. This would account for if the DefaultSecureProtocols property does not exist
    }
}
catch {
    return $false
}