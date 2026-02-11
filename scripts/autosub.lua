--=============================================================================
-->>    SUBLIMINAL PATH:
--=============================================================================
local subliminal = 'C:\\Python313\\Scripts\\subliminal.exe'

--=============================================================================
-->>    SUBTITLE LANGUAGES
--=============================================================================
local languages = {
    { 'English', 'en', 'eng' },
    { 'Bengali', 'bn', 'ben' },
}

local logins = {
    -- Empty by default - works without authentication -- breaks with authentication, weird
}

--=============================================================================
-->>    OPTIONS
--=============================================================================
local bools = {
    auto = true,
    debug = false,
    force = false,
    utf8 = true,
}

local utils = require 'mp.utils'
local state = {}

--=============================================================================
-- Utility
--=============================================================================
local function log(msg, dur)
    dur = dur or 3
    mp.msg.warn(msg)
    mp.osd_message(msg, dur)
end

local function sanitize(name)
    if not name then return nil end
    name = name:gsub("%b()", "")         -- remove brackets
    name = name:gsub("[%[%]]", "")
    name = name:gsub("YouTube", "")
    name = name:gsub("Official", "")
    name = name:gsub("Trailer", "")
    name = name:gsub("[^%w%-%._ ]", " ")
    name = name:gsub("%s+", " ")
    return name:match("^%s*(.-)%s*$")
end

local function get_streaming_dir()
    local appdata = os.getenv("APPDATA")
    local dir = appdata .. "\\mpv\\streaming_subs"
    os.execute('mkdir "' .. dir .. '" 2>nul')
    return dir
end

local function has_subtitle_loaded()
    local tracks = mp.get_property_native("track-list")
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            return true
        end
    end
    return false
end

local function find_existing_subtitle(video_path)
    local dir, filename = utils.split_path(video_path)
    local base_name = filename:match("^(.+)%..+$") or filename
    
    local files = utils.readdir(dir, "files") or {}
    
    for _, f in ipairs(files) do
        if (f:match("%.srt$") or f:match("%.ass$")) and f:find(base_name, 1, true) then
            return dir .. "\\" .. f
        end
    end
    
    return nil
end

--=============================================================================
-- Smart Title Detection
--=============================================================================
local function detect_video_path()

    local path = mp.get_property("path")
    if not path then return nil end

    -- STREAM
    if path:match("^https?://") then
        local title = mp.get_property("media-title")
        title = sanitize(title)

        if not title or title == "" then
            log("Stream title unusable for subtitle search")
            return nil
        end

        local dir = get_streaming_dir()
        return dir .. "\\" .. title .. ".mkv"
    end

    -- LOCAL FILE - Always use original path for subliminal
    -- Sanitization is only for finding existing subtitle files
    return path
end

--=============================================================================
-- Download Subtitles
--=============================================================================
local function download_subs(language, force_download)

    if not state.video_path then return false end

    log("Searching for " .. language[1] .. " sub...", 999)

    local dir, _ = utils.split_path(state.video_path)

    local args = { subliminal }

    -- provider logins
    for _, login in ipairs(logins) do
        args[#args+1] = login[1]
        args[#args+1] = login[2]
        args[#args+1] = login[3]
    end

    if bools.debug then
        args[#args+1] = "--debug"
    end

    args[#args+1] = "download"

    -- Use force flag when explicitly requested or from config
    if force_download or bools.force then
        args[#args+1] = "-f"
    end

    if bools.utf8 then
        args[#args+1] = "-e"
        args[#args+1] = "utf-8"
    end

    args[#args+1] = "-l"
    args[#args+1] = language[2]

    args[#args+1] = "-d"
    args[#args+1] = dir

    args[#args+1] = state.video_path

    local before = utils.readdir(dir, "files") or {}

    log("Downloading " .. language[1] .. " sub...", 999)

    local result = utils.subprocess({
        args = args,
        max_size = 10 * 1024 * 1024
    })

    if result.status ~= 0 then
        log("No sub found or error", 5)
        return false
    end

    local after = utils.readdir(dir, "files") or {}
    local new_sub = nil

    -- First check for newly downloaded subtitle
    for _, f in ipairs(after) do
        if f:match("%.srt$") or f:match("%.ass$") then
            local found = false
            for _, bf in ipairs(before) do
                if bf == f then found = true break end
            end
            if not found then
                new_sub = dir .. "\\" .. f
                break
            end
        end
    end

    -- If no new subtitle, check if one exists (might have been downloaded before or forced overwrite)
    if not new_sub then
        new_sub = find_existing_subtitle(state.video_path)
    end

    if new_sub then
        mp.commandv("sub-add", new_sub, "select")
        log("Added " .. language[1] .. " sub", 5)
        return true
    end

    log("No sub found or error", 5)
    return false
end

--=============================================================================
-- Control Logic
--=============================================================================
local function control()

    state.video_path = detect_video_path()
    if not state.video_path then return end

    if not bools.auto then return end

    -- If subtitles already present, DO NOT auto search
    if has_subtitle_loaded() then
        mp.msg.info("Subtitle already present — skipping auto search")
        return
    end

    mp.set_property("sub-auto", "fuzzy")

    -- First check if subtitle file already exists
    local existing_sub = find_existing_subtitle(state.video_path)
    if existing_sub then
        mp.commandv("sub-add", existing_sub, "select")
        log("Existing sub file loaded", 5)
        return
    end

    -- If no existing subtitle, try to download
    for _, language in ipairs(languages) do
        if download_subs(language, false) then
            return
        end
    end

    log("No sub found or error", 5)
end

--=============================================================================
-- Manual Keys
--=============================================================================
mp.add_key_binding("b", "download_en", function()
    state.video_path = detect_video_path()
    if not state.video_path then
        log("Cannot detect video path", 3)
        return
    end
    -- Check if subtitle is already loaded in mpv
    if has_subtitle_loaded() then
        log("Already loaded sub", 3)
        return
    end
    -- Check if subtitle file exists
    local existing_sub = find_existing_subtitle(state.video_path)
    if existing_sub then
        mp.commandv("sub-add", existing_sub, "select")
        log("Existing sub file loaded", 5)
        return
    end
    -- If not found, download normally (without force)
    download_subs(languages[1], false)
end)

mp.add_key_binding("n", "download_bn", function()
    state.video_path = detect_video_path()
    if not state.video_path then
        log("Cannot detect video path", 3)
        return
    end
    -- Check if subtitle is already loaded in mpv
    if has_subtitle_loaded() then
        log("Already loaded sub", 3)
        return
    end
    -- Check if subtitle file exists
    local existing_sub = find_existing_subtitle(state.video_path)
    if existing_sub then
        mp.commandv("sub-add", existing_sub, "select")
        log("Existing sub file loaded", 5)
        return
    end
    -- If not found, download normally (without force)
    download_subs(languages[2], false)
end)

-- Shift+b and Shift+n for forced re-download
mp.add_key_binding("Shift+b", "force_download_en", function()
    state.video_path = detect_video_path()
    if not state.video_path then
        log("Cannot detect video path", 3)
        return
    end
    -- Force re-download even if subtitle exists
    download_subs(languages[1], true)
end)

mp.add_key_binding("Shift+n", "force_download_bn", function()
    state.video_path = detect_video_path()
    if not state.video_path then
        log("Cannot detect video path", 3)
        return
    end
    -- Force re-download even if subtitle exists
    download_subs(languages[2], true)
end)

mp.register_event("file-loaded", control)
