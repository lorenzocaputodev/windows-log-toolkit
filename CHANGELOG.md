# Changelog

All notable changes to this project are documented here.

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
- Kept the more reliable Desktop path resolution (`Environment.GetFolderPath` + fallback) introduced upstream
- Merged System/Application error+warning event queries into one query per channel (4 → 2 `wevtutil` calls)
- Streamlined README, removed redundant sections

### Fixed
- Fixed a cleanup loop performance regression introduced by the optional report check

## [1.0.0] — 2026-04-15

### Added
- Initial release: `extract_logs.bat` and `clean_logs.bat`
- Desktop path resolution via `Environment.GetFolderPath` with fallback to the script's own folder
