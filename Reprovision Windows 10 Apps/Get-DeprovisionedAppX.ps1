function Get-DeprovisionedAppX {
    <#
    .SYNOPSIS
        Returns an array of apps that are deprovisioned
    .DESCRIPTION
        This function returns an array of all the apps that are deprovisioned on the local computer.
        Deprovisioned apps will show up in the registry if they were removed while Windows was offline, or
        with the PowerShell cmdlets for removing AppX Packages.
    .PARAMETER Filter
        Option filter that will be ran through as a '-match' so that regex can be used
        Accepts an array of strings, which can be a regex string if you wish
    .EXAMPLE
        PS C:\> Get-DeprovisionedAppX
        Return all deprovisioned apps on the local computers
    .EXAMPLE
        PS C:\> Get-DeprovisionedAppX -Filter Store
        Return all deprovisioned apps on the local computers that match the filter 'Store'
    #>
    param (
        [parameter(Mandatory = $false)]
        [string[]]$Filter
    )
    begin {
        $DeprovisionRoot = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
        $AllDeprovisionedApps = Get-ChildItem -Path $DeprovisionRoot | Select-Object -Property @{ Name = 'DeprovisionedApp'; Expression = { $_.PSChildName } }
        if ($null -eq $AllDeprovisionedApps) {
            Write-Warning "There are no deprovisioned apps"
        }
    }
    process {
        switch ($PSBoundParameters.ContainsKey('Filter')) {
            $true {
                foreach ($SearchString in $Filter) {
                    switch -regex ($AllDeprovisionedApps.DeprovisionedApp) {
                        $SearchString {
                            [PSCustomObject]@{
                                'DeprovisionedApp' = $PSItem
                            }
                        }
                        default {
                            Write-Verbose "$PSItem does not match the filter `'$SearchString`""
                        }
                    }
                }
            }
            $false {
                Write-Output $AllDeprovisionedApps
            }
        }
    }
}