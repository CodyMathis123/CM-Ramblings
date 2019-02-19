function Get-LenovoBIOSSettings {
    <#
    .SYNOPSIS
        Gets current BIOS settings from Lenovo computer(s)
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
        foreach ($Computer in $ComputerName) {
            #region gather BIOS settings from 'Lenovo_BiosSetting' WMI class, and check for permissions
            $getWmiObjectSplat = @{
                ComputerName = $Computer
                Namespace    = 'root\wmi'
                Class        = 'Lenovo_BiosSetting'
                ErrorAction  = 'Stop'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $getWmiObjectSplat.Credential = $Credential
            }
            if ($PSBoundParameters.ContainsKey('ComputerName')) {
                $getWmiObjectSplat.ComputerName = $Computer
            }
            try {
                $Settings = Get-WmiObject @getWmiObjectSplat | Select-Object -ExpandProperty CurrentSetting | Where-Object { $_ }
                $AccessDenied = $false
            }
            catch [System.UnauthorizedAccessException] {
                Write-Error -Message "Access denied to $Computer" -Category AuthenticationError -Exception $_.Exception
                $AccessDenied = $true
            }
            #endregion gather BIOS settings from 'Lenovo_BiosSetting' WMI class, and check for permissions

            if (-not $AccessDenied) {
                #region test for the existance of 'Lenovo_GetBiosSelections' WMI class to determine if we can query for available settings
                if ($WithOptions) {
                    $getWmiObjectSplat = @{
                        Namespace   = 'root\wmi'
                        Class       = 'Lenovo_GetBiosSelections'
                        ErrorAction = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $getWmiObjectSplat.Credential = $Credential
                    }
                    if ($PSBoundParameters.ContainsKey('ComputerName')) {
                        $getWmiObjectSplat.ComputerName = $Computer
                    }
                    try {
                        $null = Get-WmiObject @getWmiObjectSplat
                        $CanGetOptions = $true
                    }
                    catch { 
                        if ($_.CategoryInfo.Category -eq 'InvalidType') {
                            Write-Warning "Unable to query for BIOS Setting Options because 'Lenovo_GetBiosSelections' does not exist on $Computer"
                            $CanGetOptions = $false
                        }
                    }
                }
                #endregion test for the existance of 'Lenovo_GetBiosSelections' WMI class to determine if we can query for available settings

                #region format settings appropriately and check for options if requested and available
                foreach ($Setting in $Settings) {
                    $Setting = (($Setting -split ';', 2)[0] -split ',', 2)
                    $SettingName = $Setting[0]
                    $SettingValue = $Setting[1]
                    $HashTable = [ordered]@{
                        ComputerName = $Computer
                        SettingName  = $SettingName
                        SettingValue = $SettingValue
                    }
                    if ($WithOptions -and $CanGetOptions) {
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
                    elseif ($WithOptions) {
                        $HashTable.Add('SettingOptions', $null)
                    }
                    $CurrentSetting.Add([pscustomobject]$HashTable)
                }
                #endregion format settings appropriately and check for options if requested and available
            }
        }
    }
    end {
        return $CurrentSetting
    }
}
