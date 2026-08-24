@echo off
setlocal EnableExtensions
title Balatro Multiplayer
set "ENGINE=%~dp0scripts\Invoke-BalatroMode.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -ModeId multiplayer -Launch
if errorlevel 1 pause
endlocal
