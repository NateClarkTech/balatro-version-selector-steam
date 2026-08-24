@echo off
setlocal EnableExtensions
title Balatro Single-player
set "ENGINE=%~dp0scripts\Invoke-BalatroMode.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -ModeId vanilla -Launch
if errorlevel 1 pause
endlocal
