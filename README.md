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
2. Right click the script and choose **Run as administrator**.
3. Run `extract_logs.bat` first, check the output folder, and run `clean_logs.bat` only if you really want to clear the logs.

Nothing is uploaded anywhere: both scripts only write files locally.

## Requirements

- Windows 10 or 11 with `cmd.exe`, `wevtutil` and PowerShell (all included by default)
- **Administrator privileges** — both scripts check for them at startup and exit with an error message if missing

## `extract_logs.bat`

Creates a folder on your Desktop and fills it with the following:

| Output | Content |
|---|---|
| `System_Errors_Warnings.txt` | System errors + warnings, last 24 hours, up to `MAX_EVENTS` entries |
| `Application_Errors_Warnings.txt` | Application errors + warnings, last 24 hours, up to `MAX_EVENTS` entries |
| `Raw_EVTX\System.evtx` | Full System log as available at that moment |
| `Raw_EVTX\Application.evtx` | Full Application log as available at that moment |
| `Dumps\*.dmp` | Minidumps from `%SystemRoot%\Minidump\`, if present |
| `Dumps\MEMORY.DMP` | Full memory dump from `%SystemRoot%`, if present (can be several GB) |
| `systeminfo.txt` | `systeminfo` output |
| `driverquery.txt` | `driverquery` output (`/v` optional) |
| `tasklist.txt` | `tasklist /v` output |
| `collection_report.txt` | Outcome (`OK` / `FAILED`) of every step |

The readable `.txt` extracts are limited to the last 24 hours; the raw `.evtx` exports are not.

```text
<Desktop>\windows_logs_YYYY-MM-DD_HH-mm-ss\
├─ Application_Errors_Warnings.txt
├─ System_Errors_Warnings.txt
├─ collection_report.txt
├─ driverquery.txt
├─ systeminfo.txt
├─ tasklist.txt
├─ Dumps\
└─ Raw_EVTX\
```

### Settings

At the top of `extract_logs.bat`:

```bat
set "MAX_EVENTS=300"
set "DRIVERQUERY_VERBOSE=0"
```

- `MAX_EVENTS` — max entries per event query. Lower = faster, less history.
- `DRIVERQUERY_VERBOSE` — `1` for full `driverquery /v` (slower; signatures, paths), `0` for the fast version.

### Output location

Both scripts use `[Environment]::GetFolderPath('Desktop')` rather than a hardcoded `%USERPROFILE%\Desktop`, so redirected Desktops (e.g. OneDrive Known Folder Move) work. If the path can't be resolved, the scripts print a warning and use the folder they are run from. Each run gets its own timestamp, so previous results are never overwritten.

## `clean_logs.bat`

Enumerates every Event Viewer channel with `wevtutil el` and tries to clear it with `wevtutil cl`. It clears **entire logs**, not a time window.

1. Confirm the warning prompt.
2. Choose whether to save a report (`Save a report file? [Y/N]`):
   - **Y** — saves `<Desktop>\clean_logs_report_YYYY-MM-DD_HH-mm-ss.txt` with the result of each log and a summary
   - **N** — no file is written; the on-screen summary (cleaned / failed) is still shown
3. Read the summary at the end.

Some logs may fail to clear because they are protected, in use, or unavailable on that system. Windows also records the clearing itself (event 1102 in Security, 104 in System).

## Recommended workflow

1. Run `extract_logs.bat`.
2. Open the output folder and confirm the files were created.
3. Archive or share the folder if needed (see below).
4. Run `clean_logs.bat` only if you intentionally want to reset Event Viewer history.

Typical uses: debugging blue screens and crashes, keeping evidence before a cleanup, gathering material for support requests.

## Privacy

The extracted folder can contain **personal data**. Memory dumps, `.evtx` files, the process list and `systeminfo` can reveal user names, machine names, file paths and possibly memory contents. Review it before posting it publicly.

## Customization

- Time window: edit the `86400000` (milliseconds) value in the `:EventText` subroutine, e.g. `604800000` for 7 days.
- More channels: add `call :EventText <channel>` or `call :ExportEvtx <channel>` lines.
- More commands: add steps such as `ipconfig /all`, `dxdiag` or `Get-CimInstance` output. `wmic` is deprecated and missing on recent Windows 11 builds.
- Different output folder: change `:InitContext`.

## Changelog and license

Version history is in [CHANGELOG.md](./CHANGELOG.md). Released under the [MIT License](./LICENSE).
