# Changelog

All notable changes to this project are documented here.

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
