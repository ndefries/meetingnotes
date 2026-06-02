# Meeting Notes - start server and open browser (no Node.js required)
Write-Host "`n Meeting Notes" -ForegroundColor Cyan
Write-Host " Starting server..." -ForegroundColor Yellow

# Open browser after a short delay
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:8080/meeting-notes.html"
} | Out-Null

# Run the PowerShell server (blocks until Ctrl+C)
& "$PSScriptRoot\serve.ps1"
