-- auto-resume-last.lua
-- Automatically resumes the last played item (file, playlist, or folder) when mpv starts without arguments

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local resume_dir = mp.command_native({"expand-path", "~~/"})
local last_session_file = resume_dir .. "/last-session.json"

-- Function to normalize path for comparison (Windows compatible)
local function normalize_path(path)
    if not path then return nil end
    return path:gsub("\\", "/"):lower()
end

-- Function to get folder path from file path
local function get_folder_path(file_path)
    if not file_path then return nil end
    local dir, _ = utils.split_path(file_path)
    return dir
end

-- Function to check if all playlist items are from the same folder
local function is_folder_playlist(playlist)
    if not playlist or #playlist < 2 then return false, nil end
    
    local first_folder = nil
    for _, item in ipairs(playlist) do
        local item_path = item.filename or item.path
        if not item_path then return false, nil end
        
        local folder = normalize_path(get_folder_path(item_path))
        if not first_folder then
            first_folder = folder
        elseif folder ~= first_folder then
            return false, nil
        end
    end
    
    return true, first_folder
end

-- Function to check if path is a playlist file
local function is_playlist_file(path)
    if not path then return false end
    return path:match("%.m3u8?$") ~= nil or 
           path:match("%.pls$") ~= nil or 
           path:match("%.cue$") ~= nil
end

-- Save session state whenever path changes (not just on shutdown)
local function save_current_session()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    local current_path = mp.get_property("path", "")
    
    -- Only save if we have a valid path
    if not current_path or current_path == "" then
        return
    end
    
    if playlist_count == 0 then
        return
    end
    
    local playlist = mp.get_property_native("playlist", {})
    local playlist_pos = mp.get_property_number("playlist-pos", 0)
    
    -- Determine session type
    local session_type = "file"
    local session_data = {
        path = current_path,
        position = playlist_pos,
        timestamp = os.time()
    }
    
    -- Check if it's a playlist file
    if is_playlist_file(current_path) then
        session_type = "playlist_file"
        session_data.playlist = playlist
    -- Check if it's a folder playlist
    elseif playlist_count > 1 then
        local is_folder, folder_path = is_folder_playlist(playlist)
        if is_folder then
            session_type = "folder"
            session_data.folder = folder_path
            session_data.playlist = playlist
        else
            session_type = "playlist"
            session_data.playlist = playlist
        end
    end
    
    -- Save session state
    local session = {
        type = session_type,
        data = session_data
    }
    
    local f = io.open(last_session_file, "w")
    if f then
        f:write(utils.format_json(session))
        f:close()
        msg.debug("Saved session: " .. session_type .. " - " .. current_path)
    end
end

-- Save session whenever path changes
mp.observe_property("path", "string", function(name, val)
    if val and val ~= "" then
        -- Wait a moment for playlist to update
        mp.add_timeout(0.2, function()
            save_current_session()
        end)
    end
end)

-- Also save on shutdown as backup
mp.register_event("shutdown", function()
    save_current_session()
end)

-- Track if we've already tried to resume
local resume_attempted = false

-- Log that script is loaded
msg.info("auto-resume-last.lua loaded")

