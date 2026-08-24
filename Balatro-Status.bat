@echo off
setlocal EnableExtensions
title Balatro status
set "ENGINE=%~dp0scripts\Invoke-BalatroMode.ps1"
echo.
echo  Configured modes:
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -List
echo.
set "GAMEDIR="
if exist "C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
if not defined GAMEDIR if exist "C:\Program Files\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files\Steam\steamapps\common\Balatro"
if defined GAMEDIR (
    echo  Game: %GAMEDIR%
    if exist "%GAMEDIR%\version.dll" (
        echo  Lovely: ACTIVE
    ) else if exist "%GAMEDIR%\version.dll.disabled" (
        echo  Lovely: disabled
    ) else (
        echo  Lovely: missing
    )
)
echo  Mods: %APPDATA%\Balatro\Mods
echo.
pause
endlocal
