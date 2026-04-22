<p align="center">
  <img src="./assets/banner.svg" alt="Windows Log Toolkit banner" width="100%">
</p>

# Windows Log Toolkit

A small Windows troubleshooting toolkit made of two batch scripts:

- 🔎 **`extract_logs.bat`** — collects useful diagnostic data into a timestamped folder
- 🧹 **`clean_logs.bat`** — clears Windows Event Viewer logs and saves a cleanup report

The toolkit is designed for a simple workflow:

1. **Extract first**
2. Review or archive the collected data
3. **Clean only if needed**

---

## ✨ Why this toolkit exists

When you are troubleshooting Windows issues, Event Viewer data, crash dumps, driver lists, and system information are often the first things you want to preserve.

This toolkit helps you do that quickly with a pair of plain batch files:

- one script for **safe collection**
- one script for **intentional cleanup**

It keeps runs separated with timestamped folders and reports so previous results are not overwritten.

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

Recommended:
- Run as **Administrator**
- Use this **before** clearing logs
- Keep the generated folder if you may need to share logs later

### 2) Clean logs
Run:

```bat
clean_logs.bat
```

Recommended:
- Run as **Administrator**
- Use only after you have already saved what you need
- Confirm the warning prompt before proceeding

---

## 🔎 What `extract_logs.bat` does

The script creates a timestamped output folder on the current user's Desktop:

```text
%USERPROFILE%\Desktop\windows_logs_YYYY-MM-DD_HH-mm-ss
```

### It collects

- **System errors** from the last 24 hours
- **Application errors** from the last 24 hours
- **System warnings** from the last 24 hours
- **Application warnings** from the last 24 hours
- Raw **`System.evtx`** export
- Raw **`Application.evtx`** export
- **Minidumps** from `C:\Windows\Minidump\` if present
- **`MEMORY.DMP`** if present
- **`systeminfo`** output
- **`driverquery /v`** output
- **`tasklist /v`** output
- A plain text **collection report**

### Important behavior

The readable `.txt` event extracts are limited to:
- the **last 24 hours**
- a capped number of entries per query

The raw `.evtx` exports are different:
- they are intended to preserve the **full exported channel content available at that moment**
- they are **not limited to the last 24 hours** by the batch logic

### Typical output structure

```text
windows_logs_2026-04-14_12-00-00/
├─ Application_Errors.txt
├─ Application_Warnings.txt
├─ System_Errors.txt
├─ System_Warnings.txt
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

### Important behavior

This means the script attempts to clear **entire logs**, not just the last 24 hours.

If a log is listed by `wevtutil el`, the script will try to clear it fully.

### What it saves

A timestamped report on the Desktop:

```text
%USERPROFILE%\Desktop\clean_logs_report_YYYY-MM-DD_HH-mm-ss.txt
```

### Final result

The script shows:
- how many logs were cleared successfully
- how many failed
- where the report was saved

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

## ⚠️ Safety notes

- `clean_logs.bat` is **destructive for Event Viewer history**
- Always run `extract_logs.bat` first if there is any chance you will need those logs later
- Administrator rights are strongly recommended for both scripts
- The toolkit does **not** upload anything anywhere
- The scripts only save files locally on the machine where they are run

---

## ⚙️ Requirements

- Windows
- `cmd.exe`
- `wevtutil`
- PowerShell available in the system
- Administrator privileges for best results

These tools are normally present on standard Windows installations.

---

## 🛠️ Customization ideas

You can easily adapt the scripts if you want to:

- change the time window from **24 hours** to **7 days**
- export more channels than just `System` and `Application`
- increase or decrease the number of extracted entries
- collect additional commands such as `ipconfig /all`, `dxdiag`, or `wmic` output
- save output somewhere other than the Desktop

---

## 📌 Summary

- 🔎 `extract_logs.bat` = **collect first**
- 🧹 `clean_logs.bat` = **clear later if needed**
- `.txt` extracts = **last 24 hours**
- `.evtx` exports = **raw full exports available at run time**
- cleanup = **attempts to clear all enumerated Event Viewer logs**

---

## 🤖 **Notes**

This project was designed and refined by me, with targeted AI support in selected phases such as code review, refactoring, copy polishing, and visual or technical refinement.

AI was used as a support tool, not as a substitute for my work. Direction, final decisions, validation, and overall quality were handled by me.
