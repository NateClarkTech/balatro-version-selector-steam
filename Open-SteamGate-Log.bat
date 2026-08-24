@echo off
set "LOG=%LOCALAPPDATA%\BalatroMode\steam-gate.log"
echo.
echo Log path:
echo   %LOG%
echo.
if not exist "%LOG%" (
    echo No log file yet. That means Steam never started the gate,
    echo or Launch Options are wrong/empty.
    echo.
    echo Run Setup-Steam-Launch-Menu.bat, paste the line into Steam,
    echo click Play once, then open this again.
    pause
    exit /b 1
)
echo ----- last 40 lines -----
powershell -NoProfile -Command "Get-Content -LiteralPath $env:LOG -Tail 40"
echo ----- end -----
echo.
echo Opening in Notepad...
notepad "%LOG%"
