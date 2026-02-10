-- auto_resume_playlist.lua
-- Remembers the last played episode in playlist files (m3u8, etc.) and resumes from there

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local resume_dir = mp.command_native({"expand-path", "~~/"})
local playlist_state_file = resume_dir .. "/playlist-state.json"

-- Function to normalize path for comparison (Windows compatible)
local function normalize_path(path)
    if not path then return nil end
    -- Convert to lowercase and normalize separators
    return path:gsub("\\", "/"):lower()
end

-- Function to get the playlist source file path
local function get_playlist_source()
    local path = mp.get_property("path", "")
    if path:match("%.m3u8?$") or path:match("%.pls$") or path:match("%.cue$") then
        return path
    end
    -- Check if current file is part of a playlist loaded from a file
    local playlist_count = mp.get_property_number("playlist-count", 0)
    if playlist_count > 1 then
        -- This might be a playlist, try to get the source
        return path
    end
    return nil
end

-- Save playlist state (source file, current position, and all items)
mp.register_event("shutdown", function()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    if playlist_count == 0 then return end
    
    local current_path = mp.get_property("path", "")
    local playlist_pos = mp.get_property_number("playlist-pos", 0)
    local playlist = mp.get_property_native("playlist", {})
    
    -- Check if this is a playlist file (m3u8, etc.)
    local playlist_source = get_playlist_source()
    
    if playlist_source or playlist_count > 1 then
        local state = {
            source = playlist_source or current_path,
            position = playlist_pos,
            playlist = playlist,
            timestamp = os.time()
        }
        
        local f = io.open(playlist_state_file, "w")
        if f then
            f:write(utils.format_json(state))
            f:close()
            msg.info("Saved playlist state: position " .. playlist_pos .. " in " .. (playlist_source or "playlist"))
        end
    end
end)

-- Load and restore playlist state when opening a playlist file
mp.register_event("file-loaded", function()
    local current_path = mp.get_property("path", "")
    if not current_path then return end
    
    -- Check if this is a playlist file
    local is_playlist_file = current_path:match("%.m3u8?$") or 
                            current_path:match("%.pls$") or 
                            current_path:match("%.cue$")
    
    -- Also check if we have multiple items in playlist (loaded playlist)
    local playlist_count = mp.get_property_number("playlist-count", 0)
    
    if is_playlist_file or playlist_count > 1 then
        -- Wait a bit for playlist to fully load
        mp.add_timeout(0.5, function()
            local f = io.open(playlist_state_file, "r")
            if not f then return end
            
            local json = f:read("*all")
            f:close()
            
            if not json or json == "" then return end
            
            local state = utils.parse_json(json)
            if not state or not state.source then return end
            
            -- Check if this is the same playlist source
            local saved_source_normalized = normalize_path(state.source)
            local current_normalized = normalize_path(current_path)
            
            -- Match if paths are the same or if current path matches the saved source
            local matches = (saved_source_normalized == current_normalized) or
                           (playlist_count > 1 and state.playlist and #state.playlist > 0)
            
            if matches and state.position and state.position >= 0 then
                local target_pos = state.position
                local actual_count = mp.get_property_number("playlist-count", 0)
                
                -- Ensure position is valid
                if target_pos < actual_count then
                    mp.set_property_number("playlist-pos", target_pos)
                    msg.info("Resuming playlist from position " .. target_pos)
                    
                    -- Also ensure watch-later is enabled for the resumed item
                    mp.add_timeout(0.2, function()
                        mp.command("write-watch-later-config")
                    end)
                end
            end
        end)
    end
end)