-- Function to resume the last session
local function resume_last_session()
    if resume_attempted then return end
    resume_attempted = true
    
    msg.info("Attempting to resume last session...")
    
    -- Load last session
    local f = io.open(last_session_file, "r")
    if not f then
        msg.info("No last session file found")
        return
    end
    
    local json = f:read("*all")
    f:close()
    
    if not json or json == "" then
        msg.info("Last session file is empty")
        return
    end
    
    local session = utils.parse_json(json)
    if not session or not session.type or not session.data then
        msg.warn("Invalid session data")
        return
    end
    
    local session_type = session.type
    local data = session.data
    
    -- Check if session is too old (optional: skip if older than 30 days)
    local max_age = 30 * 24 * 60 * 60 -- 30 days in seconds
    if data.timestamp and (os.time() - data.timestamp) > max_age then
        msg.info("Last session is too old, not resuming")
        return
    end
    
    msg.info("Resuming last session: " .. session_type)
    
    if session_type == "file" then
        -- Resume single file
        if data.path and data.path ~= "" then
            if utils.file_info(data.path) then
                mp.commandv("loadfile", data.path, "replace")
                msg.info("Resuming file: " .. data.path)
            else
                msg.warn("Last file no longer exists: " .. data.path)
            end
        else
            msg.warn("Last session has no valid path")
        end
        
    elseif session_type == "playlist_file" then
        -- Resume playlist file (m3u8, etc.)
        if data.path and data.path ~= "" then
            if utils.file_info(data.path) then
                mp.commandv("loadfile", data.path, "replace")
                -- Set position after a delay
                if data.position then
                    mp.add_timeout(0.8, function()
                        local count = mp.get_property_number("playlist-count", 0)
                        if data.position < count then
                            mp.set_property_number("playlist-pos", data.position)
                            msg.info("Resuming playlist at position " .. data.position)
                        end
                    end)
                end
            else
                msg.warn("Last playlist file no longer exists: " .. data.path)
            end
        end
        
    elseif session_type == "folder" then
        -- Resume folder playlist
        if data.playlist and #data.playlist > 0 then
            local loaded_count = 0
            -- Load all files from the folder playlist
            for i, item in ipairs(data.playlist) do
                local item_path = item.filename or item.path
                if item_path and utils.file_info(item_path) then
                    if i == 1 then
                        mp.commandv("loadfile", item_path, "replace")
                    else
                        mp.commandv("loadfile", item_path, "append")
                    end
                    loaded_count = loaded_count + 1
                end
            end
            
            if loaded_count > 0 then
                -- Set position after loading
                if data.position then
                    mp.add_timeout(0.8, function()
                        local count = mp.get_property_number("playlist-count", 0)
                        if data.position < count then
                            mp.set_property_number("playlist-pos", data.position)
                            msg.info("Resuming folder playlist at position " .. data.position)
                        end
                    end)
                end
            else
                msg.warn("No files from last folder session found")
            end
        end
        
    elseif session_type == "playlist" then
        -- Resume general playlist
        if data.playlist and #data.playlist > 0 then
            local loaded_count = 0
            -- Load all files from the playlist
            for i, item in ipairs(data.playlist) do
                local item_path = item.filename or item.path
                if item_path and utils.file_info(item_path) then
                    if i == 1 then
                        mp.commandv("loadfile", item_path, "replace")
                    else
                        mp.commandv("loadfile", item_path, "append")
                    end
                    loaded_count = loaded_count + 1
                end
            end
            
            if loaded_count > 0 then
                -- Set position after loading
                if data.position then
                    mp.add_timeout(0.8, function()
                        local count = mp.get_property_number("playlist-count", 0)
                        if data.position < count then
                            mp.set_property_number("playlist-pos", data.position)
                            msg.info("Resuming playlist at position " .. data.position)
                        end
                    end)
                end
            else
                msg.warn("No files from last playlist session found")
            end
        end
    end
end

-- Check if mpv started without arguments and resume
local function check_and_resume()
    if resume_attempted then return end
    
    local current_path = mp.get_property("path", "")
    local playlist_count = mp.get_property_number("playlist-count", 0)
    
    -- If there's a file loaded, don't resume
    if current_path and current_path ~= "" then
        return
    end
    
    -- If there's a playlist, don't resume
    if playlist_count > 0 then
        return
    end
    
    -- mpv started without arguments, try to resume
    resume_last_session()
end

-- Check immediately and multiple times
mp.add_timeout(0.1, check_and_resume)
mp.add_timeout(0.3, check_and_resume)
mp.add_timeout(0.6, check_and_resume)
mp.add_timeout(1.0, check_and_resume)
mp.add_timeout(1.5, check_and_resume)

-- Check when mpv becomes idle
mp.observe_property("idle-active", "bool", function(name, val)
    if val then
        mp.add_timeout(0.2, check_and_resume)
    end
end)

-- Check on start-file event
mp.register_event("start-file", function()
    mp.add_timeout(0.5, check_and_resume)
end)
