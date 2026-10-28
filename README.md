# ASUS Framework spawning PowerShell every ~30 seconds (Windows)

A reproducible Windows/ASUS Armoury Crate issue: `asus_framework.exe` repeatedly creates 32-bit Windows PowerShell processes to query process statistics through WMI. On systems with PowerShell transcription enabled, each invocation can create another transcript file.

**Status:** Confirmed behavior and a **reversible, machine-specific workaround**. This is **not** a patch to ASUS software or a proven universal fix.

## Symptoms

- Brief, recurring `powershell.exe` processes, approximately every 30 seconds.
- A matching process-create event in Microsoft Sysinternals Process Monitor:
  - **Parent:** `asus_framework.exe`
  - **Child image:** `C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`
  - **Command pattern:**

```powershell
powershell.exe -c gwmi win32_process -Filter 'ProcessId=<pid> or ProcessId=<pid> or ProcessId=<pid>' | select CreationDate,KernelModeTime,ParentProcessId,ProcessId,UserModeTime,WorkingSetSize | format-table
```

- A corresponding `conhost.exe` process may be created by PowerShell.
- On a machine with transcription policy enabled, these processes generated numerous small transcript files. One observed directory contained **80,173 transcripts / 132.93 MB across 60 days**; a sample of the newest 100 transcripts all contained the ASUS WMI command. **That count is not a claim that every historical transcript was caused by ASUS.**
- Potential intermittent responsiveness impact is plausible but **not proven** by the local test.

## Environment observed (October 28, 2026)

| Component | Observed version |
|---|---|
| ASUS Framework Service / ArmouryDevice | 4.2.5.4 |
| Armoury Crate | 6.7.6.0 |
| Aura Creator | 4.7.4.0 |
| OS | Windows 11 |
| PowerShell used for diagnostics | 7.6.9 |
| Device | ASUS ROG Strix Scope II X keyboard |

Updating keyboard SDK/HAL components **did not** eliminate the WMI polling behavior in this case.

## Root cause evidence (process lineage)

Microsoft Process Monitor recorded `asus_framework.exe` creating the PowerShell command above at three successive ~30-second intervals.

A separate process parent inspection showed:

```text
\ASUS\ArmourySocketServer (scheduled task, observed on this machine)
    -> ArmourySocketServer.exe
       -> asus_framework.exe (parent instance)
          -> asus_framework.exe (child instances)
             -> powershell.exe -c gwmi win32_process ...
```

On this machine, the scheduled task action was:

```text
C:\Program Files (x86)\ASUS\ArmouryDevice\dll\ArmourySocketServer\TaskSchedulerTool_ArmourySocketServer.exe
```

**Do not assume all systems use this exact task.** Verify the task's action before changing anything.

## Reversible workaround

The scripts in this directory are deliberately conservative:

| Script | Purpose |
|---|---|
| `Inspect-AsusFrameworkPolling.ps1` | Read-only: inspect the task, processes, and recent matching transcript headers |
| `Stop-AsusFrameworkPolling.ps1` | Preview by default; with `-Apply`, export the task definition, disable the **verified** task, stop only the identified processes |
| `Restore-AsusFrameworkPolling.ps1` | Preview by default; with `-Apply`, re-enable the same task |

1. Back up any custom Aura Creator lighting profiles before changes.
2. Review the scripts. Open **PowerShell as Administrator** only for an `-Apply` operation.
3. In this directory:

```powershell
.\Inspect-AsusFrameworkPolling.ps1
.\Stop-AsusFrameworkPolling.ps1
.\Stop-AsusFrameworkPolling.ps1 -Apply
.\Inspect-AsusFrameworkPolling.ps1 -ObserveSeconds 70
```

The stop script exports the task's XML before disabling it. It does **not** uninstall Armoury Crate, change service startup types, delete transcripts, or modify ASUS files. On the observed machine, PowerShell process spawning ceased and the existing Matrix-style keyboard lighting effect continued to work, but that outcome is **not guaranteed** for other ASUS products.

To restore the task (may require restarting Armoury Crate or Windows afterward):

```powershell
.\Restore-AsusFrameworkPolling.ps1 -Apply
```

### Risks and limitations

- Disabling ArmourySocketServer can interfere with Armoury Crate device discovery, configuration, macros, lighting controls, updates, or other ASUS features. If anything breaks, restore it.
- Administrator privileges and organizational IT approval may be required, particularly on managed computers.
- Other ASUS components or future updates may re-enable the task, or recreate Framework processes via another route.
- This is **containment**, not a correction to the underlying ASUS application code.
- **Do not disable Windows PowerShell transcription as a substitute for addressing process spawning.** Transcription is only revealing the repeated launches.
- Do not post raw PowerShell transcripts or process dumps publicly; they may contain usernames, document paths, commands, or confidential information.
- The observed WMI command reads process statistics. **No network exfiltration was established** by this investigation; local transcript accumulation is a separate data-retention concern.

## Independent reports and further investigation

- [ASUS ROG forum: Armoury Crate PowerShell scripts spam (April 2026)](https://rog-forum.asus.com/t5/armoury-crate/armoury-crate-powershell-scripts-spam/td-p/1145445)
- [ASUS ROG forum: ArmouryDevice spawns PowerShell every 30 seconds (August 2026)](https://rog-forum.asus.com/t5/armoury-crate/armourydevice-asus-framework-exe-spawns-20-powershell-every-30s/td-p/1157819)
- [Microsoft Sysinternals Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)
- [pidusage issue describing the same `gwmi` command pattern](https://github.com/soyuka/pidusage/issues/192). The pattern is suggestive, **but we have not confirmed ASUS's internal dependencies or implementation.**

## Help improve this report

Share **redacted** product versions, the Process Monitor parent/child chain, whether the scheduled task exists, and whether the workaround works. Never share raw workstation transcripts or private paths.

## License

Scripts in this directory are provided under the MIT License (see `LICENSE`). Use at your own risk; no warranty or ASUS affiliation.
