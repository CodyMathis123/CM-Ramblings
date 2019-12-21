function Reprovision-App {
    <#
    .SYNOPSIS
        'Reprovision' apps by removing the registry key that prevents app reinstall
    .DESCRIPTION
        Starting in Windows 10 1803, a registry key is set for every deprovisioned app. As long as this registry key
        is in place, a deprovisioned application will not be reinstalled during a feature update. By removing these
        registry keys, we can ensure that deprovisioned apps, such as the windows store are able to be reinstalled.
    .PARAMETER DeprovisionedApp
        The full name of the app to reprovision, as it appears in the registry. You can easily get this name using
        the Get-DeprovisionedApp function. 
    .EXAMPLE
        PS C:\> Reprovision-App -DeprovisionedApp 'Microsoft.WindowsAlarms_8wekyb3d8bbwe'
        Removes the registry key for the deprovisioned WindowsAlarms app. The app will return after the next
        feature update.
    .INPUTS
        [string[]]
    .NOTES
        You must provide the exact name of the app as it appears in the registry. This is the full app 'name' - It is 
        recommended to first use the Get-DeprovisionApp function to find apps that can be reprovisioned.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$DeprovisionedApp
    )
    begin {
        $DeprovisionRoot = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
        $AllDeprovisionedApps = Get-ChildItem -Path $DeprovisionRoot
        if ($null -eq $AllDeprovisionedApps) {
            Write-Warning "There are no deprovisioned apps"
        }
    }
    process {
        foreach ($App in $DeprovisionedApp) {
            $DeprovisionedAppPath = Join-Path -Path $DeprovisionRoot -ChildPath $App
            if ($PSCmdlet.ShouldProcess($App, "Reprovision-App")) {
                $AppPath = Resolve-Path -Path $DeprovisionedAppPath -ErrorAction Ignore
                if ($null -ne $AppPath) {
                    Remove-Item -Path $AppPath.Path -Force
                }
                else {
                    Write-Warning "App $App was not found to be deprovisioned"
                }
            }
        }
    }
}