@echo off
setlocal EnableExtensions
title Setup Steam Balatro launch menu
color 0E

set "ROOT=%~dp0"
set "SCRIPTS=%ROOT%scripts"
set "INSTALLDIR=%LOCALAPPDATA%\BalatroMode"
set "GATE=%INSTALLDIR%\steam-gate.cmd"
set "UI=%INSTALLDIR%\steam-gate-ui.cmd"
set "PROFILE_PS1=%INSTALLDIR%\Set-BalatroProfile.ps1"
set "LOG=%INSTALLDIR%\steam-gate.log"
set "CMDEXE=C:\Windows\System32\cmd.exe"

if not exist "%SCRIPTS%\Balatro-SteamGate.bat" (
    echo ERROR: Missing "%SCRIPTS%\Balatro-SteamGate.bat"
    echo Did you move or delete the scripts folder?
    pause
    exit /b 1
)

if not exist "%INSTALLDIR%" mkdir "%INSTALLDIR%"
copy /Y "%SCRIPTS%\Balatro-SteamGate.bat" "%GATE%" >nul
copy /Y "%SCRIPTS%\steam-gate-ui.cmd" "%UI%" >nul
copy /Y "%SCRIPTS%\Set-BalatroProfile.ps1" "%PROFILE_PS1%" >nul

if not exist "%GATE%" (
    echo ERROR: install failed
    pause
    exit /b 1
)
if not exist "%UI%" (
    echo ERROR: UI install failed
    pause
    exit /b 1
)
if not exist "%PROFILE_PS1%" (
    echo ERROR: profile script install failed
    pause
    exit /b 1
)

cls
echo.
echo  ============================================================
echo   Steam Balatro launch menu
echo  ============================================================
echo.
echo  Installed to:
echo    %GATE%
echo    %UI%
echo    %PROFILE_PS1%
echo.
echo  Profiles on launch:
echo    Single-player -^> slot 1  (vanilla / Lovely off)
echo    Multiplayer   -^> slot 2  (modded / Lovely on)
echo.
echo  LOG FILE:
echo    %LOG%
echo.
echo  ------------------------------------------------------------
echo   PASTE THIS INTO STEAM LAUNCH OPTIONS
echo  ------------------------------------------------------------
echo.
echo  %CMDEXE% /c %GATE% %%command%%
echo.
echo  Steps:
echo    1. Steam -^> Balatro -^> Properties -^> Launch Options
echo    2. Delete everything in the box
echo    3. Paste the line above
echo    4. Play - a black window "Balatro Mode" should open
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Clipboard -Value ('%CMDEXE% /c %GATE% ' + [char]37 + 'command' + [char]37)"
if errorlevel 1 (
    echo  Clipboard failed - copy the line manually.
) else (
    echo  COPIED TO CLIPBOARD.
)
echo.
pause
endlocal
