# Meeting Notes & Task Board

A local web app for recording meetings, AI summarisation, and kanban task tracking.

## Features
- 🎙️ Live speech-to-text meeting recording
- ✨ AI summary + action item extraction (via Claude)
- ✅ Editable action items with owner, due date, priority
- 📋 Kanban board (To Do / Doing / Done) with drag & drop
- 💾 Meeting summaries saved as Markdown files
- 🎨 8 colour themes + custom colour picker

## Setup

### 1. Install dependencies
```
npm install
```

### 2. Authenticate with Claude
```
claude auth login
```
Log in with your Claude.ai or corporate account. No API key needed.

### 3. Start the server
```powershell
.\start.ps1
```

### 4. Open the app
```
http://localhost:8080/meeting-notes.html
```

## Files
| File | Purpose |
|------|---------|
| `meeting-notes.html` | The web app (single file) |
| `serve.js` | Local Node.js server + AI proxy |
| `start.ps1` | Auto-restarting server launcher |
| `meetings/` | Saved meeting summaries (Markdown, git-ignored) |
| `config.json` | Local config — git-ignored, never committed |

## Notes
- All data stored locally — nothing leaves your machine except AI prompts sent to Claude
- `config.json` and `meetings/` are in `.gitignore` so credentials and notes stay private
