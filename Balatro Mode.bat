@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Balatro Mode Switcher
color 0B

rem ============================================================
rem  Double-click menu: vanilla single-player vs modded multiplayer
rem  Toggles Lovely injector (version.dll) next to Balatro.exe
rem ============================================================

call :DetectGameDir
if not defined GAMEDIR (
    echo.
    echo  ERROR: Could not find Balatro.exe
    echo  Edit GAMEDIR_OVERRIDE at the top of this script if needed.
    echo.
    pause
    exit /b 1
)

:MENU
cls
echo.
echo  ========================================
echo   BALATRO MODE SWITCHER
echo  ========================================
echo.
echo  Game folder:
echo    %GAMEDIR%
echo.
call :GetStatus
echo  Current mode:  !STATUS!
echo  Lovely DLL:    !LOVELY!
echo  SMODS:         !SMODS!
echo  Multiplayer:   !MPMOD!
echo.
echo  ----------------------------------------
echo   [1]  Single-player  (vanilla + profile 1)
echo   [2]  Multiplayer    (modded + profile 2)
echo   [3]  Single-player + launch via Steam
echo   [4]  Multiplayer   + launch via Steam
echo   [5]  Refresh status
echo   [0]  Exit
echo  ----------------------------------------
echo.
set "CHOICE="
set /p "CHOICE=  Choose [0-5]: "

if "%CHOICE%"=="1" goto DO_SP
if "%CHOICE%"=="2" goto DO_MP
if "%CHOICE%"=="3" goto DO_SP_LAUNCH
if "%CHOICE%"=="4" goto DO_MP_LAUNCH
if "%CHOICE%"=="5" goto MENU
if "%CHOICE%"=="0" exit /b 0
if /i "%CHOICE%"=="q" exit /b 0
echo.
echo  Invalid choice.
timeout /t 1 >nul
goto MENU

:DO_SP
call :EnableSingleplayer
call :SetProfile 1
echo.
pause
goto MENU

:DO_MP
call :EnableMultiplayer
call :SetProfile 2
echo.
pause
goto MENU

:DO_SP_LAUNCH
call :EnableSingleplayer
if errorlevel 1 (
    echo.
    pause
    goto MENU
)
call :SetProfile 1
call :LaunchSteam
exit /b 0

:DO_MP_LAUNCH
call :EnableMultiplayer
if errorlevel 1 (
    echo.
    pause
    goto MENU
)
call :SetProfile 2
call :LaunchSteam
exit /b 0

rem ------------------------------------------------------------
:DetectGameDir
rem Optional hard override (uncomment and set if auto-detect fails):
rem set "GAMEDIR_OVERRIDE=C:\Program Files (x86)\Steam\steamapps\common\Balatro"

set "GAMEDIR="
if defined GAMEDIR_OVERRIDE (
    if exist "%GAMEDIR_OVERRIDE%\Balatro.exe" (
        set "GAMEDIR=%GAMEDIR_OVERRIDE%"
        exit /b 0
    )
)

