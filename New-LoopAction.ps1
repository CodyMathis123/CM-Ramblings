function New-LoopAction {
    <#
    .SYNOPSIS
        Function to loop a specified scriptblock until certain conditions are met
    .DESCRIPTION
        This function is a wrapper for a ForLoop or a DoUntil loop. This allows you to specify if you want to exit based on a timeout, or a number of iterations.
        Additionally, you can specify an optional delay between loops, and the type of dealy (Minutes, Seconds). If needed, you can also perform an action based on
        whether the 'Exit Condition' was met or not. This is the IfTimeoutScript and IfSucceedScript. 
    .PARAMETER LoopTimeout
        A time interval integer which the loop should timeout after. This is for a DoUntil loop.
    .PARAMETER LoopTimeoutType
        Provides the time increment type for the LoopTimeout, defaulting to Seconds. ('Seconds', 'Minutes', 'Hours', 'Days')
    .PARAMETER LoopDelay
        An optional delay that will occur between each loop.
    .PARAMETER LoopDelayType
        Provides the time increment type for the LoopDelay between loops, defaulting to Seconds. ('Milliseconds', 'Seconds', 'Minutes')
    .PARAMETER Iterations
        Implies that a ForLoop is wanted. This will provide the maximum number of Iterations for the loop. [i.e. "for ($i = 0; $i -lt $Iterations; $i++)..."]
    .PARAMETER ScriptBlock
        A script block that will run inside the loop. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER ExitCondition
        A script block that will act as the exit condition for the do-until loop. Will be evaluated each loop. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER IfTimeoutScript
        A script block that will act as the script to run if the timeout occurs. Recommend encapsulating inside { } or providing a [scriptblock]
    .PARAMETER IfSucceedScript
        A script block that will act as the script to run if the exit condition is met. Recommend encapsulating inside { } or providing a [scriptblock]
    .EXAMPLE
        C:\PS> $newLoopActionSplat = @{
                    LoopTimeoutType = 'Seconds'
                    ScriptBlock = { 'Bacon' }
                    ExitCondition = { 'Bacon' -Eq 'eggs' }
                    IfTimeoutScript = { 'Breakfast'}
                    LoopDelayType = 'Seconds'
                    LoopDelay = 1
                    LoopTimeout = 10
                }
                New-LoopAction @newLoopActionSplat
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Bacon
                Breakfast
    .EXAMPLE
        C:\PS> $newLoopActionSplat = @{
                    ScriptBlock = { if($Test -eq $null){$Test = 0};$TEST++ }
                    ExitCondition = { $Test -eq 4 }
                    IfTimeoutScript = { 'Breakfast' }
                    IfSucceedScript = { 'Dinner'}
                    Iterations  = 5
                    LoopDelay = 1
                }
                New-LoopAction @newLoopActionSplat
                Dinner
        C:\PS> $newLoopActionSplat = @{
                    ScriptBlock = { if($Test -eq $null){$Test = 0};$TEST++ }
                    ExitCondition = { $Test -eq 6 }
                    IfTimeoutScript = { 'Breakfast' }
                    IfSucceedScript = { 'Dinner'}
                    Iterations  = 5
                    LoopDelay = 1
                }
                New-LoopAction @newLoopActionSplat
                Breakfast
    .NOTES
        Play with the conditions a bit. I've tried to provide some examples that demonstrate how the loops, timeouts, and scripts work!
    #>
    param
    (
        [parameter()]
        [String]$Name = 'NoName',
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [int32]$LoopTimeout,
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [ValidateSet('Seconds', 'Minutes', 'Hours', 'Days')]
        [string]$LoopTimeoutType,
        [parameter(Mandatory = $true)]
        [int32]$LoopDelay,
        [parameter(Mandatory = $false)]
        [ValidateSet('Milliseconds', 'Seconds', 'Minutes')]
        [string]$LoopDelayType = 'Seconds',
        [parameter(Mandatory = $true, ParameterSetName = 'ForLoop')]
        [int32]$Iterations,
        [parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [parameter(Mandatory = $true, ParameterSetName = 'DoUntil')]
        [parameter(Mandatory = $false, ParameterSetName = 'ForLoop')]
        [scriptblock]$ExitCondition,
        [parameter(Mandatory = $false)]
        [scriptblock]$IfTimeoutScript,
        [parameter(Mandatory = $false)]
        [scriptblock]$IfSucceedScript
    )
    begin {
        Write-Verbose ('New-LoopAction: [{0}] Started' -f $Name)
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
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Executing script block' -f $Name)
                    . $ScriptBlock
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Done, executing exit condition script block' -f $Name)
                    $ExitConditionResult = . $ExitCondition
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Done, exit condition result is {1} and elapsed time is {2}' -f $Name, $ExitConditionResult, $StopWatch.Elapsed)
                }
                until ($ExitConditionResult -eq $true -or $StopWatch.Elapsed -ge $TimeSpan)
            }
            'ForLoop' {
                for ($i = 0; $i -lt $Iterations; $i++) {
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
                    Write-Verbose ('New-LoopAction: [{0}] [ForLoop - {1}/{2}] Executing script block' -f $Name, $i, $Iterations)
                    . $ScriptBlock
                    if ($PSBoundParameters.ContainsKey('ExitCondition')) {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Done, executing exit condition script block' -f $Name)
                        if (. $ExitCondition) {
                            $ExitConditionResult = $true
                            break
                        }
                        else {
                            $ExitConditionResult = $false
                        }
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop - {1}/{2}] Done, exit condition result is {2}' -f $Name, $i, $Iterations, $ExitConditionResult)
                    }
                    else {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop - {1}/{2}] Done' -f $Name, $i, $Iterations)
                    }
                }
            }
        }
    }
    end {
        switch ($PSCmdlet.ParameterSetName) {
            'DoUntil' {
                if ((-not ($ExitConditionResult)) -and $StopWatch.Elapsed -ge $TimeSpan -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Executing timeout script block' -f $Name)
                    . $IfTimeoutScript
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Done' -f $Name)
                }
                if (($ExitConditionResult) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Executing success script block' -f $Name)
                    . $IfSucceedScript
                    Write-Verbose ('New-LoopAction: [{0}] [DoUntil] Done' -f $Name)
                }
                $StopWatch.Reset()
            }
            'ForLoop' {
                if ($PSBoundParameters.ContainsKey('ExitCondition')) {
                    if ((-not ($ExitConditionResult)) -and $i -ge $Iterations -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Executing timeout script block' -f $Name)
                        . $IfTimeoutScript
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Done' -f $Name)
                    }
                    elseif (($ExitConditionResult) -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Executing success script block' -f $Name)
                        . $IfSucceedScript
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Done' -f $Name)
                    }
                }
                else {
                    if ($i -ge $Iterations -and $PSBoundParameters.ContainsKey('IfTimeoutScript')) {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Executing timeout script block' -f $Name)
                        . $IfTimeoutScript
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Done' -f $Name)

                    }
                    elseif ($i -lt $Iterations -and $PSBoundParameters.ContainsKey('IfSucceedScript')) {
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Executing success script block' -f $Name)
                        . $IfSucceedScript
                        Write-Verbose ('New-LoopAction: [{0}] [ForLoop] Done' -f $Name)
                    }
                }
            }
        }
        Write-Verbose ('New-LoopAction: [{0}] Finished' -f $Name)
    }
}
