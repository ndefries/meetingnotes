# Meeting Notes - PowerShell HTTP server (no Node.js required)
# Uses the Claude Code app already installed on this machine

$root = $PSScriptRoot
$port = 8080
$meetingsDir = Join-Path $root "meetings"
$appdataPath = Join-Path $root "appdata.json"

if (-not (Test-Path $meetingsDir)) { New-Item -ItemType Directory -Path $meetingsDir | Out-Null }

# Locate claude.exe once at startup and cache it
function Find-ClaudeExe {
    # Try known fixed paths first (most reliable on work machines)
    $knownPaths = @(
        "C:\Users\DefriesN\AppData\Roaming\Claude\claude-code\2.1.156\claude.exe",
        "C:\Users\DefriesN\AppData\Roaming\Claude\claude-code\2.1.149\claude.exe"
    )
    foreach ($p in $knownPaths) {
        if (Test-Path $p) { return $p }
    }
    # Dynamic search fallback
    foreach ($appdata in @($env:APPDATA, "C:\Users\DefriesN\AppData\Roaming")) {
        if (-not $appdata) { continue }
        $dir = Join-Path $appdata "Claude\claude-code"
        if (Test-Path $dir) {
            $exe = Get-ChildItem -Path $dir -Recurse -Filter "claude.exe" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($exe) { return $exe.FullName }
        }
    }
    return $null
}

# Cache at startup so HTTP handler doesn't re-search every request
$script:claudeExePath = Find-ClaudeExe

