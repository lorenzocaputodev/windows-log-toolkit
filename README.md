<p align="center">
  <img src="./assets/banner.svg" alt="Windows Log Toolkit banner" width="100%">
</p>

# Windows Log Toolkit

A small Windows troubleshooting toolkit made of two batch scripts, for when Event Viewer data, crash dumps, driver lists, and system information are the first things you want to preserve before touching anything:

- 🔎 **`extract_logs.bat`** — collects useful diagnostic data into a timestamped folder
- 🧹 **`clean_logs.bat`** — clears Windows Event Viewer logs and saves a cleanup report

Each run uses its own timestamped folder/report, so previous results are never overwritten. See [Recommended workflow](#-recommended-workflow) for the intended extract-then-clean sequence.

---

## 📦 Included files

```text
.
├─ extract_logs.bat
├─ clean_logs.bat
├─ README.md
├─ .gitignore
└─ assets/
   └─ banner.svg
```

---

## 🚀 Quick start

### 1) Extract logs
Run:

```bat
extract_logs.bat
```

Use this **before** clearing logs. See [Requirements](#-requirements) for Administrator notes and [Recommended workflow](#-recommended-workflow) for the full sequence.

### 2) Clean logs
Run:

```bat
clean_logs.bat
```

Use only after you have saved what you need (see [Safety notes](#-safety-notes)), and confirm the warning prompt before proceeding.

---

## 🔎 What `extract_logs.bat` does

The script resolves the current user's Desktop path and creates a timestamped output folder there:

```text
<Desktop>\windows_logs_YYYY-MM-DD_HH-mm-ss
```

If the Desktop path can't be resolved (or doesn't exist), the script falls back to the folder the script itself is running from — see [Output location](#output-location) below.

### It collects

- **System errors + warnings** (combined, last 24 hours)
- **Application errors + warnings** (combined, last 24 hours)
- Raw **`System.evtx`** export
- Raw **`Application.evtx`** export
- **Minidumps** from `C:\Windows\Minidump\` if present
- **`MEMORY.DMP`** if present
- **`systeminfo`** output
- **`driverquery`** output (fast mode by default, `/v` optional — see Tunable settings below)
- **`tasklist /v`** output
- A plain text **collection report**

### Output location

Both scripts resolve their output folder with `[Environment]::GetFolderPath('Desktop')` instead of a hardcoded `%USERPROFILE%\Desktop`. This is more reliable on setups where the Desktop has been redirected (e.g. OneDrive Known Folder Move) or on non-standard profiles. If the resolved path is empty or doesn't exist, the scripts fall back to the folder they're run from.

### Tunable settings

At the top of `extract_logs.bat` you can adjust two variables:

```bat
set "MAX_EVENTS=300"
set "DRIVERQUERY_VERBOSE=0"
```

- `MAX_EVENTS` — max number of entries pulled per event query. Lower = faster, less history captured.
- `DRIVERQUERY_VERBOSE` — set to `1` for the full `driverquery /v` (slower, more detail: digital signatures, driver paths, etc.), or leave at `0` for the fast version.

These defaults were chosen to keep the script quick while still combining errors and warnings into a single query per channel (2 queries total instead of 4), which is the main efficiency change from earlier versions.

### Time window: `.txt` vs `.evtx`

The readable `.txt` event extracts are limited to:
- the **last 24 hours**
- a capped number of entries per query

The raw `.evtx` exports are different:
- they are intended to preserve the **full exported channel content available at that moment**
- they are **not limited to the last 24 hours** by the batch logic

### Typical output structure

```text
windows_logs_2026-04-14_12-00-00/
├─ Application_Errors_Warnings.txt
├─ System_Errors_Warnings.txt
├─ collection_report.txt
├─ driverquery.txt
├─ systeminfo.txt
├─ tasklist.txt
├─ Dumps/
│  ├─ *.dmp
│  └─ MEMORY.DMP
└─ Raw_EVTX/
   ├─ Application.evtx
   └─ System.evtx
```

---

## 🧹 What `clean_logs.bat` does

The script enumerates Windows Event Viewer channels with `wevtutil el` and then tries to clear each one with `wevtutil cl`.

### Full logs, not a time window

This means the script attempts to clear **entire logs**, not just the last 24 hours.

If a log is listed by `wevtutil el`, the script will try to clear it fully.

### What it saves

After confirming the cleanup, you are asked a second question:

```text
Save a report file on the Desktop? [Y/N]
```

- **Y** — a timestamped report is saved (same [output location](#output-location) logic as `extract_logs.bat`):
  ```text
  <Desktop>\clean_logs_report_YYYY-MM-DD_HH-mm-ss.txt
  ```
- **N** — no report file is written; the cleanup still runs normally and the on-screen summary (cleaned/failed counts) is still shown at the end.

### Final result

The script shows:
- how many logs were cleared successfully
- how many failed
- where the report was saved

### Performance note

The cleanup loop uses two separate code paths (with/without report) chosen once at the start, instead of checking the "save report?" choice on every single log channel. This avoids repeated condition checks across potentially 100+ channels and keeps the loop as fast as the very first version of the script, regardless of whether you choose to save a report.

### Notes

Some logs may fail to clear because they are:
- protected
- currently in use
- unavailable on that system

---

## ✅ Recommended workflow

### Safe workflow

1. Run **`extract_logs.bat`**
2. Open the output folder and confirm files were created
3. Archive or share the folder if needed
4. Run **`clean_logs.bat`** only if you intentionally want to clear Event Viewer history

### Good use cases

- Debugging blue screens or crashes
- Preserving logs before cleanup
- Collecting quick troubleshooting material for forums or support chats
- Resetting Event Viewer history after saving the important data

---

## ⚠ Safety notes

- `clean_logs.bat` is **destructive for Event Viewer history**
- Always run `extract_logs.bat` first if there is any chance you will need those logs later
- The toolkit does **not** upload anything anywhere — the scripts only save files locally on the machine where they are run

---

## ⚙ Requirements

- Windows
- `cmd.exe`
- `wevtutil`
- PowerShell available in the system
- Administrator privileges for best results

These tools are normally present on standard Windows installations.

---

## 🛠 Customization ideas

You can easily adapt the scripts if you want to:

- change the time window from **24 hours** to **7 days**
- export more channels than just `System` and `Application`
- increase or decrease `MAX_EVENTS` in `extract_logs.bat`
- set `DRIVERQUERY_VERBOSE=1` for full driver signature detail
- collect additional commands such as `ipconfig /all`, `dxdiag`, or `wmic` output
- change `:ResolveOutputDir` to always save somewhere other than the Desktop

---

## 📌 Summary

- 🔎 `extract_logs.bat` = **collect first** — see [What it collects](#it-collects) and [Tunable settings](#tunable-settings)
- 🧹 `clean_logs.bat` = **clear later if needed** — see [What it saves](#what-it-saves)
- Safety and requirements — see [Safety notes](#-safety-notes) and [Requirements](#-requirements)
- Want to adapt the scripts? — see [Customization ideas](#-customization-ideas)
