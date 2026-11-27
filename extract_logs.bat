@echo off
setlocal EnableExtensions

title Windows Logs Extractor
color 1F

REM =========================================================
REM Windows Logs Extractor
REM ---------------------------------------------------------
REM - Needs Administrator rights (asks for them if missing)
REM - Creates a timestamped folder on the Desktop
REM - Collects useful diagnostics before cleanup/troubleshooting
REM =========================================================

call :RequireAdmin "%~f0" %1 || exit /b 1
call :InitContext

REM ---------------------------------------------------------
REM Tunable settings (safe to adjust)
REM ---------------------------------------------------------
REM Hours of history in the readable .txt extracts and WER reports
set "HOURS=24"
REM Max entries pulled per event query (lower = faster, less detail)
set "MAX_EVENTS=300"
REM Set to 1 for full driverquery /v (slower, more detail)
REM Set to 0 for fast driverquery (no /v, quicker, less detail)
set "DRIVERQUERY_VERBOSE=0"
REM Full memory dump (MEMORY.DMP, can be several GB): ask, yes or no
set "FULL_DUMP=ask"

call :CheckHours

set "BASE_DIR=%OUTDIR%windows_logs_%STAMP%"
set "RAW_DIR=%BASE_DIR%\Raw_EVTX"
set "DUMP_DIR=%BASE_DIR%\Dumps"
set "REPORT=%BASE_DIR%\collection_report.txt"
set /a STEP=0
set /a STEPS=11
set /a FAILCOUNT=0

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
>>"%REPORT%" echo Time window for .txt extracts and WER reports: last %HOURS% hours
>>"%REPORT%" echo.

echo =========================================================
echo   WINDOWS LOGS EXTRACTOR
echo =========================================================
echo.
echo Output folder:
echo %BASE_DIR%
echo.

call :PlanFullDump

call :Step "Extracting errors + warnings, last %HOURS% hours..."
call :EventText System
call :EventText Application
call :EventText Setup

call :Step "Exporting raw logs (.evtx)..."
call :ExportEvtx System
call :ExportEvtx Application
call :ExportEvtx Setup

call :Step "Copying crash dumps..."
call :CopyDumps

call :Step "Copying Live Kernel Reports (hangs and driver resets without a blue screen)..."
call :CopyTree "%SystemRoot%\LiveKernelReports" "%BASE_DIR%\LiveKernelReports" "*.dmp" "LiveKernelReports"

call :Step "Copying Windows Error Reporting reports, last %DAYS% day(s)..."
call :CopyTree "%ProgramData%\Microsoft\Windows\WER" "%BASE_DIR%\WER" "Report.wer" "WER" /MAXAGE:%DAYS%

call :Step "Saving systeminfo..."
systeminfo > "%BASE_DIR%\systeminfo.txt" 2>nul
call :Report %errorlevel% "systeminfo.txt"

call :Step "Saving driver list..."
if "%DRIVERQUERY_VERBOSE%"=="1" (
    driverquery /v > "%BASE_DIR%\driverquery.txt" 2>nul
) else (
    driverquery > "%BASE_DIR%\driverquery.txt" 2>nul
)
call :Report %errorlevel% "driverquery.txt"

call :Step "Saving running tasks..."
tasklist /v > "%BASE_DIR%\tasklist.txt" 2>nul
call :Report %errorlevel% "tasklist.txt"

call :Step "Saving network configuration..."
ipconfig /all > "%BASE_DIR%\ipconfig.txt" 2>nul
call :Report %errorlevel% "ipconfig.txt"

call :Step "Saving installed updates..."
powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Format-Table -AutoSize HotFixID,Description,InstalledOn,InstalledBy | Out-String -Width 300" > "%BASE_DIR%\installed_updates.txt" 2>nul
call :Report %errorlevel% "installed_updates.txt"

