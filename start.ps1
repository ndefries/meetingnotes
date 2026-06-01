# Meeting Notes - auto-restarting server
Write-Host "`n Meeting Notes Server" -ForegroundColor Cyan
Write-Host " App: http://localhost:8080/meeting-notes.html`n" -ForegroundColor Green

while ($true) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting server..." -ForegroundColor Yellow
    $p = Start-Process node -ArgumentList "$PSScriptRoot\serve.js" -PassThru -NoNewWindow
    $p.WaitForExit()
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Server stopped (exit $($p.ExitCode)), restarting in 2s..." -ForegroundColor Red
    Start-Sleep -Seconds 2
}
