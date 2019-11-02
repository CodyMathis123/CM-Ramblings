$Remediate = $false

$PathShouldBeROOT = Get-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Update Services\Server\Setup" -Name ContentDir | Select-Object -ExpandProperty ContentDir
$PathShouldBe = Join-Path -Path $PathShouldBeROOT -ChildPath 'WSUSContent'

[Void][Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
$serverManager = New-Object Microsoft.Web.Administration.ServerManager
$site = $serverManager.Sites | Where-Object { $_.Name -eq "WSUS Administration" }
$rootApp = $site.Applications | Where-Object { $_.Path -eq "/" }
$rootVdir = $rootApp.VirtualDirectories | Where-Object { $_.Path -eq "/Content" }
$CurrentPath = $rootVdir.PhysicalPath

switch ($CurrentPath -eq $PathShouldBe) {
    $true {
        $true
    }
    $false {
        switch ($Remediate) {
            $true {
                $rootVdir.PhysicalPath = $PathShouldBe
                $null = $serverManager.CommitChanges()
                $true
            }
            $false {
                $false
            }
        }
    }
}
