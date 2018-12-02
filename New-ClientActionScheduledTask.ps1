<#
.SYNOPSIS
    Creates a scheduled task to run CM Client actions periodically for X hours

.DESCRIPTION
    Script will create a scheduled task with the specified duration and recurrance interval to invoke CM Client Actions on a machine. This is to help expedite a machine receiving all needed policies/applications/updates from SCCM.

.PARAMETER Duration
	Specify the duration (in hours) for the task. This is how long the duration will recur for. Note: The scheduled task deletes itself after this period (1-24)

.PARAMETER Interval
	Specifies the interval to run the actions at in minutes - this is the interval for scheduled task recurrence (1-60)

.PARAMETER Schedule
	Specifies th schedules to run - 'HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval'

.PARAMETER TaskName
	Set the task name - defaults to 'SCCM Expeditious Response Task'

.PARAMETER FileName
    Sets the file name of the script that is generated. This allows you to run the script multiple times to assign differenct actions to differnt schedules

.EXAMPLE
	# Creates a scheduled task to run a MachinePol ad HardwareInv every 30 minutes for 24 hours.
	.\New-ClientActionScheduledTask.ps1 -Schedule MachinePol,HardwareInv

.NOTES
    FileName:    New-ClientActionScheduledTask.ps1
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     11-29-2018
    Updated:     11-29-2018
#>
param (
    [parameter(Mandatory = $false)]
    [ValidateRange(1, 24)]
    [int]$Duration = 24,
    [parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$Interval = 30,
    [parameter(Mandatory = $false)]
    [ValidateSet('HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval')]
    [string[]]$Schedule,
    [parameter(Mandatory = $false)]
    [string]$TaskName = "SCCM Expeditious Response Task",
    [parameter(Mandatory = $false)]
    [string]$FileName = "ClientActionScheduledTask.ps1"
)
$ErrorActionPreference = 'Stop'
# I am using $env:SystemRoot\temp because $env:temp will be the users temp folder if this is not run as system, and our scheduled task runs as system and may have access issues to the users temp folder from a scheduled task
$File = Join-Path -Path "$env:SystemRoot\temp" -ChildPath $FileName

#region generate file which the scheduled task will execute
@"
<#
.SYNOPSIS
    Invokes CM Client actions on local or remote machines

.DESCRIPTION
    This script will allow you to invoke a set of CM Client actions on a machine (with optional credentials), providing a list of the actions and an optional delay betweens actions.
    The function will attempt for 5 minutes to invoke the action, with a 10 second delay inbetween attempts. This is to account for invoke-wmimethod failures.

.PARAMETER Schedule
	Define the schedules to run on the machine - 'HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval'

.PARAMETER Delay
	Specify the delay in seconds between each schedule when more than one is ran - 0-30 seconds

.PARAMETER ComputerName
	Specifies the computers to run this against

.PARAMETER Credential
	Optional PSCredential

.EXAMPLE
	# Start a machine policy eval and a hardware inventory cycle
	.\Start-CMClientAction.ps1 -Schedule MachinePol,HardwareInv

.NOTES
    Author:      Cody Mathis
    Contact:     @CodyMathis123
    Created:     11-29-2018
    Updated:     11-29-2018
#>
function Start-CMClientAction {
    [CmdletBinding(SupportsShouldProcess = `$true)]
    param
    (
        [parameter(Mandatory = `$true)]
        [ValidateSet('HardwareInv', 'SoftwareInv', 'UpdateScan', 'UpdateEval', 'MachinePol', 'AppEval')]
        [string[]]`$Schedule,
        [parameter(Mandatory = `$false)]
        [ValidateRange(0, 30)]
        [int]`$Delay = 5,
        [parameter(Mandatory = `$false)]
        [string[]]`$ComputerName = `$env:COMPUTERNAME,
        [parameter(Mandatory = `$false)]
        [pscredential]`$Credential
    )
    begin {
        `$TimeSpan = New-TimeSpan -Minutes 5
    }
    process {
        foreach (`$Computer in `$ComputerName) {
            foreach (`$Option in `$Schedule) {
                `$Action = switch (`$Option) {
                    'HardwareInv' {
                        "{00000000-0000-0000-0000-000000000001}"
                    }
                    'SoftwareInv' {
                        "{00000000-0000-0000-0000-000000000002}"
                    }
                    'UpdateScan' {
                        "{00000000-0000-0000-0000-000000000113}"
                    }
                    'UpdateEval' {
                        "{00000000-0000-0000-0000-000000000108}"
                    }
                    'MachinePol' {
                        "{00000000-0000-0000-0000-000000000021}"
                    }
                    'AppEval' {
                        "{00000000-0000-0000-0000-000000000121}"
                    }
                }

                `$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
                do {
                    try {
                        `$invokeWmiMethodSplat = @{
                            ComputerName = `$Computer
                            Name         = 'TriggerSchedule'
                            Namespace    = 'root\ccm'
                            Class        = 'sms_client'
                            ArgumentList = `$Action
                        }
                        if (`$PSBoundParameters.ContainsKey('Credential')) {
                            `$invokeWmiMethodSplat.Add('Credential', `$Credential)
                        }
                        Write-Verbose "Triggering a `$Schedule Cycle on `$Computer via the 'TriggerSchedule' WMI method"
                        `$Invocation = Invoke-WmiMethod @invokeWmiMethodSplat
                    }
                    catch {
                        Write-Error "Failed to invoke the `$Schedule cycle via WMI. Will retry every 10 seconds until [StopWatch `$(`$StopWatch.Elapsed) -ge 5 minutes] Error: `$(`$_.Exception.Message)"
                        Start-Sleep -Seconds 10
                    }
                }
                until (`$Invocation -or `$StopWatch.Elapsed -ge `$TimeSpan)
                if (`$Invocation) {
                    Write-Verbose "Successfully invoked the `$Schedule Cycle on `$Computer via the 'TriggerSchedule' WMI method"
                    Start-Sleep -Seconds `$Delay
                }
                `$StopWatch.Reset()
            }
        }
    }
    end {
        Write-Verbose "Following actions invoked - `$Schedule"
    }
}

Start-CMClientAction -Schedule $($Schedule -join ',')
"@  | Out-File -FilePath $File -Force
#endregion generate file which the scheduled task will execute

#region create and register a scheduled task with expiration and set to delete itself
try {
    $TaskAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -File `"$File`""
    $TaskSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -Compatibility Win8 -AllowStartIfOnBatteries:$true -RunOnlyIfIdle:$false
    $TaskTrigger = New-ScheduledTaskTrigger -Once -At ($Start = (Get-Date).AddSeconds(30)) -RepetitionInterval (New-TimeSpan -Minutes $Interval) -RepetitionDuration (New-TimeSpan -Hours $Duration)
    $Task = New-ScheduledTask -Action $TaskAction -Settings $TaskSettings -Trigger $TaskTrigger
    Register-ScheduledTask -InputObject $Task -TaskName $TaskName -User "NT AUTHORITY\SYSTEM" | Out-Null
    $CreatedTask = Get-ScheduledTask -TaskName $TaskName
    $CreatedTask.Triggers[0].EndBoundary = $Start.AddHours($Duration).AddMinutes(5).ToString('s')
    $CreatedTask.Settings.DeleteExpiredTaskAfter = "PT0S"
    Set-ScheduledTask -InputObject $CreatedTask | Out-Null
}
catch {
    Write-Error "Failed to create the scheduled task - $($_.Exception.Message)"
}
#endregion create and register a scheduled task with expiration and set to delete itself
