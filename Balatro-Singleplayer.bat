@echo off
setlocal EnableExtensions
title Balatro Single-player
set "ROOT=%~dp0"
set "SCRIPTS=%ROOT%scripts"
set "GAMEDIR="
if exist "C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
if not defined GAMEDIR if exist "C:\Program Files\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files\Steam\steamapps\common\Balatro"
if not defined GAMEDIR (
    echo Could not find Balatro. Use "Balatro Mode.bat" instead.
    pause
    exit /b 1
)
if exist "%GAMEDIR%\version.dll.disabled" (
    if exist "%GAMEDIR%\version.dll" del /f /q "%GAMEDIR%\version.dll" 2>nul
    echo Single-player already set.
    goto PROFILE
)
if exist "%GAMEDIR%\version.dll" (
    ren "%GAMEDIR%\version.dll" "version.dll.disabled"
    if errorlevel 1 (
        echo Failed to disable mods. Close Balatro or Run as administrator.
        pause
        exit /b 1
    )
    echo Single-player ^(vanilla^) enabled.
    goto PROFILE
)
echo Already vanilla ^(no version.dll^).
:PROFILE
echo Setting profile slot 1...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\Set-BalatroProfile.ps1" -Profile 1
if errorlevel 1 echo WARNING: could not set profile - launching anyway.
:LAUNCH
start "" "steam://rungameid/2379780"
endlocal
