function Add-FunctionToProfile {
    <#
.SYNOPSIS
    Add a function to your profile
.DESCRIPTION
    This function is used to append a function to your PowerShell profile. You provide a function name, and if it has a script block
    then it will be appended to your PowerShell profile with the function name provided.
.PARAMETER FunctionToAdd
    The name of the function(s) you wish to add to your profile. You can provide multiple. 
.EXAMPLE
    PS C:\> Add-FunctionToProfile -FunctionToAdd 'Get-CMClientMaintenanceWindow'
.NOTES
    If a function doesn't have a script block, then it cannot be added to your profile
#>
    param(
        [Parameter(Mandatory = $True)]
        [string[]]$FunctionToAdd
    )
    foreach ($FunctionName in $FunctionToAdd) {
        try {
            $Function = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to find the specified function [Name = '$FunctionName']"
            continue
        }    
        $ScriptBlock = $Function | Select-Object -ExpandProperty ScriptBlock
        if ($null -ne $ScriptBlock) {
            $FuncToAdd = [string]::Format("`r`nfunction {0} {{{1}}}", $FunctionName, $ScriptBlock)
            ($FuncToAdd -split "`n") | Add-Content -Path $PROFILE 
        }
        else {
            Write-Error "Function $FunctionName does not have a Script Block and cannot be added to your profile."
        }
    }
}
