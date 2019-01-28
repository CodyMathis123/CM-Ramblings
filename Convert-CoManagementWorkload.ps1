param(
    # Specify the workloads you'd like to generate a value for
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
    # Translate an integer workload to the named workload values
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
        $ToCalc = [System.Collections.ArrayList]::new()
        foreach ($Option in $DesiredWorkload) {
            $null = $ToCalc.Add($Workloads[$Option])
        }
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