function Invoke-ClaudeAI($prompt) {
    $claudeExe = $script:claudeExePath
    if (-not $claudeExe) { throw "claude_not_found" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $claudeExe
    $psi.Arguments = "--print --output-format text"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write($prompt)
    $proc.StandardInput.Close()

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit(120000)

    if ($proc.ExitCode -ne 0) { throw $stderr }
    return $stdout.Trim()
}

function Parse-SummaryResponse($content) {
    $summary = $content
    $actions  = @()
    if ($content -match '(?s)SUMMARY:\s*(.*?)(?=ACTIONS_JSON:|$)') { $summary = $matches[1].Trim() }
    if ($content -match '(?s)ACTIONS_JSON:\s*(.*)') {
        $json = $matches[1].Trim() -replace '```json\r?\n?|\r?\n?```', ''
        try { $actions = $json | ConvertFrom-Json } catch {}
    }
    return @{ summary = $summary; actions = $actions }
}

function Save-MeetingFile($title, $date, $duration, $transcript, $summary, $actions) {
    $safe    = (($title, 'untitled' | Where-Object { $_ })[0]) -replace '[^a-z0-9]+', '-'
    $safe    = $safe.ToLower().Trim('-')
    $dateStr = if ($date) { try { ([datetime]$date).ToString('yyyy-MM-dd') } catch { Get-Date -Format 'yyyy-MM-dd' } } else { Get-Date -Format 'yyyy-MM-dd' }
    $displayDate = if ($date) { try { ([datetime]$date).ToString('dd/MM/yyyy HH:mm') } catch { Get-Date -Format 'dd/MM/yyyy HH:mm' } } else { Get-Date -Format 'dd/MM/yyyy HH:mm' }
    $filename = "$dateStr-$safe.md"
    $filepath = Join-Path $meetingsDir $filename

    if ($actions -and $actions.Count) {
        $actionRows = ($actions | ForEach-Object {
            $owner    = if ($_.owner)    { $_.owner }    else { 'TBC' }
            $dueDate  = if ($_.dueDate)  { $_.dueDate }  else { 'TBC' }
            $priority = if ($_.priority) { $_.priority } else { 'medium' }
            "| $($_.action) | $owner | $dueDate | $priority |"
        }) -join "`n"
    } else {
        $actionRows = "| No actions identified | N/A | N/A | N/A |"
    }

    $dur = if ($duration) { $duration } else { 'N/A' }

    $md = "# $title`n`n**Date:** $displayDate`n**Duration:** $dur`n`n---`n`n## Summary`n`n$summary`n`n---`n`n## Action Items`n`n| Action | Owner | Due Date | Priority |`n|--------|-------|----------|----------|`n$actionRows`n`n---`n`n## Transcript / Notes`n`n$transcript"
    [System.IO.File]::WriteAllText($filepath, $md, [System.Text.Encoding]::UTF8)
    return $filename
}

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'text/javascript'
    '.css'  = 'text/css'
    '.json' = 'application/json'
    '.md'   = 'text/markdown'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

$claudeExe = Find-ClaudeExe
Write-Host ""
Write-Host " Meeting Notes Server (PowerShell)" -ForegroundColor Cyan
Write-Host " App: http://localhost:$port/meeting-notes.html" -ForegroundColor Green
Write-Host ""
if ($claudeExe) {
    Write-Host " Claude: $claudeExe" -ForegroundColor Green
    Write-Host " AI summarisation: READY" -ForegroundColor Green
} else {
    Write-Host " WARNING: claude.exe not found - AI summarisation unavailable" -ForegroundColor Yellow
}
Write-Host ""
Write-Host " Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

while ($listener.IsListening) {
    $ctx = $null
    try { $ctx = $listener.GetContext() } catch { break }

    $req = $ctx.Request
    $res = $ctx.Response
    $res.Headers.Add("Access-Control-Allow-Origin", "*")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

    if ($req.HttpMethod -eq "OPTIONS") { $res.StatusCode = 204; $res.Close(); continue }

    $url     = $req.Url.AbsolutePath
    $bodyStr = ""
    $body    = $null

    if ($req.HasEntityBody) {
        $reader  = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
        $bodyStr = $reader.ReadToEnd()
        $reader.Close()
        try { $body = $bodyStr | ConvertFrom-Json } catch {}
    }

    try {
        # ── GET /api/status ──────────────────────────────────────────────────
        if ($req.HttpMethod -eq "GET" -and $url -eq "/api/status") {
            $cli   = $script:claudeExePath
            if ($cli) {
                $json = '{"ready":true,"method":"cli","model":"claude-sonnet-4-6"}'
            } else {
                $json = '{"ready":false,"method":"none","model":"claude-sonnet-4-6"}'
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        # ── POST /api/summarise ──────────────────────────────────────────────
        elseif ($req.HttpMethod -eq "POST" -and $url -eq "/api/summarise") {
            $text       = $body.text
            $title      = if ($body.title)    { $body.title }    else { "Untitled Meeting" }
            $date       = $body.date
            $duration   = $body.duration
            $transcript = $body.transcript

            $prompt = "You are a meeting assistant. Analyse this meeting transcript/notes and produce:`n`n1. A concise executive summary (3-5 sentences covering key decisions and discussion points)`n2. A JSON array of action items:`n[{`"action`":`"task description`",`"owner`":`"person name or empty string`",`"dueDate`":`"YYYY-MM-DD or empty string`",`"priority`":`"high|medium|low`"}]`n`nMeeting Title: $title`nTranscript/Notes:`n$text`n`nRespond with exactly:`nSUMMARY:`n<summary text>`n`nACTIONS_JSON:`n<json array>"

            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Summarising: $title" -ForegroundColor Yellow
            $aiResponse = Invoke-ClaudeAI $prompt
            $parsed     = Parse-SummaryResponse $aiResponse
            $filename   = Save-MeetingFile $title $date $duration $transcript $parsed.summary $parsed.actions
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Done -> meetings/$filename" -ForegroundColor Green

            $result = @{ summary = $parsed.summary; actions = $parsed.actions; filename = $filename } | ConvertTo-Json -Depth 10
            $bytes  = [System.Text.Encoding]::UTF8.GetBytes($result)
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        # ── GET /api/appdata ─────────────────────────────────────────────────
        elseif ($req.HttpMethod -eq "GET" -and $url -eq "/api/appdata") {
            $data  = if (Test-Path $appdataPath) { Get-Content $appdataPath -Raw -Encoding UTF8 } else { '{"meetings":[],"tasks":[]}' }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        # ── POST /api/appdata ────────────────────────────────────────────────
        elseif ($req.HttpMethod -eq "POST" -and $url -eq "/api/appdata") {
            [System.IO.File]::WriteAllText($appdataPath, $bodyStr, [System.Text.Encoding]::UTF8)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        # ── GET /api/files ───────────────────────────────────────────────────
        elseif ($req.HttpMethod -eq "GET" -and $url -eq "/api/files") {
            $files = @(Get-ChildItem $meetingsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                       Sort-Object Name -Descending |
                       ForEach-Object { @{ name = $_.Name; url = "/meetings/$($_.Name)" } })
            $json  = $files | ConvertTo-Json -Depth 3
            if (-not $json) { $json = "[]" }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        # ── Static files ─────────────────────────────────────────────────────
        else {
            $filePath = if ($url -eq "/") { "meeting-notes.html" } else { $url.TrimStart('/') }
            $fullPath = Join-Path $root $filePath

            if (Test-Path $fullPath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($fullPath)
                $res.ContentType = if ($mime[$ext]) { $mime[$ext] } else { "text/plain" }
                $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                $res.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
            } else {
                $res.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
    } catch {
        $res.StatusCode = 500
        $errMsg = "{`"error`":`"$($_.Exception.Message -replace '"','\"')`"}"
        $bytes  = [System.Text.Encoding]::UTF8.GetBytes($errMsg)
        $res.ContentType = "application/json"
        try { $res.OutputStream.Write($bytes, 0, $bytes.Length) } catch {}
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    try { $res.Close() } catch {}
}

$listener.Stop()
