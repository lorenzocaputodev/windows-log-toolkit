@echo off
setlocal EnableExtensions

title Windows Logs Extractor
color 1F

REM =========================================================
REM Windows Logs Extractor
REM ---------------------------------------------------------
REM - Run as Administrator for best results
REM - Creates a timestamped folder on the Desktop
REM - Collects useful diagnostics before cleanup/troubleshooting
REM =========================================================

call :RequireAdmin
call :BuildTimestamp
call :ResolveOutputDir

REM ---------------------------------------------------------
REM Tunable settings (safe to adjust)
REM ---------------------------------------------------------
REM Max entries pulled per event query (lower = faster, less detail)
set "MAX_EVENTS=300"
REM Set to 1 for full driverquery /v (slower, more detail)
REM Set to 0 for fast driverquery (no /v, quicker, less detail)
set "DRIVERQUERY_VERBOSE=0"

set "BASE_DIR=%OUTDIR%\windows_logs_%STAMP%"
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
wevtutil qe System /c:%MAX_EVENTS% /rd:true /f:text /q:"*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) <= 86400000]]]" > "%BASE_DIR%\System_Errors_Warnings.txt" 2>nul && (
    echo   [OK]
    >>"%REPORT%" echo [OK] System_Errors_Warnings.txt
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] System_Errors_Warnings.txt
)
echo.

echo [2/8] Extracting APPLICATION errors + warnings (last 24h)...
wevtutil qe Application /c:%MAX_EVENTS% /rd:true /f:text /q:"*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) <= 86400000]]]" > "%BASE_DIR%\Application_Errors_Warnings.txt" 2>nul && (
    echo   [OK]
    >>"%REPORT%" echo [OK] Application_Errors_Warnings.txt
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] Application_Errors_Warnings.txt
)
echo.

echo [3/8] Exporting raw System log (.evtx)...
wevtutil epl System "%RAW_DIR%\System.evtx" >nul 2>&1 && (
    echo   [OK]
    >>"%REPORT%" echo [OK] Raw_EVTX\System.evtx
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] Raw_EVTX\System.evtx
)
echo.

echo [4/8] Exporting raw Application log (.evtx)...
wevtutil epl Application "%RAW_DIR%\Application.evtx" >nul 2>&1 && (
    echo   [OK]
    >>"%REPORT%" echo [OK] Raw_EVTX\Application.evtx
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] Raw_EVTX\Application.evtx
)
echo.

call :CopyDumps

echo [6/8] Saving systeminfo...
systeminfo > "%BASE_DIR%\systeminfo.txt" 2>nul && (
    echo   [OK]
    >>"%REPORT%" echo [OK] systeminfo.txt
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] systeminfo.txt
)
echo.

echo [7/8] Saving driver list...
if "%DRIVERQUERY_VERBOSE%"=="1" (
    driverquery /v > "%BASE_DIR%\driverquery.txt" 2>nul
) else (
    driverquery > "%BASE_DIR%\driverquery.txt" 2>nul
)
if not errorlevel 1 (
    echo   [OK]
    >>"%REPORT%" echo [OK] driverquery.txt
) else (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] driverquery.txt
)
echo.

echo [8/8] Saving running tasks...
tasklist /v > "%BASE_DIR%\tasklist.txt" 2>nul && (
    echo   [OK]
    >>"%REPORT%" echo [OK] tasklist.txt
) || (
    echo   [FAILED]
    >>"%REPORT%" echo [FAILED] tasklist.txt
)
echo.

echo =========================================================
echo                         DONE
echo =========================================================
echo Files saved to:
echo %BASE_DIR%
echo Report:
echo %REPORT%
echo =========================================================
echo.
pause
exit /b 0

:CopyDumps
echo [5/8] Copying crash dumps...
set "FOUND_DUMP=0"

if exist "C:\Windows\Minidump\*.dmp" (
    copy "C:\Windows\Minidump\*.dmp" "%DUMP_DIR%\" >nul 2>&1
    echo   [OK] Minidumps copied
    >>"%REPORT%" echo [OK] Dumps\Minidump\*.dmp
    set "FOUND_DUMP=1"
)

if exist "C:\Windows\MEMORY.DMP" (
    copy "C:\Windows\MEMORY.DMP" "%DUMP_DIR%\" >nul 2>&1
    echo   [OK] MEMORY.DMP copied
    >>"%REPORT%" echo [OK] Dumps\MEMORY.DMP
    set "FOUND_DUMP=1"
)

if "%FOUND_DUMP%"=="0" (
    echo   [INFO] No dump files found
    >>"%REPORT%" echo [INFO] No dump files found
)
echo.
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
