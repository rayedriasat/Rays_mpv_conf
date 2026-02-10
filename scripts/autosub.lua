--=============================================================================
-->>    SUBLIMINAL PATH:
--=============================================================================
local subliminal = 'C:\\Python313\\Scripts\\subliminal.exe' -- your subliminal path
--=============================================================================
-->>    SUBTITLE LANGUAGE:
--=============================================================================
local languages = {
    { 'English', 'en', 'eng' },
    { 'Bengali', 'bn', 'ben' },
}
--=============================================================================
-->>    PROVIDER LOGINS:
--=============================================================================
local logins = {
    { '--addic7ed', '<your_addic7ed_username>', '<your_addic7ed_password>' }, -- your addic7ed username and password
}
--=============================================================================
-->>    ADDITIONAL OPTIONS:
--=============================================================================
local bools = {
    auto = true,
    debug = false,
    force = true,
    utf8 = true,
}
local excludes = {
    'no-subs-dl',
}
local includes = {}
--=============================================================================
local utils = require 'mp.utils'

-- State to store video path across functions
local state = {}

-- Get the system's temporary directory
local function get_temp_dir()
    local temp = os.getenv('TEMP') or os.getenv('TMP') or os.getenv('TMPDIR') or '/tmp'
    return temp
end

-- Sanitize filename by replacing invalid characters with underscores
local function sanitize_filename(name)
    return name:gsub('[^%w%-%._]', '_')
end

