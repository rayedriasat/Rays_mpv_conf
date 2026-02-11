# MPV Configuration

A curated MPV configuration with enhanced features for better video playback experience.

## Features

- **Persistent Playback**: Automatically saves and resumes playback position
- **Smart Subtitle Management**: Auto-loads matching subtitles and supports manual download
- **Playlist Memory**: Remembers last played position in playlists
- **Folder Position Memory**: Remembers last played file when opening folders
- **History on Empty Start**: Opening MPV with no file shows the **playback history** UI so you can pick what to play (no auto-play).
- **Playback History**: **Persistent** history (survives reboots) in two columns: **Local files** and **Online streams**. Press **h** to show; **Tab** to switch column, **↑/↓** to select, **Enter** to play, **Del** to remove. Local files that no longer exist are shown with strikethrough.
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

- **auto_resume_playlist.lua**: Remembers last played episode in playlist files (m3u8, etc.)
- **remember-folder-position.lua**: Remembers last played file in folders
- **playback-history.lua**: **Persistent** playback history (stored in `playback-history.json`, survives reboots) with two columns: **Local files** and **Online streams**. When you start MPV with no file, the history overlay is shown. **h** = toggle history; **Tab** = switch column; **↑/↓** = move selection; **Enter** = play; **Del** or **Backspace** = remove from history; **h** = close. Local entries for missing files are shown with strikethrough. Both local and online entries can be played from the list.
- **autosub.lua**: Automatic subtitle downloader (auto-detects Python/Subliminal, installs if missing)

## Empty start and history

- **Empty start**: When you open MPV without a file (e.g. from the Start Menu), the **playback history** overlay is shown. You can pick any previous local file or online stream from the list, or press **h** to close the overlay for a blank player.
- **Persistent history**: All played files and streams are stored in `%APPDATA%\\mpv\\playback-history.json` (up to 500 entries). History survives reboots. Local and online entries are shown in two columns; you can remove entries with **Del**.

## Notes

- The `autosub.lua` script can auto-install Subliminal if Python is installed; otherwise it will show an error
- Some scripts may create state files in `%APPDATA%\mpv\` for tracking playback positions
- Configuration is compatible with MPV on Windows

## License

Feel free to use and modify this configuration as needed.
