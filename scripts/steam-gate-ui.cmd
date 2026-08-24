@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Interactive UI - always run inside a real console window.
rem Do not call this from Steam directly; use steam-gate-launch.cmd

set "LOGDIR=%LOCALAPPDATA%\BalatroMode"
if not exist "!LOGDIR!" mkdir "!LOGDIR!"
set "LOG=!LOGDIR!\steam-gate.log"

>>"!LOG!" echo --------
>>"!LOG!" echo [%DATE% %TIME%] UI START
>>"!LOG!" echo [%DATE% %TIME%] ARGS=%*

set "EXE="
set "GAMEDIR="

if /i not "%~nx1"=="Balatro.exe" goto FIND_DIR
if not exist "%~1" goto FIND_DIR
set "EXE=%~1"
set "GAMEDIR=%~dp1"
if "!GAMEDIR:~-1!"=="\" set "GAMEDIR=!GAMEDIR:~0,-1!"
>>"!LOG!" echo [%DATE% %TIME%] EXE from Steam args
goto HAVE_DIR

:FIND_DIR
set "CAND=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
if exist "!CAND!\Balatro.exe" set "GAMEDIR=!CAND!"
if defined GAMEDIR goto HAVE_DIR
set "CAND=C:\Program Files\Steam\steamapps\common\Balatro"
if exist "!CAND!\Balatro.exe" set "GAMEDIR=!CAND!"
if defined GAMEDIR goto HAVE_DIR
>>"!LOG!" echo [%DATE% %TIME%] ERROR no game dir
echo ERROR: Could not find Balatro.
echo Log: !LOG!
pause
exit /b 1

:HAVE_DIR
if not defined EXE set "EXE=!GAMEDIR!\Balatro.exe"
>>"!LOG!" echo [%DATE% %TIME%] GAMEDIR=!GAMEDIR!
>>"!LOG!" echo [%DATE% %TIME%] EXE=!EXE!
if exist "!EXE!" goto EXE_OK
>>"!LOG!" echo [%DATE% %TIME%] ERROR missing exe
echo ERROR: Missing Balatro.exe
echo !EXE!
pause
exit /b 1

:EXE_OK
title Balatro - choose mode
color 0B
cls
echo.
echo  ========================================
echo   LAUNCH BALATRO
echo  ========================================
echo.
echo  Game: !GAMEDIR!
echo  Log:  !LOG!
echo.
set "INJECTOR=missing"
if exist "!GAMEDIR!\version.dll" set "INJECTOR=active"
if exist "!GAMEDIR!\version.dll.disabled" if "!INJECTOR!"=="missing" set "INJECTOR=disabled"
if "!INJECTOR!"=="active" echo  Last mode: MULTIPLAYER / modded
if "!INJECTOR!"=="disabled" echo  Last mode: SINGLE-PLAYER / vanilla
if "!INJECTOR!"=="missing" echo  Last mode: unknown
echo.
echo   [1] Single-player  (vanilla)
echo   [2] Multiplayer    (modded)
echo   [0] Cancel
echo.

choice /C 120 /N /M "  Press 1, 2, or 0: "
set "EC=!ERRORLEVEL!"
>>"!LOG!" echo [%DATE% %TIME%] choice errorlevel=!EC!
set "SEL=0"
if "!EC!"=="1" set "SEL=1"
if "!EC!"=="2" set "SEL=2"
if "!EC!"=="3" set "SEL=0"
>>"!LOG!" echo [%DATE% %TIME%] SEL=!SEL!

if "!SEL!"=="1" goto DO_SP
if "!SEL!"=="2" goto DO_MP
echo Cancelled.
>>"!LOG!" echo [%DATE% %TIME%] cancelled
timeout /t 2 >nul
exit /b 0

:DO_SP
echo.
echo  Enabling single-player...
>>"!LOG!" echo [%DATE% %TIME%] enable single
if not exist "!GAMEDIR!\version.dll" goto SP_DONE
if exist "!GAMEDIR!\version.dll.disabled" del /f /q "!GAMEDIR!\version.dll" 2>nul
if not exist "!GAMEDIR!\version.dll" goto SP_DONE
ren "!GAMEDIR!\version.dll" "version.dll.disabled"
if errorlevel 1 goto REN_FAIL
:SP_DONE
echo  OK - vanilla
set "PROFILE_SLOT=1"
goto SET_PROFILE

:DO_MP
echo.
echo  Enabling multiplayer...
>>"!LOG!" echo [%DATE% %TIME%] enable multi
if exist "!GAMEDIR!\version.dll" goto MP_DONE
if not exist "!GAMEDIR!\version.dll.disabled" goto MP_MISSING
ren "!GAMEDIR!\version.dll.disabled" "version.dll"
if errorlevel 1 goto REN_FAIL
goto MP_DONE

:MP_MISSING
>>"!LOG!" echo [%DATE% %TIME%] ERROR no lovely
echo ERROR: Lovely not installed - no version.dll found.
pause
exit /b 1

:REN_FAIL
>>"!LOG!" echo [%DATE% %TIME%] ERROR rename failed
echo ERROR: Could not rename version.dll - close Balatro or run as admin.
pause
exit /b 1

:MP_DONE
echo  OK - modded
set "PROFILE_SLOT=2"
goto SET_PROFILE

:SET_PROFILE
rem Profile 1 = single-player, Profile 2 = multiplayer (settings.jkr)
set "PROFILE_PS1=!LOGDIR!\Set-BalatroProfile.ps1"
if not exist "!PROFILE_PS1!" set "PROFILE_PS1=%~dp0Set-BalatroProfile.ps1"
if not exist "!PROFILE_PS1!" set "PROFILE_PS1=%~dp0..\scripts\Set-BalatroProfile.ps1"
if not exist "!PROFILE_PS1!" (
    >>"!LOG!" echo [%DATE% %TIME%] WARN Set-BalatroProfile.ps1 missing - skip profile switch
    echo  WARNING: Could not set profile slot - script missing.
    goto DO_RUN
)
echo  Setting Balatro profile slot to !PROFILE_SLOT!...
>>"!LOG!" echo [%DATE% %TIME%] set profile=!PROFILE_SLOT!
powershell -NoProfile -ExecutionPolicy Bypass -File "!PROFILE_PS1!" -Profile !PROFILE_SLOT! -LogPath "!LOG!"
if errorlevel 1 (
    >>"!LOG!" echo [%DATE% %TIME%] WARN profile set failed rc=!ERRORLEVEL!
    echo  WARNING: Profile set failed - check log. Game will still launch.
) else (
    echo  OK - profile slot !PROFILE_SLOT!
)

:DO_RUN
echo.
echo  Starting Balatro...
>>"!LOG!" echo [%DATE% %TIME%] launching game
pushd "!GAMEDIR!"
"!EXE!"
set "RC=!ERRORLEVEL!"
popd
>>"!LOG!" echo [%DATE% %TIME%] game exit rc=!RC!
exit /b !RC!
