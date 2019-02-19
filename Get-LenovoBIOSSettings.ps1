function Get-LenovoBIOSSettings {
    <#
    .SYNOPSIS
        Gets current BIOS settings from Lenovo computer
    .DESCRIPTION
        This functions allows you to retrieve all the BIOS settings from a Lenovo computer, including a switch to 
        return the 'options' for each setting. Note that retrieving the options makes this take longer
        because we have to invoke a WMI method per setting. 
    .PARAMETER ComputerName
        Optionally provide the computer you want the setting for
    .PARAMETER WithOptions
        Optionally performs the GetBiosSelections for each setting to return the possible options. 
    .PARAMETER Credential
        Optionally provides credentials to perform the WMI queries and methods with
    .EXAMPLE
        C:\PS> Get-LenovoBiosSettings -ComputerName MAS86109 -WithOptions
        Returns the current BIOS settings for MAS83109 including what options each setting has
    .INPUTS
        [Alias('Computer', 'HostName', 'ServerName', 'IPAddress')]
        $ComputerName
    .OUTPUTS
        [pscustomobject[]]
    .NOTES
        May not work if Lenovo decides to change the format of the data stored in WMI
    #>
    [OutputType([pscustomobject[]])]
    param
    (
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [Alias('Computer', 'HostName', 'ServerName', 'IPAddress')]
        [string[]]$ComputerName,
        [switch]$WithOptions,
        [parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    begin {
        $CurrentSetting = [System.Collections.Generic.List[object]]::new()
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            $ComputerName = $env:COMPUTERNAME
        }
    }
    process {
        foreach($Computer in $ComputerName) {
            $getWmiObjectSplat = @{
                ComputerName = $Computer
                Namespace    = 'root\wmi'
                Class        = 'Lenovo_BiosSetting'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $getWmiObjectSplat.Credential = $Credential
            }
            if ($PSBoundParameters.ContainsKey('ComputerName')) {
                $getWmiObjectSplat.ComputerName = $Computer
            }
            $Settings = Get-WmiObject @getWmiObjectSplat | Select-Object -ExpandProperty CurrentSetting | Where-Object { $_ }
            
            foreach ($Setting in $Settings) {
                $Setting = (($Setting -split ';', 2)[0] -split ',', 2)
                $SettingName = $Setting[0]
                $SettingValue = $Setting[1]
                $HashTable = [ordered]@{
                    ComputerName = $Computer
                    SettingName = $SettingName
                    SettingValue = $SettingValue
                }
                if ($WithOptions) {
                    $getWmiObjectSplat = @{
                        Namespace = 'root\wmi'
                        Class     = 'Lenovo_GetBiosSelections'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $getWmiObjectSplat.Credential = $Credential
                    }
                    if ($PSBoundParameters.ContainsKey('ComputerName')) {
                        $getWmiObjectSplat.ComputerName = $Computer
                    }
            
                    $SettingOptions = ((Get-WmiObject @getWmiObjectSplat).GetBiosSelections($SettingName)) | Select-Object -ExpandProperty Selections
                    $HashTable.Add('SettingOptions', $SettingOptions)
                }
                $CurrentSetting.Add([pscustomobject]$HashTable)
            }
        }
    }
    end {
        return $CurrentSetting
    }
}
