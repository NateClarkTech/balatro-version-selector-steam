@echo off
setlocal EnableExtensions
title Balatro Multiplayer
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
if exist "%GAMEDIR%\version.dll" goto PROFILE
if exist "%GAMEDIR%\version.dll.disabled" (
    ren "%GAMEDIR%\version.dll.disabled" "version.dll"
    if errorlevel 1 (
        echo Failed to enable multiplayer. Close Balatro or Run as administrator.
        pause
        exit /b 1
    )
    echo Multiplayer enabled.
    goto PROFILE
)
echo Lovely injector not found in game folder.
pause
exit /b 1
:PROFILE
echo Setting profile slot 2...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\Set-BalatroProfile.ps1" -Profile 2
if errorlevel 1 echo WARNING: could not set profile - launching anyway.
:LAUNCH
start "" "steam://rungameid/2379780"
endlocal