rem Multiplayer Launcher settings.json gameDirectory
set "MPSETTINGS=%APPDATA%\Balatro Multiplayer Launcher\settings.json"
if exist "%MPSETTINGS%" (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "try { (Get-Content -LiteralPath $env:MPSETTINGS -Raw | ConvertFrom-Json).gameDirectory } catch { }" 2^>nul`) do (
        if exist "%%A\Balatro.exe" set "GAMEDIR=%%A"
    )
)
if defined GAMEDIR exit /b 0

rem Common Steam install
if exist "C:\Program Files (x86)\Steam\steamapps\common\Balatro\Balatro.exe" (
    set "GAMEDIR=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
    exit /b 0
)
if exist "C:\Program Files\Steam\steamapps\common\Balatro\Balatro.exe" (
    set "GAMEDIR=C:\Program Files\Steam\steamapps\common\Balatro"
    exit /b 0
)
if exist "C:\Program Files (x86)\Steam\steamapps\common\Balatro Modded\Balatro.exe" (
    set "GAMEDIR=C:\Program Files (x86)\Steam\steamapps\common\Balatro Modded"
    exit /b 0
)
exit /b 1

rem ------------------------------------------------------------
:GetStatus
set "STATUS=unknown"
set "LOVELY=not found"
set "SMODS=missing"
set "MPMOD=missing"

if exist "%GAMEDIR%\version.dll" (
    set "STATUS=MULTIPLAYER (modded)"
    set "LOVELY=ACTIVE (version.dll)"
) else if exist "%GAMEDIR%\version.dll.disabled" (
    set "STATUS=SINGLE-PLAYER (vanilla)"
    set "LOVELY=disabled (version.dll.disabled)"
)

set "MODSDIR=%APPDATA%\Balatro\Mods"
if exist "%MODSDIR%\smods\" set "SMODS=found"
if exist "%MODSDIR%\smods" set "SMODS=found"

rem multiplayer folder may be multiplayer-0.5.4 etc.
set "MPMOD=missing"
for /d %%D in ("%MODSDIR%\multiplayer*") do set "MPMOD=found"
exit /b 0

rem ------------------------------------------------------------
:EnableSingleplayer
echo.
echo  Switching to SINGLE-PLAYER (vanilla)...
if exist "%GAMEDIR%\version.dll.disabled" (
    if exist "%GAMEDIR%\version.dll" (
        del /f /q "%GAMEDIR%\version.dll" 2>nul
        if exist "%GAMEDIR%\version.dll" (
            echo  ERROR: Could not remove active version.dll - is Balatro running?
            echo  Close the game and try again. Run as Administrator if needed.
            exit /b 1
        )
        echo  OK - already had disabled copy; removed active injector.
        exit /b 0
    )
    echo  OK - already in single-player mode.
    exit /b 0
)
if exist "%GAMEDIR%\version.dll" (
    ren "%GAMEDIR%\version.dll" "version.dll.disabled"
    if errorlevel 1 (
        echo  ERROR: Could not rename version.dll
        echo  Close Balatro first. If it still fails, right-click this .bat
        echo  and choose "Run as administrator".
        exit /b 1
    )
    echo  OK - Lovely disabled (version.dll -^> version.dll.disabled)
    echo  Mods stay in %%AppData%%\Balatro\Mods but will not load.
    exit /b 0
)
echo  WARNING: No version.dll found - game is already vanilla
echo  (or Lovely was never installed).
exit /b 0

rem ------------------------------------------------------------
:EnableMultiplayer
echo.
echo  Switching to MULTIPLAYER (modded)...
if exist "%GAMEDIR%\version.dll" (
    echo  OK - Lovely already active.
    call :WarnMods
    exit /b 0
)
if exist "%GAMEDIR%\version.dll.disabled" (
    ren "%GAMEDIR%\version.dll.disabled" "version.dll"
    if errorlevel 1 (
        echo  ERROR: Could not rename version.dll.disabled
        echo  Close Balatro first. If it still fails, right-click this .bat
        echo  and choose "Run as administrator".
        exit /b 1
    )
    echo  OK - Lovely enabled (version.dll.disabled -^> version.dll)
    call :WarnMods
    exit /b 0
)
echo  ERROR: Neither version.dll nor version.dll.disabled found in:
echo    %GAMEDIR%
echo  Reinstall Lovely / open Balatro Multiplayer Launcher, then try again.
exit /b 1

rem ------------------------------------------------------------
:WarnMods
set "MODSDIR=%APPDATA%\Balatro\Mods"
if not exist "%MODSDIR%\smods\" if not exist "%MODSDIR%\smods" (
    echo  WARNING: SMODS not found under %MODSDIR%
)
set "FOUNDMP=0"
for /d %%D in ("%MODSDIR%\multiplayer*") do set "FOUNDMP=1"
if "!FOUNDMP!"=="0" (
    echo  WARNING: Multiplayer mod not found under %MODSDIR%
)
exit /b 0

rem ------------------------------------------------------------
:LaunchSteam
echo.
echo  Launching Balatro via Steam...
start "" "steam://rungameid/2379780"
exit /b 0

:SetProfile
set "SLOT=%~1"
echo  Setting Balatro profile slot to %SLOT%...
if exist "%~dp0scripts\Set-BalatroProfile.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Set-BalatroProfile.ps1" -Profile %SLOT%
) else if exist "%LOCALAPPDATA%\BalatroMode\Set-BalatroProfile.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\BalatroMode\Set-BalatroProfile.ps1" -Profile %SLOT%
) else (
    echo  WARNING: Set-BalatroProfile.ps1 not found.
    exit /b 1
)
exit /b %ERRORLEVEL%
