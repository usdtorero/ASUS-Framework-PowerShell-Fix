#Requires -Version 5.1
<#
.SYNOPSIS
    Restore the ASUS ArmourySocketServer task disabled by the containment script.
.DESCRIPTION
    Preview-only by default. With -Apply in elevated PowerShell, re-enables
    the verified scheduled task. Does not change ASUS files or lighting profiles.
#>
[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$taskPath = '\ASUS\'
$taskName = 'ArmourySocketServer'
$expectedExe = 'TaskSchedulerTool_ArmourySocketServer.exe'

try {
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
    $matched = @($task.Actions | Where-Object {
        ([string]$_.Execute).Trim('"') -match ([regex]::Escape($expectedExe) + '$')
    })
    if ($matched.Count -eq 0) {
        throw 'The task action does not match the expected ASUS launcher. Nothing changed.'
    }

    Write-Host "Task: $taskPath$taskName"
    Write-Host "Current state: $($task.State)"

    if (-not $Apply) {
        Write-Host 'PREVIEW ONLY: no changes made. Use -Apply as Administrator to re-enable.'
        return
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator privileges are required for -Apply.'
    }

    Enable-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop | Out-Null
    $current = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
    Write-Host "Restored task state: $($current.State)"
    Write-Host 'If ASUS features do not return, reopen Armoury Crate or restart Windows.'
}
catch {
    Write-Error "Restore failed: $($_.Exception.Message)"
}
