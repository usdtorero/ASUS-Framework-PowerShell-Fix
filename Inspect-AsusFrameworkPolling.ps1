#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only ASUS Framework polling diagnostic.
.DESCRIPTION
    Reports relevant scheduled task state and processes. Optionally observes
    for new ASUS WMI PowerShell transcripts without printing transcript contents.
    Does not modify ASUS services, tasks, files, or PowerShell policy.
.EXAMPLE
    .\Inspect-AsusFrameworkPolling.ps1 -ObserveSeconds 70
#>
[CmdletBinding()]
param(
    [ValidateRange(0,300)][int]$ObserveSeconds = 0,
    [switch]$CopyToClipboard
)

$ErrorActionPreference = 'Stop'
$report = [System.Collections.Generic.List[string]]::new()
$report.Add('=== ASUS FRAMEWORK POLLING INSPECTION ===')
$report.Add('No system changes performed.')

try {
    $task = @(Get-ScheduledTask -ErrorAction Stop | Where-Object {
        $_.TaskPath -eq '\ASUS\' -and $_.TaskName -eq 'ArmourySocketServer'
    })
    if ($task.Count -eq 1) {
        $report.Add("Task: \ASUS\ArmourySocketServer [$($task[0].State)]")
        foreach ($action in $task[0].Actions) {
            $report.Add("Action: $($action.Execute)")
        }
    } else {
        $report.Add('Task: \ASUS\ArmourySocketServer not found.')
    }
}
catch {
    $report.Add("Could not inspect scheduled tasks: $($_.Exception.Message)")
}

try {
    $procs = @(Get-CimInstance Win32_Process -Filter "Name='asus_framework.exe' OR Name='ArmourySocketServer.exe'" -ErrorAction Stop)
    $report.Add("ASUS Framework / SocketServer process count: $($procs.Count)")
    foreach ($p in $procs) {
        $report.Add("$($p.Name) PID $($p.ProcessId)")
    }
}
catch {
    $report.Add("Could not inspect processes: $($_.Exception.Message)")
}

$begin = Get-Date
if ($ObserveSeconds -gt 0) {
    Write-Host "Observing for $ObserveSeconds seconds..." 
    Start-Sleep -Seconds $ObserveSeconds
}
$cutoff = if ($ObserveSeconds -gt 0) { $begin } else { (Get-Date).AddMinutes(-15) }
$root = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell-Transcripts'

if (-not (Test-Path -LiteralPath $root)) {
    $report.Add('Transcript directory not found at the default location; no transcript analysis performed.')
}
else {
    $matching = 0
    $candidateCount = 0
    $errors = 0
    $days = @($cutoff.ToString('yyyyMMdd'); (Get-Date).ToString('yyyyMMdd'))
    foreach ($day in ($days | Select-Object -Unique)) {
        $folder = Join-Path $root $day
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $folder -File -Filter '*.txt' -ErrorAction SilentlyContinue)) {
            if ($file.LastWriteTime -lt $cutoff) { continue }
            $candidateCount++
            try {
                $header = Get-Content -LiteralPath $file.FullName -TotalCount 22 -ErrorAction Stop
                if ($header -match '^Host Application:\s*powershell\.exe\s+-c\s+gwmi\s+win32_process') {
                    $matching++
                }
            }
            catch { $errors++ }
        }
    }
    $report.Add("Transcript sample window start: $($cutoff.ToString('s'))")
    $report.Add("New/recent transcripts sampled: $candidateCount")
    $report.Add("ASUS WMI monitoring transcripts: $matching")
    $report.Add("Unreadable transcripts: $errors")
}

$output = $report -join [Environment]::NewLine
Write-Output $output
if ($CopyToClipboard) {
    Set-Clipboard -Value $output
}
