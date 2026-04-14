@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Windows Event Logs Cleanup
color 1F

call :RequireAdmin
call :BuildTimestamp
call :ResolveOutputDir

set "REPORT=%OUTDIR%\clean_logs_report_%STAMP%.txt"
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
    exit /b 0
)

> "%REPORT%" echo Windows Event Logs Cleanup Report
>>"%REPORT%" echo Generated: %DATE% %TIME%
>>"%REPORT%" echo Computer: %COMPUTERNAME%
>>"%REPORT%" echo User: %USERNAME%
>>"%REPORT%" echo Output directory: %OUTDIR%
>>"%REPORT%" echo.

echo.
echo Starting cleanup of all Windows Event Viewer logs...
echo A detailed report will be saved to:
echo %REPORT%
echo.

for /f "delims=" %%a in ('wevtutil el') do (
    set "LOGNAME=%%a"
    echo Cleaning log: "!LOGNAME!"
    wevtutil cl "!LOGNAME!" >nul 2>&1

    if !errorlevel! equ 0 (
        echo   [OK]
        set /a OKCOUNT+=1
        >>"%REPORT%" echo [OK] !LOGNAME!
    ) else (
        echo   [FAILED]
        set /a FAILCOUNT+=1
        >>"%REPORT%" echo [FAILED] !LOGNAME!
    )
)

>>"%REPORT%" echo.
>>"%REPORT%" echo Summary
>>"%REPORT%" echo -------
>>"%REPORT%" echo Logs cleaned successfully: !OKCOUNT!
>>"%REPORT%" echo Logs not cleaned: !FAILCOUNT!

echo.
echo =========================================================
echo                         SUMMARY
echo =========================================================
echo Cleaned successfully: !OKCOUNT!
echo Failed: !FAILCOUNT!
echo Report: %REPORT%
echo.
if !FAILCOUNT! GTR 0 (
    echo Note: Some logs may be protected, in use, or unavailable.
) else (
    echo All enumerated logs were cleared successfully.
)
echo =========================================================
echo.
pause
exit /b 0

:RequireAdmin
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] Please run this script as Administrator.
    echo Right click the file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)
exit /b 0

:BuildTimestamp
for /f %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%i"
if not defined STAMP set "STAMP=%DATE:/=-%_%TIME::=-%"
exit /b 0

:ResolveOutputDir
for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath('Desktop')"`) do set "OUTDIR=%%i"
if not defined OUTDIR set "OUTDIR=%~dp0"
if not exist "%OUTDIR%" set "OUTDIR=%~dp0"
exit /b 0