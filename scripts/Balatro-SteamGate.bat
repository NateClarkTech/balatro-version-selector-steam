@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Steam entrypoint: open a visible console, then run the UI script.
rem Launch Options:
rem   C:\Windows\System32\cmd.exe /c C:\Users\Nate\AppData\Local\BalatroMode\steam-gate.cmd %command%

set "LOGDIR=%LOCALAPPDATA%\BalatroMode"
if not exist "!LOGDIR!" mkdir "!LOGDIR!"
set "LOG=!LOGDIR!\steam-gate.log"
set "UI=!LOGDIR!\steam-gate-ui.cmd"

>>"!LOG!" echo --------
>>"!LOG!" echo [%DATE% %TIME%] LAUNCHER START
>>"!LOG!" echo [%DATE% %TIME%] ARGS=%*
>>"!LOG!" echo [%DATE% %TIME%] UI=!UI!

if not exist "!UI!" (
    >>"!LOG!" echo [%DATE% %TIME%] ERROR missing UI script
    echo ERROR: Missing steam-gate-ui.cmd - run Setup-Steam-Launch-Menu.bat
    pause
    exit /b 1
)

rem start /wait guarantees a real console window for choice.exe
rem Paths under LocalAppData have no spaces; keep quoting simple for Steam args.
>>"!LOG!" echo [%DATE% %TIME%] starting visible UI window
start "Balatro Mode" /wait "%ComSpec%" /c call "!UI!" %*
set "RC=!ERRORLEVEL!"
>>"!LOG!" echo [%DATE% %TIME%] UI finished rc=!RC!
exit /b !RC!
