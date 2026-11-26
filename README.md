<p align="center">
  <img src="./assets/banner.svg" alt="Windows Log Toolkit banner" width="100%">
</p>

# Windows Log Toolkit

[![Release](https://img.shields.io/github/v/release/lorenzocaputodev/windows-log-toolkit)](https://github.com/lorenzocaputodev/windows-log-toolkit/releases/latest) [![License](https://img.shields.io/github/license/lorenzocaputodev/windows-log-toolkit)](LICENSE) ![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)

Two batch scripts to preserve Windows diagnostic data before you start troubleshooting, and to clear Event Viewer history afterwards:

- 🔎 **`extract_logs.bat`** — collects event logs, crash dumps, driver list and system info into a timestamped folder
- 🧹 **`clean_logs.bat`** — clears Windows Event Viewer logs, with an optional report

> [!WARNING]
> `clean_logs.bat` permanently erases Event Viewer history. Run `extract_logs.bat` first if you might need those logs.

## Quick start

1. Download the latest version from the [Releases page](https://github.com/lorenzocaputodev/windows-log-toolkit/releases/latest), or clone the repository.
2. Double click the script and accept the Windows prompt asking for Administrator rights (or right click it and choose **Run as administrator**).
3. Run `extract_logs.bat` first, check the output folder, and run `clean_logs.bat` only if you really want to clear the logs.

Nothing is uploaded anywhere: both scripts only write files locally.

## Requirements

- Windows 10 or 11 with `cmd.exe`, `wevtutil` and PowerShell (all included by default)
- **Administrator privileges** — if missing, both scripts ask for them and restart in a new window; if you refuse, they exit with an error message

## `extract_logs.bat`

Creates a folder on your Desktop and fills it with the following:

| Output | Content |
|---|---|
| `System_Errors_Warnings.txt` | System errors + warnings, last `HOURS` hours, up to `MAX_EVENTS` entries |
| `Application_Errors_Warnings.txt` | Application errors + warnings, same limits |
| `Setup_Errors_Warnings.txt` | Setup log errors + warnings (Windows Update installs), same limits |
| `Raw_EVTX\System.evtx`, `Application.evtx`, `Setup.evtx` | Full logs as available at that moment |
| `Dumps\*.dmp` | Minidumps from `%SystemRoot%\Minidump\`, if present |
| `Dumps\MEMORY.DMP` | Full memory dump from `%SystemRoot%`, if present and confirmed (see `FULL_DUMP`) |
| `LiveKernelReports\` | `.dmp` files from `%SystemRoot%\LiveKernelReports\`: hangs and driver resets (often GPU or USB) that did not cause a blue screen |
| `WER\` | Windows Error Reporting `Report.wer` files (app crashes and hangs) from the last `HOURS` hours, rounded up to whole days |
| `systeminfo.txt` | `systeminfo` output |
| `driverquery.txt` | `driverquery` output (`/v` optional) |
| `tasklist.txt` | `tasklist /v` output |
| `ipconfig.txt` | `ipconfig /all` output |
| `installed_updates.txt` | Installed Windows updates (`Get-HotFix`), newest first |
| `disk_health.txt` | Health status of each physical disk, plus temperature, wear and read/write errors when the disk reports them |
| `collection_report.txt` | Outcome (`OK` / `FAILED` / `SKIPPED` / `INFO`) of every item |

The readable `.txt` extracts and the WER reports are limited to the time window; the raw `.evtx` exports and the dumps are not.

```text
<Desktop>\windows_logs_YYYY-MM-DD_HH-mm-ss\
├─ Application_Errors_Warnings.txt
├─ Setup_Errors_Warnings.txt
├─ System_Errors_Warnings.txt
├─ collection_report.txt
├─ disk_health.txt
├─ driverquery.txt
├─ installed_updates.txt
├─ ipconfig.txt
├─ systeminfo.txt
├─ tasklist.txt
├─ Dumps\
├─ LiveKernelReports\
├─ Raw_EVTX\
└─ WER\
```

### Settings

At the top of `extract_logs.bat`:

```bat
set "HOURS=24"
set "MAX_EVENTS=300"
set "DRIVERQUERY_VERBOSE=0"
set "FULL_DUMP=ask"
```

- `HOURS` — time window for the `.txt` extracts and WER reports, e.g. `168` for a week. Invalid values fall back to `24`.
- `MAX_EVENTS` — max entries per event query. Lower = faster, less history.
- `DRIVERQUERY_VERBOSE` — `1` for full `driverquery /v` (slower; signatures, paths), `0` for the fast version.
- `FULL_DUMP` — what to do with `MEMORY.DMP`, which can be several GB: `ask` (default) shows its size and asks before the collection starts, `yes` always copies it, `no` never does. In every case it is skipped if the output drive would be left with less than 1 GB free.

### Output location

Both scripts use `[Environment]::GetFolderPath('Desktop')` rather than a hardcoded `%USERPROFILE%\Desktop`, so redirected Desktops (e.g. OneDrive Known Folder Move) work. If the path can't be resolved, the scripts print a warning and use the folder they are run from. Each run gets its own timestamp, so previous results are never overwritten.

## `clean_logs.bat`

Enumerates every Event Viewer channel with `wevtutil el` and clears it with `wevtutil cl`. It clears **entire logs**, not a time window.

- Logs that are already empty are skipped (there is nothing to clear), so a run is much faster than trying 1000+ channels one by one. Logs whose event count can't be read are always tried.
- Enabled Analytic and Debug logs can only be cleared while disabled: when clearing one of them fails, the script disables it, clears it and enables it again. If it can't be enabled again, the report says so with a `[WARN]` line.
- Some logs only allow reading, even for Administrators (for example `Microsoft-Windows-LiveId/Operational`). When clearing fails, the script checks the log's permissions and marks these as `[PROTECTED]` instead of `[FAILED]`, so `[FAILED]` only means a real error.

1. Confirm the warning prompt.
2. Choose whether to save a report (`Save a report file? [Y/N]`):
   - **Y** — saves `<Desktop>\clean_logs_report_YYYY-MM-DD_HH-mm-ss.txt` with the result of each log and a summary
   - **N** — no file is written; the on-screen summary is still shown
3. Read the summary at the end: logs cleaned, already empty, protected, failed, and about how much disk space was freed.

Some logs may still fail to clear because they are in use or unavailable on that system. Windows also records the clearing itself (event 1102 in Security, 104 in System).

## Recommended workflow

1. Run `extract_logs.bat`.
2. Open the output folder and confirm the files were created.
3. Archive or share the folder if needed (see below).
4. Run `clean_logs.bat` only if you intentionally want to reset Event Viewer history.

Typical uses: debugging blue screens and crashes, keeping evidence before a cleanup, gathering material for support requests.

## Privacy

The extracted folder can contain **personal data**. Memory dumps, `.evtx` files, WER reports, the process list, `ipconfig` and `systeminfo` can reveal user names, machine names, file paths and possibly memory contents. Review it before posting it publicly.

## Customization

- More channels: add `call :EventText <channel>` or `call :ExportEvtx <channel>` lines.
- More commands: add a `call :Step "..."` line, the command and `call :Report %errorlevel% "<file>"`, then raise `STEPS`. Examples: `dxdiag /t <file>` or `Get-CimInstance` output. `wmic` is deprecated and missing on recent Windows 11 builds.
- Different output folder: change `:InitContext`.

## Changelog and license

Version history is in [CHANGELOG.md](./CHANGELOG.md). Released under the [MIT License](./LICENSE).
