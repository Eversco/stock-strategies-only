@echo off
rem Double-click to start the Web UI (bypasses the PowerShell execution policy)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-web.ps1"
