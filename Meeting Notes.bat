@echo off
cd /d "%~dp0"
echo Starting Meeting Notes server...
start "" powershell -ExecutionPolicy Bypass -WindowStyle Minimized -File "%~dp0start.ps1"
echo Waiting for server to start...
timeout /t 4 /nobreak >nul
start "" "http://localhost:8080/meeting-notes.html"
