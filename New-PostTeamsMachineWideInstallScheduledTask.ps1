<#
.SYNOPSIS
    Launch the Teams install as the logged in user via a scheduled task
.DESCRIPTION
    This script will create a scheduled task if one is not found which is used to
    install Microsoft Teams as the logged in user. This scheduled task executes
    the Teams.exe found in %ProgramFiles% so that a user can start using Teams
    shortly after the Machine Wide installer completes instead of having to 
    log off and back on.
.NOTES
    Generally used as a script that runs after a Teams Machine Wide Installer completes
#>
if (!(Get-ScheduledTask -TaskName 'Teams User Install - Post Machine Wide Install' -ErrorAction SilentlyContinue)) {
    switch ([System.Environment]::Is64BitOperatingSystem) {
        $true {
            [string]$TeamsMachineInstaller = Get-ItemPropertyValue -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\ -Name TeamsMachineInstaller -ErrorAction Stop
            [string]$Exe = $TeamsMachineInstaller.Substring(0, $TeamsMachineInstaller.IndexOf('.exe') + 4).Trim() -Replace "C:\\Program Files\\", "${env:ProgramFiles(x86)}\"
    
        }
        $false {
            [string]$TeamsMachineInstaller = Get-ItemPropertyValue -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\ -Name TeamsMachineInstaller -ErrorAction Stop
            [string]$Exe = $TeamsMachineInstaller.Substring(0, $TeamsMachineInstaller.IndexOf('.exe') + 4).Trim()
        }
    }
    [string]$InstallerArgs = $TeamsMachineInstaller.Substring($Exe.Length, $TeamsMachineInstaller.Length - $exe.Length).Trim()
    $newScheduledTaskSplat = @{
        Action      = New-ScheduledTaskAction -Execute $Exe -Argument $InstallerArgs
        Description = 'Start the Teams installer for the currently logged on user after a Teams Machine Wide install'
        Settings    = New-ScheduledTaskSettingsSet -Compatibility Vista -AllowStartIfOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Trigger     = New-ScheduledTaskTrigger -At ($Start = (Get-Date).AddSeconds(5)) -Once
        Principal   = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
    }
    
    $ScheduledTask = New-ScheduledTask @newScheduledTaskSplat
    $ScheduledTask.Settings.DeleteExpiredTaskAfter = "PT0S"
    $ScheduledTask.Triggers[0].StartBoundary = $Start.ToString("yyyy-MM-dd'T'HH:mm:ss")
    $ScheduledTask.Triggers[0].EndBoundary = $Start.AddMinutes(10).ToString('s')
    
    Register-ScheduledTask -InputObject $ScheduledTask -TaskName 'Teams User Install - Post Machine Wide Install'
}