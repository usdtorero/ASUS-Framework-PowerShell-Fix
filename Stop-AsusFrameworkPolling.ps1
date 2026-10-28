#Requires -Version 5.1
<#
.SYNOPSIS
    Reversible containment for ASUS Framework's recurring PowerShell launches.
.DESCRIPTION
    Without arguments, previews the action without changing anything.
    With -Apply, validates the observed ASUS task, exports its XML locally,
    disables it and stops the associated processes. May disrupt Armoury Crate.
    This does not patch ASUS software.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$BackupDirectory = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ASUS-Framework-Task-Backups')
)

$ErrorActionPreference = 'Stop'
$taskPath = '\ASUS\'
$taskName = 'ArmourySocketServer'
$expectedExe = 'TaskSchedulerTool_ArmourySocketServer.exe'

function Get-TargetProcesses {
    @(Get-CimInstance Win32_Process -Filter "Name='asus_framework.exe' OR Name='ArmourySocketServer.exe'" -ErrorAction Stop)
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
    $matchedActions = @($task.Actions | Where-Object {
        ([string]$_.Execute).Trim('"') -match ([regex]::Escape($expectedExe) + '$')
    })

    if ($matchedActions.Count -eq 0) {
        throw "Task action is not the expected $expectedExe. Nothing changed."
    }

    Write-Host "Task: $taskPath$taskName"
    Write-Host "State: $($task.State)"
    Write-Host "Action: $($matchedActions[0].Execute)"
    $initial = @(Get-TargetProcesses)
    Write-Host "Targeted processes now: $($initial.Count)"

    if (-not $Apply) {
        Write-Host 'PREVIEW ONLY: no changes made.'
        Write-Host 'Run with -Apply in an elevated PowerShell window to proceed.'
        return
    }

    if (-not (Test-IsAdministrator)) {
        throw 'Administrator privileges are required for -Apply.'
    }

    New-Item -ItemType Directory -Path $BackupDirectory -Force -ErrorAction Stop | Out-Null
    $backup = Join-Path $BackupDirectory ('ArmourySocketServer_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.xml')

    Export-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop |
        Set-Content -LiteralPath $backup -Encoding UTF8 -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $backup)) {
        throw 'Task backup was not created. Refusing to disable the task.'
    }
    Write-Host "Task XML backed up locally: $backup"

    if ($task.State -ne 'Disabled') {
        Disable-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop | Out-Null
        Write-Host 'Task disabled.'
    } else {
        Write-Host 'Task was already disabled.'
    }

    foreach ($name in @('ArmourySocketServer.exe', 'asus_framework.exe')) {
        $targets = @(Get-TargetProcesses | Where-Object { $_.Name -eq $name })
        foreach ($p in $targets) {
            try {
                Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction Stop
                Write-Host "Stopped $name (PID $($p.ProcessId))."
            }
            catch {
                Write-Warning "Could not stop $name (PID $($p.ProcessId)): $($_.Exception.Message)"
            }
        }
    }

    Write-Host 'Observing for respawn for 35 seconds...'
    Start-Sleep -Seconds 35

    $afterTask = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
    $remaining = @(Get-TargetProcesses)
    Write-Host "Task state: $($afterTask.State)"
    Write-Host "Remaining ASUS Framework / SocketServer processes: $($remaining.Count)"
    if ($remaining.Count -gt 0) {
        Write-Warning 'Processes remain or restarted: a separate ASUS component may also launch them.'
    } else {
        Write-Host 'No targeted processes found after observation.'
    }
    Write-Host 'Existing transcripts and lighting profiles were not modified.'
}
catch {
    Write-Error "Containment failed: $($_.Exception.Message)"
}
