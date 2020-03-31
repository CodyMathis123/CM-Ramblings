[Void][Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
$serverManager = New-Object Microsoft.Web.Administration.ServerManager
$WSUS_ConfigKey = 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Update Services\Server\Setup'

try {
    $ServerCertName = Get-ItemPropertyValue -Path $WSUS_ConfigKey -Name 'ServerCertificateName' -ErrorAction Stop
    $UsingSSL = Get-ItemPropertyValue -Path $WSUS_ConfigKey -Name 'UsingSSL' -ErrorAction Stop
    if ($serverManager.ApplicationPools.Name -contains 'WsusPool' -and $env:COMPUTERNAME -match $ServerCertName -and $UsingSSL) {
        Write-Host 'WSUS Server is SSL'
    }
}
catch {
    # Deliberate empty return. If anything above throws an error, we assume we are not on an SSL WSUS box
}