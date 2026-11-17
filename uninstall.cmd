@echo off
chcp 65001 >nul
title Desinstalar DocxViewer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
pause
