function Set-CMClientSettingPriority {
    <#
    .SYNOPSIS
        Move a MEMCM Client policy to the specified priority
    .DESCRIPTION
        Becuase the GUI does not allow you to move more than one step at a time,
        this PowerShell function can be used to set an Client Settings policy to a specific
        priority without having to click increase, or decrease over and over
    .PARAMETER Name
        The name of the Client Policy to increase or decrease the priority of
    .PARAMETER Priority
        The desired priority to set the Client Policy to
    .EXAMPLE
        PS C:\> Set-CMClientSettingPriority -Name 'ClientSetting1' -Priority 3
            Will move the priority of the ClientSetting1 up, or down, until it reaches priority 3
    .NOTES
        FileName:    Set-CMClientSettingPriority.ps1
        Author:      Cody Mathis
        Contact:     @CodyMathis123
        Created:     2020-07-07
        Updated:     2020-07-07
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [int]$Priority
    )
    $Policy = Get-CMClientSetting -Name $Name
    if ($null -eq $Policy) {
        Write-Warning "No Client policy found with [Name: $Name]"
        return $false
    }
    $BeginningPriority = $Policy.Priority

    if ($BeginningPriority -eq $Priority) {
        Write-Verbose "Policy [Name: $Name] found with [Priority: $BeginningPriority] already set"
        return $true
    }
    else {
        Write-Verbose "Policy [Name: $Name] found with [Priority: $BeginningPriority] - will increase or decrease as needed"

        switch ($Priority -gt $BeginningPriority) {
            $true {
                Write-Verbose "Will Decrease policy priority until it reaches $Priority"
                if ($PSCmdlet.ShouldProcess("[PolicyName: $Name] [DesiredPriority: $Priority] [Action: Decrease]", "Set-CMClientSettingPriority")) {

                    Do {
                        $Policy | Set-CMClientSettingGeneral -Priority Decrease
                    }
                    until ((Get-CMClientSetting -Name $Name).Priority -eq $Priority)
                }
            }
            $false {
                Write-Verbose "Will Increase policy priority until it reaches $Priority"
                if ($PSCmdlet.ShouldProcess("[PolicyName: $Name] [DesiredPriority: $Priority] [Action: Increase]", "Set-CMClientSettingPriority")) {

                    Do {
                        $Policy | Set-CMClientSettingGeneral -Priority Increase
                    }
                    until ((Get-CMClientSetting -Name $Name).Priority -eq $Priority)
                }
            }
        }

        $EndPriority = (Get-CMClientSetting -Name $Name).Priority
        if ($EndPriority -eq $Priority) {
            return $true
        }
        else {
            return $false
        }
    }
}