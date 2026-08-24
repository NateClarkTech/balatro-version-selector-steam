@echo off
setlocal EnableExtensions
title Setup Steam Balatro launch menu
color 0E

set "ROOT=%~dp0"
set "SCRIPTS=%ROOT%scripts"
set "CONFIG=%ROOT%config"
set "INSTALLDIR=%LOCALAPPDATA%\BalatroMode"
set "GATE=%INSTALLDIR%\steam-gate.cmd"
set "UI=%INSTALLDIR%\steam-gate-ui.cmd"
set "LOG=%INSTALLDIR%\steam-gate.log"
set "CMDEXE=C:\Windows\System32\cmd.exe"

if not exist "%SCRIPTS%\Balatro-SteamGate.bat" (
    echo ERROR: Missing "%SCRIPTS%\Balatro-SteamGate.bat"
    pause
    exit /b 1
)

if not exist "%INSTALLDIR%" mkdir "%INSTALLDIR%"

copy /Y "%SCRIPTS%\Balatro-SteamGate.bat" "%GATE%" >nul
copy /Y "%SCRIPTS%\steam-gate-ui.cmd" "%UI%" >nul
copy /Y "%SCRIPTS%\Invoke-BalatroMode.ps1" "%INSTALLDIR%\Invoke-BalatroMode.ps1" >nul
copy /Y "%SCRIPTS%\Set-BalatroProfile.ps1" "%INSTALLDIR%\Set-BalatroProfile.ps1" >nul

rem Install modes.json only if the user does not already have one
if not exist "%INSTALLDIR%\modes.json" (
    if exist "%CONFIG%\modes.json" (
        copy /Y "%CONFIG%\modes.json" "%INSTALLDIR%\modes.json" >nul
    ) else if exist "%CONFIG%\modes.example.json" (
        copy /Y "%CONFIG%\modes.example.json" "%INSTALLDIR%\modes.json" >nul
    )
)

cls
echo.
echo  ============================================================
echo   Steam Balatro launch menu
echo  ============================================================
echo.
echo  Installed to:
echo    %INSTALLDIR%
echo.
echo  Mode config (edit this to add more mod packs):
echo    %INSTALLDIR%\modes.json
echo  Repo template:
echo    %CONFIG%\modes.example.json
echo.
echo  Priority: LocalAppData modes.json  then  repo config\modes.json
echo.
echo  LOG:
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
echo    2. Clear the box, paste the line above
echo    3. Play - pick a mode from your config
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
