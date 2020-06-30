try {
    [Void][Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
    $serverManager = New-Object Microsoft.Web.Administration.ServerManager -ErrorAction SilentlyContinue
}
catch {
    # Deliberate empty return. If anything above throws an error, we assume we are not on a box with IIS
    exit 0
}

if ((Get-CimInstance -Query "SELECT Name FROM Win32_ServerFeature WHERE Name ='Windows Server Update Services'").Name -and $serverManager.ApplicationPools.Name -contains 'WsusPool') {
    Write-Host 'WSUS Is Installed'
}