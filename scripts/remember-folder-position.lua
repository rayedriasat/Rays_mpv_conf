-- remember-folder-position.lua
-- Remembers the last played file position when opening the same folder
-- Works together with mpv's watch-later feature to resume playback

local utils = require 'mp.utils'

local resume_dir = mp.command_native({"expand-path", "~~/"})
local folder_state_file = resume_dir .. "/folder-positions.json"

-- Function to get folder path from file path
local function get_folder_path(file_path)
    if not file_path then return nil end
    local dir, _ = utils.split_path(file_path)
    return dir
end

-- Function to normalize path for comparison
local function normalize_path(path)
    if not path then return nil end
    return path:gsub("\\", "/"):lower()
end

-- Load folder positions
local folder_positions = {}
local function load_folder_positions()
    local f = io.open(folder_state_file, "r")
    if f then
        local json = f:read("*all")
        f:close()
        if json and json ~= "" then
            folder_positions = utils.parse_json(json) or {}
        end
    end
end

-- Save folder positions
local function save_folder_positions()
    local f = io.open(folder_state_file, "w")
    if f then
        f:write(utils.format_json(folder_positions))
        f:close()
    end
end

-- Initialize: load saved positions
load_folder_positions()

-- Track when we're playing from a folder (playlist with multiple items from same directory)
local is_folder_playlist = false
local current_folder = nil

-- Detect if we're playing a folder-based playlist
mp.register_event("file-loaded", function()
    local playlist_count = mp.get_property_number("playlist-count", 0)
    local current_path = mp.get_property("path", "")
    
    if playlist_count > 1 and current_path then
        local folder = normalize_path(get_folder_path(current_path))
        -- Check if all items in playlist are from the same folder
        local playlist = mp.get_property_native("playlist", {})
        local all_same_folder = true
        for _, item in ipairs(playlist) do
            local item_folder = normalize_path(get_folder_path(item.filename or item.path))
            if item_folder ~= folder then
                all_same_folder = false
                break
            end
        end
        
        if all_same_folder then
            is_folder_playlist = true
            current_folder = folder
            
            -- Check if we have a saved position for this folder
            local saved_file = folder_positions[folder]
            if saved_file then
                -- Find the saved file in the current playlist
                for i, item in ipairs(playlist) do
                    local item_path = normalize_path(item.filename or item.path)
                    if item_path == normalize_path(saved_file) then
                        -- Switch to the saved file position
                        mp.add_timeout(0.3, function()
                            mp.set_property_number("playlist-pos", i - 1)
                            mp.msg.info("Resuming from last played file in folder")
                        end)
                        break
                    end
                end
            end
        else
            is_folder_playlist = false
            current_folder = nil
        end
    else
        is_folder_playlist = false
        current_folder = nil
    end
end)

-- Save current file when it changes (only for folder playlists)
local last_path = nil
mp.observe_property("path", "string", function(name, val)
    if val and val ~= "" and val ~= last_path and is_folder_playlist and current_folder then
        last_path = val
        folder_positions[current_folder] = val
        save_folder_positions()
    end
end)
