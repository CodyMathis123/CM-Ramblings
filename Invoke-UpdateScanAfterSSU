#region detection
$TaskName = 'Invoke-UpdateScanAfterSSU'

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

$null -ne $Task
#endregion detection

#region remediation
$TaskName = 'Invoke-UpdateScanAfterSSU'

$TaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" 
  xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2019-05-22T23:53:35.7629665</Date>
    <Author>MASON_NTD\sa869791</Author>
    <URI>\$TaskName</URI>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>PT15M</Duration>
        <StopAtDurationEnd>true</StopAtDurationEnd>
      </Repetition>
      <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-WindowsUpdateClient'] and EventID=19]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT1M</Delay>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
      <Arguments>-command "&amp;{`$TimeFrame=(Get-Date).AddMinutes(-17);`$Filter=@{LogName='System';StartTime=`$TimeFrame;Id='19';ProviderName='Microsoft-Windows-WindowsUpdateClient';};`$Events=Get-WinEvent -FilterHashtable `$Filter;foreach(`$Event in `$Events){switch -Regex (`$Event.Message){'Servicing Stack Update'{foreach(`$Schedule in @('108','113')){`$ScheduleString = [string]::Format('{{00000000-0000-0000-0000-000000000{0}}}',`$Schedule);`$invokeWmiMethodSplat=@{Name='TriggerSchedule';Namespace='root\ccm';Class='sms_client';ArgumentList=`$ScheduleString;ErrorAction='Stop';};Invoke-WmiMethod @invokeWmiMethodSplat;}}}}}"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Register-ScheduledTask -Xml $TaskXML -TaskName $TaskName
#endregion remediation