call :Step "Saving disk health..."
powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table -AutoSize FriendlyName,MediaType,BusType,HealthStatus,OperationalStatus,@{n='SizeGB';e={[math]::Round($_.Size/1GB)}} | Out-String -Width 300; Get-PhysicalDisk | ForEach-Object { $r = $_ | Get-StorageReliabilityCounter; [pscustomobject]@{Disk=$_.FriendlyName; TemperatureC=$r.Temperature; WearPercent=$r.Wear; ReadErrors=$r.ReadErrorsTotal; WriteErrors=$r.WriteErrorsTotal; PowerOnHours=$r.PowerOnHours} } | Format-Table -AutoSize | Out-String -Width 300" > "%BASE_DIR%\disk_health.txt" 2>nul
call :Report %errorlevel% "disk_health.txt"

echo.
echo =========================================================
echo                         DONE
echo =========================================================
echo Files saved to:
echo %BASE_DIR%
echo Report:
echo %REPORT%
echo.
if %FAILCOUNT% GTR 0 echo %FAILCOUNT% item(s) failed: see the report for details.
echo Note: dumps, .evtx files and WER reports may contain personal data.
echo Review them before sharing.
echo =========================================================
echo.
pause
color
exit /b 0

REM ---------------------------------------------------------
REM Subroutines
REM ---------------------------------------------------------

:Step
REM %1 = message shown for this step
set /a STEP+=1
echo.
echo [%STEP%/%STEPS%] %~1
exit /b 0

:EventText
REM %1 = channel name (System / Application / Setup)
wevtutil qe %1 /c:%MAX_EVENTS% /rd:true /f:text /q:"*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) <= %WINDOW_MS%]]]" > "%BASE_DIR%\%1_Errors_Warnings.txt" 2>nul
call :Report %errorlevel% "%1_Errors_Warnings.txt"
exit /b 0

:ExportEvtx
REM %1 = channel name (System / Application / Setup)
wevtutil epl %1 "%RAW_DIR%\%1.evtx" >nul 2>&1
call :Report %errorlevel% "Raw_EVTX\%1.evtx"
exit /b 0

:PlanFullDump
REM Decides before the long steps whether MEMORY.DMP gets copied:
REM sets COPY_FULL=1, or SKIP_FULL to the reason it is skipped.
set "COPY_FULL="
set "SKIP_FULL="
if not exist "%SystemRoot%\MEMORY.DMP" exit /b 0
set "DUMP_MB="
set "FREE_MB="
for /f "usebackq tokens=1,2" %%a in (`powershell -NoProfile -Command "$s = [math]::Ceiling((Get-Item -LiteralPath (Join-Path $env:SystemRoot 'MEMORY.DMP')).Length / 1MB); try { $f = [math]::Floor([IO.DriveInfo]::new([IO.Path]::GetPathRoot($env:DUMP_DIR)).AvailableFreeSpace / 1MB) } catch { $f = -1 }; [string]$s + ' ' + $f"`) do (
    set "DUMP_MB=%%a"
    set "FREE_MB=%%b"
)
if not defined DUMP_MB set "DUMP_MB=?"
if not defined FREE_MB set "FREE_MB=-1"
echo Found a full memory dump: %SystemRoot%\MEMORY.DMP, %DUMP_MB% MB
if /i "%FULL_DUMP%"=="no" (
    set "SKIP_FULL=disabled by the FULL_DUMP setting"
    goto :PlanFullDumpEnd
)
if "%DUMP_MB%"=="?" goto :PlanFullDumpChoice
if %FREE_MB% LSS 0 goto :PlanFullDumpChoice
set /a NEEDED_MB=DUMP_MB+1024
if %FREE_MB% GEQ %NEEDED_MB% goto :PlanFullDumpChoice
set "SKIP_FULL=not enough free space, %FREE_MB% MB available"
goto :PlanFullDumpEnd
:PlanFullDumpChoice
if /i "%FULL_DUMP%"=="yes" (
    set "COPY_FULL=1"
    goto :PlanFullDumpEnd
)
choice /C YN /N /M "Copy it too? It can take a while. [Y/N]: "
if errorlevel 2 (
    set "SKIP_FULL=skipped by user choice"
) else (
    set "COPY_FULL=1"
)
:PlanFullDumpEnd
if defined SKIP_FULL echo MEMORY.DMP will not be copied: %SKIP_FULL%
exit /b 0

