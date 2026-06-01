@echo off
cd /d "%~dp0"
echo Starting Meeting Notes...
start "" "http://localhost:8080/meeting-notes.html"
powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1"
