@echo off
rem Double-click to run setup_dl2026.ps1 (bypasses PowerShell execution policy for this run only)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_dl2026.ps1"
pause
