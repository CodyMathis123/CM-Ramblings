$Remediate = $false
$IssuingCA = 'Auto Enrollment Issuing CA'
$Website = 'WSUS Administration'

try {
    $WSUS_Server = Get-WsusServer -ErrorAction Stop
}
catch {
    # This is not a WSUS server, or it is in an error state. Return compliant.
    return $true
}
#region helper functions
function Get-WSUSPortNumbers {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Return the port numbers in use by WSUS
    .DESCRIPTION
        This function will automatically determine the ports in use by WSUS, and return them as a PSCustomObject.
        
        If WSUS is set to use any custom port other than 80/443 it 
            automatically determines the HTTP as noted in the link below
            https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/2-configure-wsus#configure-ssl-on-the-wsus-server
                ... if you use any port other than 443 for HTTPS traffic, 
                WSUS will send clear HTTP traffic over the port that numerically 
                comes before the port for HTTPS. For example, if you use port 8531 for HTTPS, 
                WSUS will use port 8530 for HTTP.
    .EXAMPLE
        PS C:\> Get-WSUSPortNumbers -WSUSServer (Get-WSUSServer)
    .INPUTS
        [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]
    .OUTPUTS
        [PSCustomerObject]
    .NOTES
        FileName: Get-WSUSPortNumbers.ps1
        Author:   Cody Mathis
        Contact:  @CodyMathis123
        Created:  6/29/2020
        Updated:  6/29/2020
    #>
    param (
        [Parameter(Mandatory = $true)]
        [object]$WSUSServer
    )
    #region Determine WSUS Port Numbers
    $WSUS_Port1 = $WSUSServer.PortNumber
    $WSUS_IsSSL = $WSUSServer.UseSecureConnection

    switch ($WSUS_IsSSL) {
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

    return [PSCustomObject]@{
        WSUSIsSSL = $WSUS_IsSSL
        WSUSPort1 = $WSUS_Port1
        WSUSPort2 = $WSUS_Port2
    }
}
#endregion

$WSUSPorts = Get-WSUSPortNumbers -WSUSServer $WSUS_Server
if ($WSUSPorts.WSUSIsSSL) {
    $PortNumber = $WSUSPorts.WSUSPort1
}
else {
    # WSUS is not configured to use SSL. Return compliant.
    return 'Compliant'
}

$AllCerts = Get-ChildItem -Path Cert:\LocalMachine\My\
$ServerAuth = $allCerts | Where-Object { $_.issuer -match $IssuingCA -and $_.Subject -match $env:COMPUTERNAME -and $_.EnhancedKeyUsageList.FriendlyName -contains 'Server Authentication' } | Sort-Object -Property NotAfter | Select-Object -ExpandProperty Thumbprint -Last 1
$Binding = Get-WebBinding -Name $Website -Protocol https

if ($null -eq $ServerAuth) {
    return 'No Cert Found'
}

switch ($null -ne $Binding) {
    $true {
        continue
    }
    $false {
        switch ($Remediate) {
            $true {
                $null = New-WebBinding -Name $Website -Protocol https -Port $PortNumber
                $Binding = Get-WebBinding -Name $Website -Protocol https
            }
            $false {
                return 'HTTPS Binding does not exist'
            }
        }

    }
}

switch ($Binding.certificateHash -eq $ServerAuth) {
    $true {
        return 'Compliant'
    }
    $false {
        switch ($Remediate) {
            $true {
                $Binding.AddSslCertificate($ServerAuth, 'MY')
                return 'Compliant'
            }
            $false {
                return 'Incorrect Cert Bound'
            }
        }
    }
}