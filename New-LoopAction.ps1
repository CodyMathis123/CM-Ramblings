function New-LoopAction {
    <#
	.SYNOPSIS
		This function allows you to create a looping script with an exit condition
	#>
    param
    (
        # Provides the integer value that is part of the exit condition of the loop
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [int32]$LoopTimeout,
        # Provides the time increment type for the loop timeout that is part of the exit condition of the loop

        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [ValidateSet('Seconds', 'Minutes', 'Hours', 'Days')]
        [string]$LoopTimeoutType,
        # Provides the integer delay in seconds between loops ($LoopDelayType defaults to seconds)

        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [int32]$LoopDelay,
        # Provides the time increment type for the LoopDelay between loops (defaults to seconds)

        [parameter(Mandatory = $false, ParameterSetName = 'DoUntil')]
        [ValidateSet('Milliseconds', 'Seconds')]
        [string]$LoopDelayType = 'Seconds',
        # A script block that will run inside the do-until loop recommend, encapsulating inside { }

        [parameter(Mandatory = $true, ParameterSetName = 'ForLoop')]
        [int32]$Iterations,
        # Provides the number of iterations to perform the loop for

        [parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        # A script block that will act as the exit condition for the do-until loop, recommend encapsulating inside { }

        [parameter(Mandatory = $true)]
        [scriptblock]$ExitCondition,
        # A script block that will act as the script to run if the timeout occurs, recommend encapsulating inside { }

        [parameter(Mandatory = $false)]
        [scriptblock]$IfTimeoutScript,
        # A script block that will act as the script to run if the condition succeeds, recommend encapsulating inside { }

        [parameter(Mandatory = $false)]
        [scriptblock]$IfSucceedScript
    )
    begin {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                $paramNewTimeSpan = @{
                    $LoopTimeoutType = $LoopTimeout
                }    
                $TimeSpan = New-TimeSpan @paramNewTimeSpan
                $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                $FirstRunDone = $false        
            }
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                do {
                    switch ($FirstRunDone) {
                        $false {
                            $FirstRunDone = $true
                        }
                        Default {
                            $paramStartSleep = @{
                                $LoopDelayType = $LoopDelay
                            }
                            Start-Sleep @paramStartSleep
                        }
                    }
                    . $ScriptBlock
                }
                until ((. $ExitCondition) -or $StopWatch.Elapsed -ge $TimeSpan)
            }
            'ForLoop' {
                for ($i = 0; $i -lt $Iterations; $i++) {
                    . $ScriptBlock
                    if (. $ExitCondition) {
                        break
                    }
                }
            }
        }
    }
    end {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                if ((-not (. $ExitCondition)) -and $StopWatch.Elapsed -ge $TimeSpan -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                    . $IfTimeoutScript
                }
                if ((. $ExitCondition) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                    . $IfSucceedScript
                }
                $StopWatch.Reset()
            }
            'ForLoop' {
                if ((-not (. $ExitCondition)) -and $i -ge $Iterations -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                    . $IfTimeoutScript
                }
                elseif ((. $ExitCondition) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                    . $IfSucceedScript
                }
            }
        }
    }
}
