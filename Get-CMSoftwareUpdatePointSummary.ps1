function Get-CMSoftwareUpdatePointSummary {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SMSProvider
    )
    $SiteCode = $(Get-WmiObject -ComputerName $SMSProvider -Namespace 'root/SMS' -Class SMS_ProviderLocation -ErrorAction SilentlyContinue).SiteCode
    $WMIQueryParameters = @{
        ComputerName = $SMSProvider
        NameSpace = "root\sms\site_$SiteCode"
    }

    $SoftwareUpdatePoints = Get-WmiObject -Query "SELECT NetbiosName FROM SMS_R_System where SystemRoles = 'SMS Software Update Point'" @WMIQueryParameters | Select-Object -ExpandProperty NetbiosName
    $SoftwareUpdatePoints | ForEach-Object {
        $ServerName = $_ -replace "\\"
        $ServerName = [system.net.dns]::GetHostByName($ServerName).HostNAme
        if (Test-Connection -ComputerName $ServerName -Quiet -Count 3) {
            $WSUS = @{ }
            $WSUS.ComputerName = $ServerName
            $WSUS.Site = $SiteCode
            $HKLM = 2147483650
            $WSUSConfigKeyPath = "SOFTWARE\Microsoft\Update Services\Server\Setup"
            $ConnectionProperties = @('PortNumber', 'UsingSSL')
            $WMI_Connection = Get-WmiObject -List "StdRegProv" -namespace root\default -ComputerName $ServerName
            foreach ($Property in $ConnectionProperties) {
                $WSUS.$Property = ($WMI_Connection.GetDWORDValue($hklm, $WSUSConfigKeyPath, $Property)).uValue
            }
            $WSUS_Server = Get-WsusServer -Name $WSUS['ComputerName'] -UseSsl:$WSUS['UsingSSL'] -PortNumber $WSUS['PortNumber']
            $ServerConfig = $WSUS_Server.GetConfiguration()
            $DBConfig = $WSUS_Server.GetDatabaseConfiguration()
            $WSUS.SyncFromMicrosoftUpdate = $ServerConfig.SyncFromMicrosoftUpdate
            if (-not $WSUS.SyncFromMicrosoftUpdate) {
                $WSUS.UpstreamWsusServerName = $ServerConfig.UpstreamWsusServerName
                $WSUS.UpstreamWsusServerPortNumber = $ServerConfig.UpstreamWsusServerPortNumber
                $WSUS.UpstreamWsusServerUseSsl = $ServerConfig.UpstreamWsusServerUseSsl
                $WSUS.IsReplicaServer = $ServerConfig.IsReplicaServer
            }
            $WSUS.PortNumber = $WSUS_Server.PortNumber
            $WSUS.SqlServerName = $DBConfig.ServerName
            $WSUS.SqlDatabaseName = $DBConfig.DatabaseName
            $WSUS.UsingWID = $DBConfig.IsUsingWindowsInternalDatabase
            $WSUS.LocalContentCachePath = $ServerConfig.LocalContentCachePath
            $WSUS.SyncFromMicrosoftUpdate = $ServerConfig.SyncFromMicrosoftUpdate
            [pscustomobject]$WSUS | Select-Object -Property ComputerName, Site, PortNumber, UsingSSL, SqlServerName, SqlDatabaseName, UsingWID, LocalContentCachePath, SyncFromMicrosoftUpdate, UpstreamWsusServerName, UpstreamWsusServerPortNumber, UpstreamWsusServerUseSsl, IsReplicaServer
        }
    }
}
