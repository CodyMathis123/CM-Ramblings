<#
.SYNOPSIS
    Creates a scheduled task to run CM Client actions periodically for X hours

.DESCRIPTION
    Script will create a scheduled task with the specified duration and recurrance interval to invoke CM Client Actions on a machine. This is to help expedite a machine receiving all needed policies/applications/updates from SCCM.

.PARAMETER Duration
	Specify the duration (in hours) for the task. This is how long the duration will recur for. Note: The scheduled task deletes itself after this period

.PARAMETER Interval
	Specifies the interval to run the actions at in minutes - this is the interval for scheduled task recurrence

.PARAMETER Schedule
	Specifies th schedules to run - 'HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval', 'DDR'

.PARAMETER TaskName
    Set the task name - defaults to "SCCM Action Scheduler - [$($Schedule -join ',')]"
    
.PARAMETER FileName
	Set the file name - defaults to "Start-CMClientAction.ps1" - this end up in c:\windows\temp so it'll eventually be deleted. 

.EXAMPLE
	# Creates a scheduled task to run a MachinePol and HardwareInv every 30 minutes for 24 hours.
    .\New-ClientActionScheduledTask.ps1 -Schedule MachinePol,HardwareInv
    
.EXAMPLE	
 	# Creates a scheduled task to run HardwareInv,UpdateScan,UpdateEval every 15 minutes for 12 hours.	
 	.\New-ClientActionScheduledTask.ps1 -Schedule HardwareInv,UpdateScan,UpdateEval -Interval 15 -Duration 12	
 		
 .EXAMPLE	
 	# Creates a scheduled task to run MachinePol every 5 minutes for 6 hours and names the task 'Expeditious CM Client Response'	
 	.\New-ClientActionScheduledTask.ps1 -Schedule MachinePol -TaskName 'Expeditious CM Client Response' -Interval 5 -Duration 6	
 

.NOTES
    FileName:    New-ClientActionScheduledTask.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     11-29-2018
    Updated:     12-23-2018
#>
param (
    [parameter(Mandatory = $false)]
    [int]$Duration = 24,
    [parameter(Mandatory = $false)]
    [int]$Interval = 30,
    [parameter(Mandatory = $true)]
    [ValidateSet('HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval', 'DDR')]
    [string[]]$Schedule,
    [parameter(Mandatory = $false)]
    [string]$TaskName,
    [parameter(Mandatory = $false)]
    [string]$FileName = 'Start-CMClientAction.ps1'
)
$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('TaskName')) {
    $TaskName = "SCCM Action Scheduler - [$($Schedule -join ',')]"
} 

if (-not $FileName.EndsWith('.ps1')) {
    $FileName = [string]::Format("{0}.ps1", $FileName)
}

# I am using $env:SystemRoot\temp because $env:temp will be the users temp folder if this is not run as system, and our scheduled task runs as system and may have access issues to the users temp folder from a scheduled task
$File = Join-Path -Path "$env:SystemRoot\temp" -ChildPath $FileName

