# Meeting Notes - First-time setup script
# Run this once on any new machine

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Meeting Notes - Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir

# 1. Check Node.js
Write-Host "[1/4] Checking Node.js..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  Node.js not found. Opening download page..." -ForegroundColor Red
    Start-Process "https://nodejs.org/en/download"
    Write-Host "  Install Node.js then re-run this script." -ForegroundColor Red
    pause; exit 1
}
Write-Host "  Node.js $(node --version) found." -ForegroundColor Green

# 2. Install npm dependencies
Write-Host "[2/4] Installing dependencies..." -ForegroundColor Yellow
npm install --silent
Write-Host "  Done." -ForegroundColor Green

# 3. Install Claude Code CLI
Write-Host "[3/4] Installing Claude Code CLI..." -ForegroundColor Yellow
npm install -g @anthropic-ai/claude-code --silent 2>$null
Write-Host "  Done." -ForegroundColor Green

# 4. Log in to Claude
Write-Host "[4/4] Logging in to Claude..." -ForegroundColor Yellow
Write-Host "  A browser window will open — sign in with your corporate account.`n" -ForegroundColor White
claude auth login

# Create desktop shortcut
Write-Host "`nCreating desktop shortcut..." -ForegroundColor Yellow
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\Meeting Notes.lnk")
$shortcut.TargetPath = "$dir\Meeting Notes.bat"
$shortcut.WorkingDirectory = $dir
$shortcut.Description = "Start Meeting Notes app"
$shortcut.IconLocation = "shell32.dll,13"
$shortcut.Save()
Write-Host "  Shortcut created on desktop." -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "  Double-click 'Meeting Notes' on your desktop to start." -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan
pause
