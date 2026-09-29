@echo off
setlocal EnableExtensions

title Windows Logs Extractor
color 1F

REM =========================================================
REM Windows Logs Extractor
REM ---------------------------------------------------------
REM - Run as Administrator (checked at startup)
REM - Creates a timestamped folder on the Desktop
REM - Collects useful diagnostics before cleanup/troubleshooting
REM =========================================================

call :RequireAdmin || exit /b 1
call :InitContext

REM ---------------------------------------------------------
REM Tunable settings (safe to adjust)
REM ---------------------------------------------------------
REM Max entries pulled per event query (lower = faster, less detail)
set "MAX_EVENTS=300"
REM Set to 1 for full driverquery /v (slower, more detail)
REM Set to 0 for fast driverquery (no /v, quicker, less detail)
set "DRIVERQUERY_VERBOSE=0"

set "BASE_DIR=%OUTDIR%windows_logs_%STAMP%"
set "RAW_DIR=%BASE_DIR%\Raw_EVTX"
set "DUMP_DIR=%BASE_DIR%\Dumps"
set "REPORT=%BASE_DIR%\collection_report.txt"

mkdir "%BASE_DIR%" 2>nul
if not exist "%BASE_DIR%" (
    echo.
    echo [ERROR] Failed to create output folder:
    echo %BASE_DIR%
    echo.
    pause
    color
    exit /b 1
)

mkdir "%RAW_DIR%" 2>nul
mkdir "%DUMP_DIR%" 2>nul

>"%REPORT%" echo Windows Logs Extraction Report
>>"%REPORT%" echo Generated: %DATE% %TIME%
>>"%REPORT%" echo Computer: %COMPUTERNAME%
>>"%REPORT%" echo User: %USERNAME%
>>"%REPORT%" echo Output folder: %BASE_DIR%
>>"%REPORT%" echo.

echo =========================================================
echo   WINDOWS LOGS EXTRACTOR
echo =========================================================
echo.
echo Output folder:
echo %BASE_DIR%
echo.

echo [1/8] Extracting SYSTEM errors + warnings (last 24h)...
call :EventText System
echo.

echo [2/8] Extracting APPLICATION errors + warnings (last 24h)...
call :EventText Application
echo.

echo [3/8] Exporting raw System log (.evtx)...
call :ExportEvtx System
echo.

echo [4/8] Exporting raw Application log (.evtx)...
call :ExportEvtx Application
echo.

echo [5/8] Copying crash dumps...
call :CopyDumps
echo.

echo [6/8] Saving systeminfo...
systeminfo > "%BASE_DIR%\systeminfo.txt" 2>nul
call :Report %errorlevel% "systeminfo.txt"
echo.

echo [7/8] Saving driver list...
if "%DRIVERQUERY_VERBOSE%"=="1" (
    driverquery /v > "%BASE_DIR%\driverquery.txt" 2>nul
) else (
    driverquery > "%BASE_DIR%\driverquery.txt" 2>nul
)
call :Report %errorlevel% "driverquery.txt"
echo.

echo [8/8] Saving running tasks...
tasklist /v > "%BASE_DIR%\tasklist.txt" 2>nul
call :Report %errorlevel% "tasklist.txt"
echo.

echo =========================================================
echo                         DONE
echo =========================================================
echo Files saved to:
echo %BASE_DIR%
echo Report:
echo %REPORT%
echo.
echo Note: dumps and .evtx files may contain personal data.
echo Review them before sharing.
echo =========================================================
echo.
pause
color
exit /b 0

REM ---------------------------------------------------------
REM Subroutines
REM ---------------------------------------------------------

:EventText
REM %1 = channel name (System / Application)
wevtutil qe %1 /c:%MAX_EVENTS% /rd:true /f:text /q:"*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) <= 86400000]]]" > "%BASE_DIR%\%1_Errors_Warnings.txt" 2>nul
call :Report %errorlevel% "%1_Errors_Warnings.txt"
exit /b 0

:ExportEvtx
REM %1 = channel name (System / Application)
wevtutil epl %1 "%RAW_DIR%\%1.evtx" >nul 2>&1
call :Report %errorlevel% "Raw_EVTX\%1.evtx"
exit /b 0

:CopyDumps
set "FOUND_DUMP="
if exist "%SystemRoot%\Minidump\*.dmp" call :CopyDump "%SystemRoot%\Minidump\*.dmp" "*.dmp"
if exist "%SystemRoot%\MEMORY.DMP" call :CopyDump "%SystemRoot%\MEMORY.DMP" "MEMORY.DMP"
if not defined FOUND_DUMP (
    echo   [INFO] No dump files found
    >>"%REPORT%" echo [INFO] No dump files found
)
exit /b 0

:CopyDump
REM %1 = source path, %2 = label used in the report
echo   Copying %~2 (may take a while for large dumps)...
copy "%~1" "%DUMP_DIR%\" >nul 2>&1
call :Report %errorlevel% "Dumps\%~2"
set "FOUND_DUMP=1"
exit /b 0

:Report
REM %1 = errorlevel of the previous step, %2 = label used in the report
if "%~1"=="0" (
    echo   [OK]
    >>"%REPORT%" echo [OK] %~2
) else (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] %~2
)
exit /b 0

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