#region functions
function Start-CMClientAction {
    <#
.SYNOPSIS
    Invokes CM Client actions on local or remote machines

.DESCRIPTION
    This script will allow you to invoke a set of CM Client actions on a machine (with optional credentials), providing a list of the actions and an optional delay betweens actions. 
    The function will attempt for 5 minutes to invoke the action, with a 10 second delay inbetween attempts. This is to account for invoke-wmimethod failures.

.PARAMETER Schedule
	Define the schedules to run on the machine - 'HardwareInv', 'FullHardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval'

.PARAMETER Delay
	Specify the delay in seconds between each schedule when more than one is ran - 0-30 seconds

.PARAMETER ComputerName
    Specifies the computers to run this against
    
.PARAMETER Timeout
    Specifies the timeout in minutes after which any individual computer will stop attempting the schedules. Default is 5 minutes.

.PARAMETER Credential
	Optional PSCredential

.EXAMPLE
	# Start a machine policy eval and a hardware inventory cycle
	Start-CMClientAction -Schedule MachinePol,HardwareInv

.NOTES
    FileName:    Start-CMClientAction.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     11-29-2018
    Updated:     12-23-2018
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [Alias('Computer', 'HostName', 'ServerName', 'IPAddress')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [parameter(Mandatory = $true)]
        [ValidateSet('HardwareInv', 'FullHardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval', 'DDR')]
        [string[]]$Schedule,
        [parameter(Mandatory = $false)]
        [ValidateRange(0, 30)]
        [int]$Delay = 5,
        [parameter(Mandatory = $false)]
        [int]$Timeout = 5,
        [parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    begin {
        $TimeSpan = New-TimeSpan -Minutes $Timeout
        # Load Microsoft.SMS.TSEnvironment COM object
        try {
            $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        }
        catch [System.Exception] {
            Write-Warning -Message "Unable to construct Microsoft.SMS.TSEnvironment object"
        }
        #exit script if a task sequence is detected. No need to be doing policy refreshes in the middle of a TS!
        if ($TSEnvironment) {
            exit 0
        }
    }
    process {
        foreach ($Computer in $ComputerName) {
            foreach ($Option in $Schedule) {
                $Action = switch ($Option) {
                    HardwareInv {
                        '{00000000-0000-0000-0000-000000000001}'
                    }
                    FullHardwareInv {
                        '{00000000-0000-0000-0000-000000000001}'
                    }
                    SoftwareInv {
                        '{00000000-0000-0000-0000-000000000002}'
                    }
                    UpdateScan {
                        '{00000000-0000-0000-0000-000000000113}'
                    }
                    UpdateEval {
                        '{00000000-0000-0000-0000-000000000108}'
                    }
                    MachinePol {
                        '{00000000-0000-0000-0000-000000000021}'
                    }
                    AppEval {
                        '{00000000-0000-0000-0000-000000000121}'
                    }
                    DDR {
                        '{00000000-0000-0000-0000-000000000003}'
                    }
                }

                $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                do {
                    try {
                        Remove-Variable MustExit -ErrorAction SilentlyContinue
                        Remove-Variable Invocation -ErrorAction SilentlyContinue
                        if ($Option -eq 'FullHardwareInv') {
                            $getWMIObjectSplat = @{
                                ComputerName = $Computer
                                Namespace    = 'root\ccm\invagt'
                                Class        = 'InventoryActionStatus'
                                Filter       = "InventoryActionID ='$Action'"
                                ErrorAction  = 'Stop'
                            }
                            if ($PSBoundParameters.ContainsKey('Credential')) {
                                $getWMIObjectSplat.Add('Credential', $Credential)
                            }
                            Write-Verbose "Attempting to delete Hardware Inventory history for $Computer as a FullHardwareInv was requested"
                            $HWInv = Get-WMIObject @getWMIObjectSplat
                            if ($null -ne $HWInv) {
                                $HWInv.Delete()
                                Write-Verbose "Hardware Inventory history deleted for $Computer"
                            }
                            else {
                                Write-Verbose "No Hardware Inventory history to delete for $Computer"
                            }
                        }
                        $invokeWmiMethodSplat = @{
                            ComputerName = $Computer
                            Name         = 'TriggerSchedule'
                            Namespace    = 'root\ccm'
                            Class        = 'sms_client'
                            ArgumentList = $Action
                            ErrorAction  = 'Stop'
                        }
                        if ($PSBoundParameters.ContainsKey('Credential')) {
                            $invokeWmiMethodSplat.Add('Credential', $Credential)
                        }
                        Write-Verbose "Triggering a $Option Cycle on $Computer via the 'TriggerSchedule' WMI method"
                        $Invocation = Invoke-WmiMethod @invokeWmiMethodSplat
                    }
                    catch [System.UnauthorizedAccessException] {
                        Write-Error -Message "Access denied to $Computer" -Category AuthenticationError -Exception $_.Exception
                        $MustExit = $true
                    }
                    catch {
                        Write-Warning "Failed to invoke the $Option cycle via WMI. Will retry every 10 seconds until [StopWatch $($StopWatch.Elapsed) -ge 5 minutes] Error: $($_.Exception.Message)"
                        Start-Sleep -Seconds 10
                    }
                }
                until ($Invocation -or $StopWatch.Elapsed -ge $TimeSpan -or $MustExit)
                if ($Invocation) {
                    Write-Verbose "Successfully invoked the $Option Cycle on $Computer via the 'TriggerSchedule' WMI method"
                    Start-Sleep -Seconds $Delay
                }
                elseif ($StopWatch.Elapsed -ge $TimeSpan) {
                    Write-Error "Failed to invoke $Option cycle via WMI after 5 minutes of retrrying."
                }
                $StopWatch.Reset()    
            }
        }
    }
    end {
        Write-Verbose "Following actions invoked - $Schedule"
    }
}

function New-ScheduledTaskTimeString {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Hours = 0,
        [Parameter(Mandatory = $false)]
        [int]$Minutes = 0
    )
    $TimeSpan = New-TimeSpan -Hours $Hours -Minutes $Minutes
    $TimeSpanDays = $TimeSpan | Select-Object -ExpandProperty Days
    $TimeSpanHours = $TimeSpan | Select-Object -ExpandProperty Hours
    $TimeSpanMinutes = $TimeSpan | Select-Object -ExpandProperty Minutes

    if ($TimeSpanDays -gt 0) {
        $OutputDays = [string]::Format("{0}D", $TimeSpanDays)
    }

    if ($TimeSpanHours -gt 0 -or $TimeSpanMinutes -gt 0) {
        $Delimiter = 'T'
        if ($TimeSpanHours -gt 0) {
            $OutputHours = [string]::Format("{0}H", $TimeSpanHours)
        }

        if ($TimeSpanMinutes -gt 0) {
            $OutputMinutes = [string]::Format("{0}M", $TimeSpanMinutes)
        }
    }

    [string]::Format("P{0}{1}{2}{3}", $OutputDays, $Delimiter, $OutputHours, $OutputMinutes)

}
#endregion functions

#region generate file which the scheduled task will execute
${Function:Start-CMClientAction}.ToString().Trim()  | Out-File -FilePath $File -Force
#endregion generate file which the scheduled task will execute

#region create and register a scheduled task with expiration and set to delete itself
try {
    $TScomObject = New-Object -ComObject ("Schedule.Service")
    $TScomObject.Connect()
    $RootTSFolder = $TScomObject.GetFolder("\")
    $TaskDefinition = $TScomObject.NewTask(0)
    $TaskDefinition.Settings.Enabled = $true
    $TaskDefinition.Settings.AllowDemandStart = $true
    $TaskDefinition.Settings.DisallowStartIfOnBatteries = $false
    $TaskDefinition.Settings.StopIfGoingOnBatteries = $false
    $TaskDefinition.Settings.Compatibility = 2
    $TaskDefinition.Settings.DeleteExpiredTaskAfter = "PT0S"
    
    #region task trigger creation
    $Start = (Get-Date).AddSeconds(30)
    $CalculatedDuration = New-ScheduledTaskTimeString -Hours $Duration
    $CalculatedInterval = New-ScheduledTaskTimeString -Minutes $Interval
    $triggers = $TaskDefinition.Triggers
    $trigger = $triggers.Create(1)
    $trigger.StartBoundary = $Start.ToString("yyyy-MM-dd'T'HH:mm:ss")
    $trigger.Repetition.Duration = $CalculatedDuration
    $trigger.Repetition.Interval = $CalculatedInterval
    $trigger.Repetition.StopAtDurationEnd = $true
    $trigger.EndBoundary = $Start.AddHours($Duration).AddMinutes(5).ToString('s')
    $trigger.Enabled = $true
    #endregion task trigger creation

    $Action = $TaskDefinition.Actions.Create(0)
    $Action.Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Action.Arguments = "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command `"$File`" -Schedule $($Schedule -join ',')"
    $RootTSFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, 6, "System", $null, 5)
}
catch {
    Write-Error "Failed to create the scheduled task - $($_.Exception.Message)"
}
#endregion create and register a scheduled task with expiration and set to delete itself