:CopyDumps
set "FOUND_DUMP="
if exist "%SystemRoot%\Minidump\*.dmp" call :CopyDump "%SystemRoot%\Minidump\*.dmp" "Dumps\*.dmp"
if defined COPY_FULL call :CopyDump "%SystemRoot%\MEMORY.DMP" "Dumps\MEMORY.DMP"
if defined SKIP_FULL (
    echo   [SKIPPED] Dumps\MEMORY.DMP
    >>"%REPORT%" echo [SKIPPED] Dumps\MEMORY.DMP: %SKIP_FULL%
    set "FOUND_DUMP=1"
)
if not defined FOUND_DUMP (
    echo   [INFO] No dump files found
    >>"%REPORT%" echo [INFO] No dump files found
)
exit /b 0

:CopyDump
REM %1 = source path, %2 = label used in the report
echo   Copying %~2 (may take a while for large dumps)...
copy "%~1" "%DUMP_DIR%\" >nul 2>&1
call :Report %errorlevel% "%~2"
set "FOUND_DUMP=1"
exit /b 0

:CopyTree
REM %1 = source folder, %2 = destination folder, %3 = file mask,
REM %4 = label used in the report, %5 = extra robocopy option (optional)
if not exist "%~1\" (
    echo   [INFO] %~4: folder not found
    >>"%REPORT%" echo [INFO] %~4: folder not found
    exit /b 0
)
robocopy "%~1" "%~2" "%~3" /S /R:0 /W:0 /NP /NJH /NJS /NFL /NDL %5 >nul 2>&1
if errorlevel 8 (
    call :Report 1 "%~4"
    exit /b 0
)
if errorlevel 1 (
    call :Report 0 "%~4"
    exit /b 0
)
rd "%~2" 2>nul
echo   [INFO] %~4: nothing to copy
>>"%REPORT%" echo [INFO] %~4: nothing to copy
exit /b 0

:Report
REM %1 = errorlevel of the previous step, %2 = label used in the report
if "%~1"=="0" (
    echo   [OK] %~2
    >>"%REPORT%" echo [OK] %~2
) else (
    echo   [FAILED] %~2
    >>"%REPORT%" echo [FAILED] %~2
    set /a FAILCOUNT+=1
)
exit /b 0

:CheckHours
REM Falls back to 24 when HOURS is not a positive whole number, then sets
REM WINDOW_MS (HOURS in milliseconds, built as text to avoid 32-bit overflow)
REM and DAYS (HOURS rounded up to whole days, for robocopy /MAXAGE).
echo %HOURS%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo [WARN] HOURS="%HOURS%" is not a positive whole number, using 24.
    echo.
    set "HOURS=24"
)
set /a HOURS_X36=HOURS*36
set "WINDOW_MS=%HOURS_X36%00000"
set /a DAYS=(HOURS+23)/24
exit /b 0

:RequireAdmin
REM %1 = this script's full path, %2 = "elevated" when relaunched by this routine
fltmc >nul 2>&1
if not errorlevel 1 exit /b 0
if /i "%~2"=="elevated" goto :AdminFailed
echo Requesting Administrator rights, the script continues in a new window...
set "SELF=%~1"
powershell -NoProfile -Command "Start-Process -FilePath '%SELF:'=''%' -ArgumentList 'elevated' -Verb RunAs" >nul 2>&1
if errorlevel 1 goto :AdminFailed
color
exit /b 1
:AdminFailed
echo.
echo [ERROR] Administrator rights are required and were not granted.
echo Right-click the file and choose "Run as administrator".
echo.
pause
color
exit /b 1

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
