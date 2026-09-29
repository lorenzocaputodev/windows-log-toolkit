@echo off
setlocal EnableExtensions

title Windows Event Logs Cleanup
color 1F

REM =========================================================
REM Windows Event Logs Cleanup
REM ---------------------------------------------------------
REM - Run as Administrator (checked at startup)
REM - This script CLEARS Windows Event Viewer logs
REM - An optional report is saved on the Desktop
REM =========================================================

call :RequireAdmin || exit /b 1
call :InitContext

set "REPORT=%OUTDIR%clean_logs_report_%STAMP%.txt"
set /a OKCOUNT=0
set /a FAILCOUNT=0

echo =========================================================
echo   WINDOWS EVENT LOGS CLEANUP
echo =========================================================
echo.
echo WARNING: This script clears Windows Event Viewer logs.
echo It is strongly recommended to extract and save logs first.
echo.
choice /C YN /N /M "Do you want to continue? [Y/N]: "
if errorlevel 2 (
    echo.
    echo Operation cancelled by user.
    echo.
    pause
    color
    exit /b 0
)

echo.
choice /C YN /N /M "Save a report file? [Y/N]: "
if errorlevel 2 (
    REM Writing the report to NUL keeps a single cleanup loop for both cases
    set "REPORT=NUL"
    set "REPORT_INFO=not created (skipped by user choice)"
) else (
    set "REPORT_INFO=%REPORT%"
)

>"%REPORT%" echo Windows Event Logs Cleanup Report
>>"%REPORT%" echo Generated: %DATE% %TIME%
>>"%REPORT%" echo Computer: %COMPUTERNAME%
>>"%REPORT%" echo User: %USERNAME%
>>"%REPORT%" echo Output directory: %OUTDIR%
>>"%REPORT%" echo.

echo.
echo Starting cleanup of all Windows Event Viewer logs...
echo Report: %REPORT_INFO%
echo.

for /F "delims=" %%a in ('wevtutil el') do (
    echo Cleaning log: "%%a"
    wevtutil cl "%%a" >nul 2>&1
    if errorlevel 1 (
        echo   [FAILED]
        set /a FAILCOUNT+=1
        >>"%REPORT%" echo [FAILED] %%a
    ) else (
        echo   [OK]
        set /a OKCOUNT+=1
        >>"%REPORT%" echo [OK] %%a
    )
)

>>"%REPORT%" echo.
>>"%REPORT%" echo Summary
>>"%REPORT%" echo -------
>>"%REPORT%" echo Logs cleaned successfully: %OKCOUNT%
>>"%REPORT%" echo Logs not cleaned: %FAILCOUNT%

echo.
echo =========================================================
echo                         SUMMARY
echo =========================================================
echo Cleaned successfully: %OKCOUNT%
echo Failed: %FAILCOUNT%
echo Report: %REPORT_INFO%
echo.
if %FAILCOUNT% GTR 0 (
    echo Note: Some logs may be protected, in use, or unavailable.
) else (
    echo All enumerated logs were cleared successfully.
)
echo =========================================================
echo.
pause
color
exit /b 0

REM ---------------------------------------------------------
REM Subroutines
REM ---------------------------------------------------------

:RequireAdmin
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Please run this script as Administrator.
    echo Right click the file and choose "Run as administrator".
    echo.
    pause
    color
    exit /b 1
)
exit /b 0

:InitContext
REM Sets STAMP (yyyy-MM-dd_HH-mm-ss) and OUTDIR (Desktop, or the script
REM folder as fallback, always with a trailing backslash) in one PowerShell call.
set "STAMP="
set "OUTDIR="
for /f "usebackq tokens=1,* delims=|" %%a in (`powershell -NoProfile -Command "(Get-Date -Format yyyy-MM-dd_HH-mm-ss) + '|' + [Environment]::GetFolderPath('Desktop')"`) do (
    set "STAMP=%%a"
    set "OUTDIR=%%b"
)
if not defined STAMP call :FallbackStamp
if defined OUTDIR if not exist "%OUTDIR%\" set "OUTDIR="
if not defined OUTDIR (
    set "OUTDIR=%~dp0"
    echo [WARN] Desktop folder not resolved, using the script folder instead.
    echo.
)
if not "%OUTDIR:~-1%"=="\" set "OUTDIR=%OUTDIR%\"
exit /b 0

:FallbackStamp
set "STAMP=%DATE%_%TIME%"
set "STAMP=%STAMP:/=-%"
set "STAMP=%STAMP::=-%"
set "STAMP=%STAMP: =0%"
set "STAMP=%STAMP:,=-%"
set "STAMP=%STAMP:.=-%"
exit /b 0
