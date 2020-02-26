Function New-CMScheduleStartTime {
    [CmdletBinding()]
    <#
        .SYNOPSIS
            Recreate a CMSchedule object with a new start time
        .DESCRIPTION
            Natively, the CMSchedule objects do not allow you to write to the StartTime property. This makes it 
            difficult to adjust the start time of an existing maintenance window. This function can be used to
            'recreate' a CMSchedule based on the input schedule, with a new start time.
        .PARAMETER CMSchedule
            An array of CMSchedule objects
        .PARAMETER StartTime
            The desired new start time for the schedule
        .EXAMPLE
            CCM:\> $Sched = Get-CMMaintenanceWindow -CollectionName 'test'
                $Schedobject = Convert-CMSchedule -ScheduleString $Sched.ServiceWindowSchedules
                New-CMScheduleStartTime -CMSchedule $Schedobject -StartTime $Schedobject.StartTime.AddDays(5)
        .NOTES
            FileName:    New-CMScheduleStartTime.ps1
            Author:      Cody Mathis
            Contact:     @CodyMathis123
            Created:     2020-02-26
            Updated:     2020-02-26
    #>
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Schedules')]
        [Microsoft.ConfigurationManagement.ManagementProvider.WqlQueryEngine.WqlResultObjectBase[]]$CMSchedule,
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime
    )
    begin {
    }
    process {
        foreach ($Schedule in $CMSchedule) {
            $RecurType = $Schedule.SmsProviderObjectPath
            Switch ($RecurType) {
                SMS_ST_NonRecurring {
                    $DayDuration = $CMSchedule.DayDuration
                    $HourDuration = $CMSchedule.HourDuration
                    $MinuteDuration = $CMSchedule.MinuteDuration
                    $NewEndTime = $StartTime.AddDays($DayDuration).AddHours($HourDuration).AddMinutes($MinuteDuration)
                    New-CMSchedule -Start $StartTime -End $NewEndTime -Nonrecurring -IsUtc:$CMSchedule.IsGMT
                }
                SMS_ST_RecurInterval {
                    if ($CMSchedule.MinuteSpan -ne 0) {
                        $Span = 'Minutes'
                        $Interval = $CMSchedule.MinuteSpan
                    }
                    elseif ($CMSchedule.HourSpan -ne 0) {
                        $Span = 'Hours'
                        $Interval = $CMSchedule.HourSpan
                    }
                    elseif ($CMSchedule.DaySpan -ne 0) {
                        $Span = 'Days'
                        $Interval = $CMSchedule.DaySpan
                    }

                    New-CMSchedule -Start $StartTime -RecurInterval $Span -RecurCount $Interval -IsUtc:$CMSchedule.IsGMT
                }
                SMS_ST_RecurWeekly {
                    $Day = $CMSchedule.Day
                    $WeekRecurrence = $CMSchedule.ForNumberOfWeeks
                    New-CMSchedule -Start $StartTime -DayOfWeek $([DayOfWeek]($Day - 1)) -RecurCount $WeekRecurrence -IsUtc:$CMSchedule.IsGMT
                }
                SMS_ST_RecurMonthlyByWeekday {
                    $Day = $CMSchedule.Day
                    $ForNumberOfMonths = $CMSchedule.ForNumberOfMonths
                    $WeekOrder = $CMSchedule.WeekOrder
                    New-CMSchedule -Start $StartTime -DayOfWeek $([DayOfWeek]($Day - 1)) -WeekOrder $WeekOrder -IsUtc:$CMSchedule.IsGMT -RecurCount $ForNumberOfMonths
                }
                SMS_ST_RecurMonthlyByDate {
                    New-CMSchedule -Start $StartTime -DayOfMonth $CMSchedule.MonthDay -RecurCount $CMSchedule.ForNumberOfMonths -IsUtc:$CMSchedule.IsGMT
                }
                Default {
                    Write-Error "Parsing Schedule String resulted in invalid type of $RecurType"
                }
            }
        }
    }
}
