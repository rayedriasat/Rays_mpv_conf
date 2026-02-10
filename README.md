# MPV Configuration

A curated MPV configuration with enhanced features for better video playback experience.

## Features

- **Persistent Playback**: Automatically saves and resumes playback position
- **Smart Subtitle Management**: Auto-loads matching subtitles and supports manual download
- **Playlist Memory**: Remembers last played position in playlists
- **Folder Position Memory**: Remembers last played file when opening folders
- **Resume on Empty Start**: Opening MPV from Start Menu (no file) resumes the last played file/playlist/folder
- **Playback History**: Press **h** to show last 10 played files; press 1–0 to play, or ↑↓ + Enter to select
- **Volume Boost**: Extended volume range up to 300%

## Quick Setup

### Windows (One-Click Install)

1. Download this repository or clone it:
   ```bash
   git clone https://github.com/rayedriasat/Rays_mpv_conf.git
   cd Rays_mpv_conf
   ```

2. Run the setup script:
   
   **Option A - Batch file (Easiest):**
   - Double-click `setup-mpv-config.bat`
   
   **Option B - PowerShell script:**
   - Right-click on `setup-mpv-config.ps1` and select **"Run with PowerShell"**
   - Or open PowerShell in this directory and run:
     ```powershell
     .\setup-mpv-config.ps1
     ```

The script will:
- Copy `mpv.conf` to `%APPDATA%\mpv\`
- Copy all Lua scripts to `%APPDATA%\mpv\scripts\`
- Show installation instructions if MPV is not installed

### Manual Setup

1. Copy `mpv.conf` to `%APPDATA%\mpv\mpv.conf`
2. Copy all files from `scripts\` to `%APPDATA%\mpv\scripts\`

## MPV Installation

If MPV is not installed, choose one of these methods:

### Option 1: Chocolatey (Recommended)
```powershell
choco install mpvio
```

### Option 2: Official Website
Download from: https://mpv.io/installation/

### Option 3: Scoop
```powershell
scoop bucket add extras
scoop install extras/mpv
```


## Configuration Details

### Main Configuration (`mpv.conf`)

- Volume boost up to 300%
- Auto-save playback position on quit
- Resume playback from saved position
- Auto-load matching subtitle files
- Preferred subtitle language: English

### Included Scripts

- **auto-resume-last.lua**: Resumes last played file/playlist/folder when you open MPV without arguments (e.g. from Start Menu). Saves session whenever the current path changes so the last path is never lost.
- **auto_resume_playlist.lua**: Remembers last played episode in playlist files (m3u8, etc.)
- **remember-folder-position.lua**: Remembers last played file in folders
- **playback-history.lua**: Press **h** to toggle a list of the last 10 played files. Use **1–9** and **0** to play that entry, or **↑/↓** to move selection and **Enter** to play. Press **h** or **Esc** to hide.
- **autosub.lua**: Automatic subtitle downloader (auto-detects Python/Subliminal, installs if missing)

## Why “resume on empty start” failed before (and how it was fixed)

- **What was wrong**  
  The “last session” was only written in the **shutdown** handler. By the time MPV runs that handler, the current **path** can already be cleared or empty, so the script was saving a session with an empty path. When you started MPV with no file, it tried to resume but had nothing valid to load.

- **What fixed it**  
  The script was changed to **save the session whenever the current path changes** (using `mp.observe_property("path", ...)`), not only on shutdown. So the last played file/playlist/folder is always stored while you’re still playing. When you open MPV without arguments, the same resume logic runs but now finds a valid path and loads it.

## Notes

- The `autosub.lua` script can auto-install Subliminal if Python is installed; otherwise it will show an error
- Some scripts may create state files in `%APPDATA%\mpv\` for tracking playback positions
- Configuration is compatible with MPV on Windows

## License

Feel free to use and modify this configuration as needed.
