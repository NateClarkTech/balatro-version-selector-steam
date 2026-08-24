@echo off
setlocal EnableExtensions
title Edit Balatro modes config
set "LOCAL=%LOCALAPPDATA%\BalatroMode\modes.json"
set "REPO=%~dp0config\modes.json"
set "EXAMPLE=%~dp0config\modes.example.json"

if exist "%LOCAL%" (
    echo Opening installed config:
    echo   %LOCAL%
    notepad "%LOCAL%"
    exit /b 0
)

if not exist "%REPO%" if exist "%EXAMPLE%" (
    copy /Y "%EXAMPLE%" "%REPO%" >nul
)

if exist "%REPO%" (
    echo No LocalAppData config yet. Opening repo config:
    echo   %REPO%
    echo.
    echo Tip: run Setup-Steam-Launch-Menu.bat to install a copy under
    echo %%LocalAppData%%\BalatroMode\modes.json ^(edited there for Steam Play^).
    notepad "%REPO%"
    exit /b 0
)

echo ERROR: No modes.json found.
pause
exit /b 1
