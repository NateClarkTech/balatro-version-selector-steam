@echo off
setlocal EnableExtensions
title Balatro Mode Selector
color 0B
set "ENGINE=%~dp0scripts\Invoke-BalatroMode.ps1"
if not exist "%ENGINE%" (
    echo ERROR: Missing %ENGINE%
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Menu -Launch
set "RC=%ERRORLEVEL%"
if %RC% neq 0 (
    echo.
    pause
)
exit /b %RC%
