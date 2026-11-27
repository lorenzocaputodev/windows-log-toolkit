# Changelog

All notable changes to this project are documented here.

## [2.3.1] — 2026-11-27

### Changed
- Clearer wording in the README and in a few on-screen messages ("Right-click the file…")

## [2.3.0] — 2026-11-26

### Added
- Both scripts ask for Administrator rights and restart elevated when started without them, instead of just exiting
- `extract_logs.bat`: `HOURS` setting for the time window of the `.txt` extracts (no more editing the millisecond value in `:EventText`)
- `extract_logs.bat`: `FULL_DUMP` setting (`ask` / `yes` / `no`) for `MEMORY.DMP`; with `ask` the size is shown and the choice is made before the long steps start, and the copy is skipped if it would leave less than 1 GB free
- `extract_logs.bat`: new outputs: Setup log (`.txt` + `.evtx`), Live Kernel Reports, Windows Error Reporting reports, `ipconfig /all`, installed updates, disk health
- `extract_logs.bat`: each result line names its item, and the final screen shows how many items failed
- `clean_logs.bat`: enabled Analytic/Debug logs, which can't be cleared while enabled, are disabled, cleared and enabled again
- `clean_logs.bat`: logs whose permissions don't allow clearing, even for Administrators, are reported as `[PROTECTED]` instead of `[FAILED]`
- `clean_logs.bat`: the summary also shows the logs skipped because already empty, the protected ones, and about how much disk space was freed
- `.gitattributes` keeps Windows line endings in the `.bat` files, which `cmd.exe` needs to find labels reliably

### Changed
- `clean_logs.bat` skips logs that are already empty instead of running `wevtutil cl` on every channel (1000+ on a typical system), which made it slow and inflated the failure count
- The Administrator check uses `fltmc` instead of `net session`, which fails on systems where the Server service is disabled

## [2.2.1] — 2026-09-29

### Fixed
- The Administrator check now actually stops both scripts: `exit /b` inside the `:RequireAdmin` subroutine only returned to the caller, so the script kept running without elevation
- `extract_logs.bat`: the crash dump step now checks the result of each `copy` instead of always reporting `[OK]`, and the report lists the real destination (`Dumps\*.dmp`, `Dumps\MEMORY.DMP`)
- `extract_logs.bat`: dump paths use `%SystemRoot%` instead of a hardcoded `C:\Windows`
- `clean_logs.bat`: the per-log result uses `if errorlevel` instead of `&& (...) || (...)`, which could count a log twice; report lines no longer risk misparsed redirects when a log name ends with a digit
- Removed `EnableDelayedExpansion`, which silently stripped `!` from log names and paths
- Paths with parentheses (e.g. `Program Files (x86)`) no longer break the report messages in `clean_logs.bat`
- The fallback timestamp is now a valid folder name, and a script located at a drive root no longer yields a broken output path

### Changed
- Repeated step logic in `extract_logs.bat` moved into subroutines (`:EventText`, `:ExportEvtx`, `:CopyDumps`, `:Report`)
- `clean_logs.bat` uses a single cleanup loop for both report/no-report modes (the report is written to `NUL` when skipped)
- A warning is printed when the Desktop can't be resolved and the script folder is used instead
- The console color is restored when the scripts finish
- Removed the unnecessary `-ExecutionPolicy Bypass` from the PowerShell call
- The "save a report" prompt no longer says "Desktop", since the output folder may fall back to the script folder
- `extract_logs.bat` warns that large dumps can take a while and that the output may contain personal data
- README: fixed the stale `:ResolveOutputDir` reference, replaced the deprecated `wmic` suggestion, documented the mandatory Administrator requirement and added a privacy note

## [2.2.0] — 2026-08-17

### Changed
- Merged the timestamp and Desktop-path resolution into a single PowerShell call (`:InitContext`), replacing the two separate `:BuildTimestamp` and `:ResolveOutputDir` calls — halves PowerShell startup overhead on each run

## [2.1.0] — 2026-08-17

### Fixed
- Restored `if errorlevel` checks in `extract_logs.bat`, replacing the less reliable `&&`/`||` pattern, across all 8 extraction steps
- Fixed a double-backslash edge case in the Desktop path fallback (`extract_logs.bat` and `clean_logs.bat`)
- Fixed broken internal README links caused by invisible variation-selector characters in emoji headings

## [2.0.0] — 2026-07-16

### Added
- Tunable `MAX_EVENTS` and `DRIVERQUERY_VERBOSE` settings in `extract_logs.bat`
- Optional cleanup report in `clean_logs.bat`, asked at runtime instead of always saved

### Changed
- Kept the more reliable Desktop path resolution (`Environment.GetFolderPath` + fallback)
- Merged System/Application error+warning event queries into one query per channel (4 → 2 `wevtutil` calls)
- Streamlined README, removed redundant sections

### Fixed
- Fixed a cleanup loop performance regression introduced by the optional report check

## [1.0.0] — 2026-04-15

### Added
- Initial release: `extract_logs.bat` and `clean_logs.bat`
- Desktop path resolution via `Environment.GetFolderPath` with fallback to the script's own folder
