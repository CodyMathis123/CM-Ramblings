try {
    [Void][Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
    $serverManager = New-Object Microsoft.Web.Administration.ServerManager 
}
catch {
    # Deliberate empty return. If anything above throws an error, we assume we are not on a box with IIS
    exit 0
}

try {
    $UpdateServices = (Get-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Update Services\Server\Setup\Installed Role Services" -Name 'UpdateServices-Services' -ErrorAction SilentlyContinue).'UpdateServices-Services'
    if ($UpdateServices -eq 2 -and (Get-CimInstance -Query "SELECT Name FROM Win32_ServerFeature WHERE Name ='Windows Server Update Services'").Name -and $serverManager.ApplicationPools.Name -contains 'WsusPool') {
        Write-Host 'WSUS PostInstall Has Ran'
    }
}
catch {
    # Deliberate empty return. If anything above throws an error, we assume we are not on a WSUS box
    exit 0
}