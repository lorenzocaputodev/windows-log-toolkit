@echo off
setlocal EnableExtensions

title Windows Event Logs Cleanup
color 1F

REM =========================================================
REM Windows Event Logs Cleanup
REM ---------------------------------------------------------
REM - Needs Administrator rights (asks for them if missing)
REM - This script CLEARS Windows Event Viewer logs
REM - An optional report is saved on the Desktop
REM =========================================================

call :RequireAdmin "%~f0" %1 || exit /b 1
call :InitContext

set "REPORT=%OUTDIR%clean_logs_report_%STAMP%.txt"
set /a OKCOUNT=0
set /a FAILCOUNT=0
set /a PROTCOUNT=0

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
echo Looking for logs that contain events...
call :BuildLogList

set "LOGINFO=%TEMP%\clean_logs_info_%STAMP%.txt"
for /f "usebackq skip=1 delims=" %%a in ("%LOGLIST%") do call :CleanLog "%%a"
del "%LOGLIST%" "%LOGINFO%" 2>nul

call :MeasureFreed

>>"%REPORT%" echo.
>>"%REPORT%" echo Summary
>>"%REPORT%" echo -------
>>"%REPORT%" echo Logs cleaned successfully: %OKCOUNT%
>>"%REPORT%" echo Logs already empty, skipped: %SKIPCOUNT%
>>"%REPORT%" echo Logs protected by Windows, not clearable: %PROTCOUNT%
>>"%REPORT%" echo Logs not cleaned because of an error: %FAILCOUNT%
>>"%REPORT%" echo Space freed: %FREED_INFO%

echo.
echo =========================================================
echo                         SUMMARY
echo =========================================================
echo Cleaned successfully: %OKCOUNT%
echo Already empty, skipped: %SKIPCOUNT%
echo Protected by Windows: %PROTCOUNT%
echo Failed: %FAILCOUNT%
echo Space freed: %FREED_INFO%
echo Report: %REPORT_INFO%
echo.
if %PROTCOUNT% GTR 0 echo Protected logs only allow reading, even for Administrators: this is normal.
if %FAILCOUNT% GTR 0 (
    echo Note: Some logs failed: they may be in use or unavailable.
) else (
    echo Every log that Windows allows clearing was cleared.
)
echo =========================================================
echo.
pause
color
exit /b 0

REM ---------------------------------------------------------
REM Subroutines
REM ---------------------------------------------------------

:BuildLogList
REM Writes LOGLIST: a header line "*<empty logs>|<MB used by all logs>",
REM then every log that has events or whose event count can't be read.
REM Empty logs are left out: there is nothing to clear in them.
REM If PowerShell fails, every log from "wevtutil el" is listed instead.
set "LOGLIST=%TEMP%\clean_logs_list_%STAMP%.txt"
set "SKIPCOUNT=0"
set "BEFORE_MB=-1"
set "HEADER="
powershell -NoProfile -Command "$info = @{}; Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object { $info[$_.LogName] = $_ }; $skip = 0; $names = foreach ($n in (wevtutil el)) { if ($info[$n] -and $info[$n].RecordCount -eq 0) { $skip++ } else { $n } }; $mb = [math]::Round(($info.Values | Measure-Object FileSize -Sum).Sum / 1MB); '*' + $skip + '|' + $mb; $names" > "%LOGLIST%" 2>nul
set /p HEADER=<"%LOGLIST%"
if not defined HEADER set "HEADER=-"
if "%HEADER:~0,1%"=="*" goto :BuildLogListHeader
echo [WARN] Could not check which logs are empty, trying all of them.
>"%LOGLIST%" echo *0^|-1
wevtutil el >>"%LOGLIST%"
set "HEADER=*0|-1"
:BuildLogListHeader
for /f "tokens=1,2 delims=*|" %%a in ("%HEADER%") do (
    set "SKIPCOUNT=%%a"
    set "BEFORE_MB=%%b"
)
echo.
exit /b 0

:CleanLog
REM %1 = log name
echo Cleaning log: "%~1"
wevtutil cl "%~1" >nul 2>&1
if not errorlevel 1 goto :CleanLogOk
wevtutil gl "%~1" >"%LOGINFO%" 2>nul || goto :CleanLogFailed
call :IsProtectedLog
if not errorlevel 1 goto :CleanLogProtected
REM Enabled Analytic/Debug logs can only be cleared while disabled:
REM disable, clear, then enable again.
call :IsEnabledDirectLog
if errorlevel 1 goto :CleanLogFailed
wevtutil sl "%~1" /e:false /q:true >nul 2>&1
wevtutil cl "%~1" >nul 2>&1
set "CL_RESULT=%errorlevel%"
wevtutil sl "%~1" /e:true /q:true >nul 2>&1
if not errorlevel 1 goto :CleanLogRetried
echo   [WARN] Could not enable the log again
>>"%REPORT%" echo [WARN] %~1 was left disabled: could not enable it again
:CleanLogRetried
if not "%CL_RESULT%"=="0" goto :CleanLogFailed
:CleanLogOk
echo   [OK]
set /a OKCOUNT+=1
>>"%REPORT%" echo [OK] %~1
exit /b 0
:CleanLogFailed
echo   [FAILED]
set /a FAILCOUNT+=1
>>"%REPORT%" echo [FAILED] %~1
exit /b 0
:CleanLogProtected
echo   [PROTECTED] Windows does not allow clearing this log
set /a PROTCOUNT+=1
>>"%REPORT%" echo [PROTECTED] %~1
exit /b 0

:IsProtectedLog
REM Reads LOGINFO ("wevtutil gl" output). Exit code 0 when the log's
REM permissions (channelAccess) don't let the current user clear it.
REM Any error counts as "not protected", so the log is reported as failed.
powershell -NoProfile -Command "$a = (Get-Content -LiteralPath $env:LOGINFO | Where-Object { $_ -like 'channelAccess: *' }) -replace '^channelAccess: ', ''; $id = [Security.Principal.WindowsIdentity]::GetCurrent(); $mine = @($id.User.Value) + @($id.Groups | ForEach-Object { $_.Value }); $sd = [Security.AccessControl.RawSecurityDescriptor]::new([string]$a); $can = $sd.DiscretionaryAcl | Where-Object { $_.AceQualifier -eq 'AccessAllowed' -and $mine -contains $_.SecurityIdentifier.Value -and ($_.AccessMask -band 0x50000004) }; if ($can) { exit 1 } else { exit 0 }" >nul 2>&1
exit /b %errorlevel%

:IsEnabledDirectLog
REM Reads LOGINFO ("wevtutil gl" output). Exit code 0 when it is an
REM enabled Analytic or Debug log.
findstr /r /c:"^type: Analytic" /c:"^type: Debug" "%LOGINFO%" >nul || exit /b 1
findstr /r /c:"^enabled: true" "%LOGINFO%" >nul || exit /b 1
exit /b 0

:MeasureFreed
REM Sets FREED_INFO from the total log size before and after the cleanup.
set "FREED_INFO=unknown"
if "%BEFORE_MB%"=="-1" exit /b 0
set "AFTER_MB="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | Measure-Object FileSize -Sum).Sum / 1MB)"`) do set "AFTER_MB=%%a"
if not defined AFTER_MB exit /b 0
set /a FREED_MB=BEFORE_MB-AFTER_MB
if %FREED_MB% LSS 0 set /a FREED_MB=0
set "FREED_INFO=about %FREED_MB% MB"
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
echo Right click the file and choose "Run as administrator".
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
