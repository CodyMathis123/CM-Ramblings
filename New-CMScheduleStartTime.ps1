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
        #region create our splat for the new schedule, start time is the same for all
        $NewSchedSplat = @{
            Start = $StartTime
        }
        #endregion create our splat for the new schedule, start time is the same for all
    }
    process {
        foreach ($Schedule in $CMSchedule) {
            #region determine new end time based off new start time, and existing durations
            $NewEndTime = $StartTime.AddDays($Schedule.DayDuration).AddHours($Schedule.HourDuration).AddMinutes($Schedule.MinuteDuration)
            #endregion determine new end time based off new start time, and existing durations

            #region define the paramters that are the same for all 'new' schedules
            $NewSchedSplat['End'] = $NewEndTime
            $NewSchedSplat['IsUTC'] = $Schedule.IsGMT
            #endregion define the paramters that are the same for all 'new' schedules

            #region based on recur type, we will add parameters to our $NewSchedSplat
            Switch ($Schedule.SmsProviderObjectPath) {
                SMS_ST_NonRecurring {
                    $NewSchedSplat['Nonrecurring'] = $true
                }
                SMS_ST_RecurInterval {
                    if ($Schedule.MinuteSpan -ne 0) {
                        $Span = 'Minutes'
                        $Interval = $Schedule.MinuteSpan
                    }
                    elseif ($Schedule.HourSpan -ne 0) {
                        $Span = 'Hours'
                        $Interval = $Schedule.HourSpan
                    }
                    elseif ($Schedule.DaySpan -ne 0) {
                        $Span = 'Days'
                        $Interval = $Schedule.DaySpan
                    }
                    $NewSchedSplat['RecurInterval'] = $Span
                    $NewSchedSplat['RecurCount'] = $Interval
                }
                SMS_ST_RecurWeekly {
                    $NewSchedSplat['DayOfWeek'] = [DayOfWeek]($Day - $Schedule.Day)
                    $NewSchedSplat['RecurCount'] = $Schedule.ForNumberOfWeeks
                }
                SMS_ST_RecurMonthlyByWeekday {
                    $NewSchedSplat['DayOfWeek'] = [DayOfWeek]($Day - $Schedule.Day)
                    $NewSchedSplat['WeekOrder'] = $Schedule.WeekOrder
                    $NewSchedSplat['RecurCount'] = $Schedule.ForNumberOfMonths
                }
                SMS_ST_RecurMonthlyByDate {
                    $NewSchedSplat['DayOfMonth'] = $Schedule.MonthDay
                    $NewSchedSplat['RecurCount'] = $Schedule.ForNumberOfMonths
                }
                Default {
                    Write-Error "Parsing Schedule String resulted in invalid type of $RecurType"
                }
            }
            #endregion based on recur type, we will add parameters to our $NewSchedSplat

            New-CMSchedule @NewSchedSplat
        }
    }
}