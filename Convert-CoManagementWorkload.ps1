<#
.SYNOPSIS
    Convert CoMgmt workloads from int to text and vice-versa
.DESCRIPTION
    In log files, WMI and the database we are presented with an integer values for the currently enabled functions with Co-Management.
        This function has two ParameterSets.
        For the 'TranslateWorkload' ParameterSet you can input an integer (0-255) and return a string array of the workloads that are enabled.
        For the 'GenerateWorkload' ParameterSet you can input a string array of the workloads you'd like and it will return the translated integer equivalent.
.PARAMETER DesiredWorkload
    Specify the workloads you'd like to generate a translated integer for. The options are are below. It will be translated using a bitwise and operator.
        'Compliance policies',
        'Device Configuration',
        'Endpoint Protection',
        'Office Click-To-Run apps',
        'Resource access policies',
        'Windows Updates policies'
.PARAMETER Workload
    Translate an integer workload to the named workload values using bitwise or operator.
.EXAMPLE
    PS C:\> .\Convert-CoManagementWorkload -DesiredWorkload 'Windows Updates Policies','Office Click-To-Run apps'
        145

        This would return a value of 145, which could be used to update a configuration item.
.EXAMPLE
    PS C:\> .\Convert-CoManagementWorkload -Workload 145
        Office Click-to-Run apps
        Windows Updates Policies

        This translates the workload integer value of 145 to the component that would be enabled, Office C2R and WUFB.
.NOTES
    FileName: Convert-CoManagementWorkload.ps1
    Author:   Cody Mathis
    Contact:  @CodyMathis123
    Created:  1/28/2019
    Updated:  1/29/2019

    Version History:
    1.0.0 - (1/28/2019) Initial script creation
    1.0.1 - (1/29/2019) Added proper help and commenting and specified OutputType
#>
[OutputType([int], ParameterSetName = 'GenerateWorkload')]
[OutputType([string[]], ParameterSetName = 'TranslateWorkload')]
param(
    [Parameter(Mandatory = $True, ParameterSetName = 'GenerateWorkload')]
    [ValidateSet('Compliance policies',
        'Device Configuration',
        'Endpoint Protection',
        'Office Click-To-Run apps',
        'Resource access policies',
        'Windows Updates policies'
    )]
    [string[]]
    $DesiredWorkload,
    [Parameter(Mandatory = $True, ParameterSetName = 'TranslateWorkload')]
    [ValidateRange(0, 255)]
    [int]
    $Workload
)

switch ($PSCmdlet.ParameterSetName) {
    'GenerateWorkload' {
        $Workloads = @{
            "Compliance policies"      = 3;
            "Resource access policies" = 5;
            "Windows Updates Policies" = 17;
            "Endpoint Protection"      = 33;
            "Device Configuration"     = 45;
            "Office Click-to-Run apps" = 129;
        }
        # Creating an arraylist and adding all the integer values for our workloads to the arraylist.
        $ToCalc = [System.Collections.ArrayList]::new()
        foreach ($Option in $DesiredWorkload) {
            $null = $ToCalc.Add($Workloads[$Option])
        }

        <#
            In order to calculate our output value we join all of our converted workload integers with -bor giving us something like '17 -bor 129'
            This is then converted to a scriptblock so we can execute it to receive an integer output. This is a bitwise operation.
        #>
        $Calculation = $ToCalc -join ' -bor '
        $Output = [scriptblock]::Create($Calculation)
        & $Output
    }
    'TranslateWorkload' {
        $Workloads = @{
            3   = "Compliance policies";
            5   = "Resource access policies"
            17  = "Windows Updates Policies";
            33  = "Endpoint Protection"
            45  = "Device Configuration"
            129 = "Office Click-to-Run apps"
        }

        # If our workload input is greater than 1, we perform a -band comparison against all possible workloads and return the matches
        if ($Workload -gt 1) {
            foreach ($Value in $Workloads.Keys) {
                if (($Value -band $Workload) -eq $Value) {
                    $Workloads[$value]
                }
            }
        }
        else {
            Write-Output 'None'
        }
    }
}