-- Download subtitles using Subliminal and load them into MPV
function download_subs(language, video_path)
    language = language or languages[1]
    if #language == 0 then
        log('No Language found\n')
        return false
    end

    log('Searching ' .. language[1] .. ' subtitles ...', 30)

    -- Extract directory from video_path
    local dir, _ = utils.split_path(video_path)
    local table = { args = { subliminal } }
    local a = table.args

    -- Add provider logins
    for _, login in ipairs(logins) do
        a[#a + 1] = login[1]
        a[#a + 1] = login[2]
        a[#a + 1] = login[3]
    end
    if bools.debug then
        a[#a + 1] = '--debug'
    end

    a[#a + 1] = 'download'
    if bools.force then
        a[#a + 1] = '-f'
    end
    if bools.utf8 then
        a[#a + 1] = '-e'
        a[#a + 1] = 'utf-8'
    end

    a[#a + 1] = '-l'
    a[#a + 1] = language[2]
    a[#a + 1] = '-d'
    a[#a + 1] = dir
    a[#a + 1] = video_path

    local result = utils.subprocess(table)

    -- Check if a subtitle was downloaded
    if result.status == 0 and string.find(result.stdout, 'Downloaded 1 subtitle') then
        -- Construct expected subtitle path (e.g., "video_name.en.srt")
        local base_name = video_path:match('^(.*)%.') or video_path:match('^(.*)/') or video_path
        base_name = base_name:match('[^/]*$') -- Get filename without path
        local sub_path = dir .. '/' .. base_name .. '.' .. language[2] .. '.srt'
        
        -- Verify subtitle file exists and load it
        if utils.file_info(sub_path) then
            mp.commandv('sub-add', sub_path, 'select', language[1], language[2])
            log(language[1] .. ' subtitles loaded!')
            return true
        else
            log('Subtitle file not found after download')
            return false
        end
    else
        log('No ' .. language[1] .. ' subtitles found\n')
        return false
    end
end

-- Control subtitle downloading on file load
function control_downloads()
    local path = mp.get_property('path')
    if not path then
        log('No video path available')
        return
    end

    -- Handle online streams
    if path:match('^https?://') then
        local media_title = mp.get_property('media-title')
        if not media_title or media_title == '' then
            log('No media-title available for stream, cannot download subtitles')
            return
        end
        local sanitized_title = sanitize_filename(media_title)
        local temp_dir = get_temp_dir() .. '/mpv_subtitles'
        -- Create temporary directory (Note: os.execute is not ideal, but sufficient here)
        os.execute('mkdir -p "' .. temp_dir .. '"') -- Use quotes for Windows compatibility
        state.video_path = temp_dir .. '/' .. sanitized_title .. '.mkv'
        local temp_file = io.open(state.video_path, 'w')
        if temp_file then
            temp_file:close()
        else
            log('Failed to create temporary file for stream')
            return
        end
    else
        state.video_path = path
    end

    if not autosub_allowed() then
        return
    end

    -- Set MPV properties
    mp.set_property('sub-auto', 'fuzzy')
    mp.set_property('slang', languages[1][2])

    -- Check existing subtitle tracks
    sub_tracks = {}
    for _, track in ipairs(mp.get_property_native('track-list')) do
        if track['type'] == 'sub' then
            sub_tracks[#sub_tracks + 1] = track
        end
    end

    -- Attempt to download subtitles if needed
    for _, language in ipairs(languages) do
        if should_download_subs_in(language) then
            if download_subs(language, state.video_path) then
                return
            end
        else
            return
        end
    end
    log('No subtitles were found')
end

-- Check if auto-downloading is allowed
function autosub_allowed()
    local duration = tonumber(mp.get_property('duration'))
    local active_format = mp.get_property('file-format')
    local directory = utils.split_path(mp.get_property('path')) -- First element is directory

    if not bools.auto then
        mp.msg.warn('Automatic downloading disabled!')
        return false
    elseif duration and duration < 900 then
        mp.msg.warn('Video is less than 15 minutes\n=> NOT auto-downloading subtitles')
        return false
    elseif active_format and active_format:find('^cue') then
        mp.msg.warn('Automatic subtitle downloading is disabled for cue files')
        return false
    else
        local not_allowed = {'aiff', 'ape', 'flac', 'mp3', 'ogg', 'wav', 'wv', 'tta'}
        for _, file_format in pairs(not_allowed) do
            if file_format == active_format then
                mp.msg.warn('Automatic subtitle downloading is disabled for audio files')
                return false
            end
        end

        for _, exclude in pairs(excludes) do
            local escaped_exclude = exclude:gsub('%W', '%%%0')
            if directory and directory:find(escaped_exclude) then
                mp.msg.warn('This path is excluded from auto-downloading subs')
                return false
            end
        end

        for i, include in ipairs(includes) do
            local escaped_include = include:gsub('%W', '%%%0')
            if directory and directory:find(escaped_include) then
                break
            elseif i == #includes then
                mp.msg.warn('This path is not included for auto-downloading subs')
                return false
            end
        end
    end

    return true
end

-- Check if subtitles need to be downloaded for a language
function should_download_subs_in(language)
    for i, track in ipairs(sub_tracks) do
        local subtitles = track['external'] and 'subtitle file' or 'embedded subtitles'
        if not track['lang'] and (track['external'] or not track['title']) and i == #sub_tracks then
            local status = track['selected'] and ' active' or ' present'
            log('Unknown ' .. subtitles .. status)
            mp.msg.warn('=> NOT downloading new subtitles')
            return false
        elseif track['lang'] == language[3] or track['lang'] == language[2] or
               (track['title'] and track['title']:lower():find(language[3])) then
            if not track['selected'] then
                mp.set_property('sid', track['id'])
                log('Enabled ' .. language[1] .. ' ' .. subtitles .. '!')
            else
                log(language[1] .. ' ' .. subtitles .. ' active')
            end
            mp.msg.warn('=> NOT downloading new subtitles')
            return false
        end
    end
    mp.msg.warn('No ' .. language[1] .. ' subtitles were detected\n=> Proceeding to download:')
    return true
end

-- Log messages to terminal and OSD
function log(string, secs)
    secs = secs or 2.5
    mp.msg.warn(string)
    mp.osd_message(string, secs)
end

-- Key bindings for manual subtitle download
mp.add_key_binding('b', 'download_subs', function() 
    if state.video_path then 
        download_subs(languages[1], state.video_path) 
    else 
        log('No video loaded to download subtitles for')
    end 
end)
mp.add_key_binding('n', 'download_subs2', function() 
    if state.video_path then 
        download_subs(languages[2], state.video_path) 
    else 
        log('No video loaded to download subtitles for')
    end 
end)

-- Register event to trigger on file load
mp.register_event('file-loaded', control_downloads)