function Get-CMClientMaintenanceWindow {
    <#
    .SYNOPSIS
        Get ConfigMgr Maintenance Window information from computers via WMI
    .DESCRIPTION
        This function will allow you to gather maintenance window information from multiple computers using WMI queries. You can provide an array of computer names,
        or you can pass them through the pipeline. You are also able to specify the Maintenance Window Type (MWType) you wish to query for, and pass credentials.
    .PARAMETER ComputerName
        Provides computer names to gather MW info from.
    .PARAMETER MWType
        Specifies the types of MW you want information for. Valid options are below
            'All Deployment Service Window',
            'Program Service Window',
            'Reboot Required Service Window',
            'Software Update Service Window',
            'Task Sequences Service Window',
            'Corresponds to non-working hours'
    .PARAMETER Credential
        Provides optional credentials to use for the WMI cmdlets.
    .EXAMPLE
        C:\PS> Get-CMClientMaintenanceWindow
            Return all the 'All Deployment Service Window', 'Software Update Service Window' Maintenance Windows for the local computer. These are the two default MW types
            that the function looks for
    .EXAMPLE
        C:\PS> Get-CMClientMaintenanceWindow -ComputerName 'Workstation1234','Workstation4321' -MWType 'Software Update Service Window'
            Return all the 'Software Update Service Window' Maintenance Windows for Workstation1234, and Workstation4321
    .NOTES
        FileName:    Get-CMClientMaintenanceWindow.ps1
        Author:      Cody Mathis
        Contact:     @CodyMathis123
        Created:     2019-08-14
        Updated:     2019-08-14
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [Alias('Computer', 'PSComputerName', 'IPAddress', 'ServerName', 'HostName')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [parameter(Mandatory = $false)]
        [ValidateSet('All Deployment Service Window',
            'Program Service Window',
            'Reboot Required Service Window',
            'Software Update Service Window',
            'Task Sequences Service Window',
            'Corresponds to non-working hours')]
        [string[]]$MWType = @('All Deployment Service Window', 'Software Update Service Window'),
        [parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    begin {
        #region Create hashtable for mapping MW types, and create WMI filter based on input params
        $MW_Type = @{
            1	=	'All Deployment Service Window'
            2	=	'Program Service Window'
            3	=	'Reboot Required Service Window'
            4	=	'Software Update Service Window'
            5	=	'Task Sequences Service Window'
            6	=	'Corresponds to non-working hours'
        }

        $RequestedTypesRaw = foreach ($One in $MWType) {
            $MW_Type.Keys.Where( { $MW_Type[$_] -eq $One } )
        }
        $RequestedTypesFilter = [string]::Format('Type = {0}', [string]::Join(' OR Type =', $RequestedTypesRaw))
        #endregion Create hashtable for mapping MW types, and create WMI filter based on input params

        #region define the PSDefaultParameterValues
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $PSDefaultParameterValues['Get-WmiObject:Credential'] = $Credential
        }
        #endregion define the PSDefaultParameterValues

        # Create our list which will be the return value
        $ReturnMW = [System.Collections.Generic.List[pscustomobject]]::new()
    }
    process {
        foreach ($Computer in $ComputerName) {
            try {
                $PSDefaultParameterValues['Get-WmiObject:ComputerName'] = $Computer

                if (Test-Connection -ComputerName $Computer -Count 2 -Quiet) {
                    $TimeZone = Get-WmiObject -Class Win32_TimeZone -Property Caption | Select-Object -ExpandProperty Caption

                    $getWmiObjectServiceWindowSplat = @{
                        Namespace = 'root\CCM\ClientSDK'
                        Class     = 'CCM_ServiceWindow'
                        Filter    = $RequestedTypesFilter
                    }
                    [System.Management.ManagementObject[]]$ServiceWindows = Get-WmiObject @getWmiObjectServiceWindowSplat
                    if ($ServiceWindows -is [Object] -and $ServiceWindows.Count -gt 0) {
                        $MachineMW = foreach ($ServiceWindow in $ServiceWindows) {
                            [PSCustomObject]@{
                                ComputerName = $Computer
                                StartTime    = [DateTime]::ParseExact($($ServiceWindow.StartTime.Split('+|-')[0]), 'yyyyMMddHHmmss.ffffff', [System.Globalization.CultureInfo]::InvariantCulture)
                                EndTime      = [DateTime]::ParseExact($($ServiceWindow.EndTime.Split('+|-')[0]), 'yyyyMMddHHmmss.ffffff', [System.Globalization.CultureInfo]::InvariantCulture)
                                TimeZone     = $TimeZone
                                Duration     = $ServiceWindow.Duration
                                MWID         = $ServiceWindow.ID
                                Type         = $MW_Type.Item([int]$($ServiceWindow.Type))
                            }
                        }
                        $ReturnMW.Add($MachineMW)
                    }
                    else {
                        $NoMW = [PSCustomObject]@{
                            ComputerName = $Computer
                            StartTime    = $null
                            EndTime      = $null
                            TimeZone     = $TimeZone
                            Duration     = $null
                            MWID         = $null
                            Type         = "No ServiceWindow of type(s) $($RequestedTypesRaw -join ', ')"
                        }
                        $ReturnMW.Add($NoMW)
                    }
                }
                else {
                    $Offline = [PSCustomObject]@{
                        ComputerName = $Computer
                        StartTime    = $null
                        EndTime      = $null
                        TimeZone     = $null
                        Duration     = $null
                        MWID         = $null
                        Type         = 'OFFLINE'
                    }
                    $ReturnMW.Add($Offline)
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
            finally {
                if ($PSDefaultParameterValues.ContainsKey('Get-WmiObject:ComputerName')) {
                    $PSDefaultParameterValues.Remove('Get-WmiObject:ComputerName')
                }
                if ($PSDefaultParameterValues.ContainsKey('Get-WmiObject:Credential')) {
                    $PSDefaultParameterValues.Remove('Get-WmiObject:Credential')
                }
            }
        }
    }
    end { 
        return $ReturnMW
    }
}
