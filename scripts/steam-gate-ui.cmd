@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Steam-visible console entry: config-driven mode menu, then launch.

set "LOGDIR=%LOCALAPPDATA%\BalatroMode"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LOG=%LOGDIR%\steam-gate.log"
set "ENGINE=%LOGDIR%\Invoke-BalatroMode.ps1"
if not exist "%ENGINE%" set "ENGINE=%~dp0Invoke-BalatroMode.ps1"
if not exist "%ENGINE%" set "ENGINE=%~dp0..\scripts\Invoke-BalatroMode.ps1"

>>"%LOG%" echo --------
>>"%LOG%" echo [%DATE% %TIME%] UI START (config engine)
>>"%LOG%" echo [%DATE% %TIME%] ARGS=%*
>>"%LOG%" echo [%DATE% %TIME%] ENGINE=%ENGINE%

if not exist "%ENGINE%" (
    echo ERROR: Invoke-BalatroMode.ps1 not found.
    echo Run Setup-Steam-Launch-Menu.bat from the repo.
    >>"%LOG%" echo [%DATE% %TIME%] ERROR missing engine
    pause
    exit /b 1
)

rem Pass Steam's Balatro.exe path when present so we launch the same binary.
set "STEAMEXE="
if /i "%~nx1"=="Balatro.exe" set "STEAMEXE=%~1"

title Balatro - choose mode
color 0B

if defined STEAMEXE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Menu -Launch -SteamExeArgs "%STEAMEXE%" -LogPath "%LOG%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Menu -Launch -LogPath "%LOG%"
)
set "RC=%ERRORLEVEL%"
>>"%LOG%" echo [%DATE% %TIME%] engine exit rc=%RC%
if %RC% neq 0 (
    echo.
    echo Something went wrong. See log:
    echo   %LOG%
    pause
)
exit /b %RC%
