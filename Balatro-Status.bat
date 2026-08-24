@echo off
setlocal EnableExtensions
title Balatro status
set "GAMEDIR="
if exist "C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
if not defined GAMEDIR if exist "C:\Program Files\Steam\steamapps\common\Balatro\Balatro.exe" set "GAMEDIR=C:\Program Files\Steam\steamapps\common\Balatro"
echo.
echo  Game: %GAMEDIR%
if exist "%GAMEDIR%\version.dll" (
    echo  Mode: MULTIPLAYER / modded  ^(version.dll active^)
) else if exist "%GAMEDIR%\version.dll.disabled" (
    echo  Mode: SINGLE-PLAYER / vanilla  ^(version.dll.disabled^)
) else (
    echo  Mode: unknown / vanilla  ^(no Lovely file^)
)
echo  Mods: %APPDATA%\Balatro\Mods
echo.
pause
endlocal
