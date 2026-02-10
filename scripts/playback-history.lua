-- playback-history.lua
-- Press "h" to toggle a list of last 10 played files. Press 1-9, 0 to play, or Arrow keys + Enter.

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local history_file
local history = {}          -- list of {path, title} for last 10 items
local max_history = 10
local visible = false
local selected_index = 1     -- 1-based, for arrow key selection
local osd_overlay

-- Resolve config path
local function get_history_path()
    if history_file then return history_file end
    local dir = mp.command_native({"expand-path", "~~/"})
    history_file = dir .. "/playback-history.json"
    return history_file
end

-- Load history from file
local function load_history()
    local path = get_history_path()
    local f = io.open(path, "r")
    if not f then return end
    local json = f:read("*all")
    f:close()
    if json and json ~= "" then
        local ok, data = pcall(function() return utils.parse_json(json) end)
        if ok and data and type(data) == "table" then
            history = data
            if #history > max_history then
                local t = {}
                for i = 1, max_history do t[i] = history[i] end
                history = t
            end
        end
    end
end

-- Save history to file
local function save_history()
    local path = get_history_path()
    local f = io.open(path, "w")
    if f then
        f:write(utils.format_json(history))
        f:close()
    end
end

-- Add current file to history (avoid duplicates, put at front)
local function add_to_history(path, title)
    if not path or path == "" then return end
    title = title or path:match("[^/\\]+$") or path

    for i = #history, 1, -1 do
        if history[i] and (history[i].path == path or (history[i].path and history[i].path:gsub("\\", "/") == path:gsub("\\", "/"))) then
            table.remove(history, i)
        end
    end

    table.insert(history, 1, { path = path, title = title })
    while #history > max_history do
        table.remove(history)
    end
    save_history()
end

-- Build OSD content (ASS)
local function build_osd()
    if not osd_overlay then
        osd_overlay = mp.create_osd_overlay("ass-events")
    end

    local line_height = 28
    local font_size = 22
    local margin_x = 50
    local margin_y = 80
    local w, h = mp.get_osd_size()

    local ass = string.format(
        "{\\an7\\pos(%d,%d)\\fnConsolas\\fs%d\\b1}Playback history (1–0 play, ↑↓ select, Enter play, H/Esc hide)\\N\\N",
        margin_x, margin_y, font_size - 2
    )

    for i = 1, max_history do
        local item = history[i]
        local text = item and (item.title or item.path or "?") or "(empty)"
        if #text > 70 then
            text = text:sub(1, 67) .. "..."
        end
        local num = i == 10 and "0" or tostring(i)
        local prefix = string.format("[%s] ", num)
        local line
        if i == selected_index and visible then
            line = string.format("{\\b1\\c&H00FFFF&}%s%s{\\b0\\c&HFFFFFF&}\\N", prefix, text)
        else
            line = string.format("%s%s\\N", prefix, text)
        end
        ass = ass .. line
    end

    osd_overlay.data = ass
    osd_overlay:update()
end

-- Show overlay
local function show_history()
    load_history()
    visible = true
    selected_index = 1
    build_osd()
end

-- Hide overlay
local function hide_history()
    visible = false
    if osd_overlay then
        osd_overlay:remove()
    end
end

-- Toggle visibility
local function toggle_history()
    if visible then
        hide_history()
    else
        show_history()
    end
end

-- Play item by index (1–10)
local function play_history_item(index)
    if index < 1 or index > max_history then return end
    local item = history[index]
    if not item or not item.path then return end
    if not utils.file_info(item.path) then
        msg.warn("File no longer exists: " .. item.path)
        return
    end
    hide_history()
    mp.commandv("loadfile", item.path, "replace")
    msg.info("Playing: " .. (item.title or item.path))
end

-- Move selection
local function move_selection(delta)
    if not visible or #history == 0 then return end
    selected_index = selected_index + delta
    if selected_index < 1 then selected_index = 1 end
    if selected_index > math.min(#history, max_history) then
        selected_index = math.min(#history, max_history)
    end
    build_osd()
end

-- Key bindings when overlay is visible
local function bind_history_keys()
    mp.add_forced_key_binding("h", "history_toggle", toggle_history)
    mp.add_forced_key_binding("ESC", "history_hide", function()
        if visible then hide_history() end
    end)
    for i = 1, 9 do
        mp.add_forced_key_binding(tostring(i), "history_play_" .. i, function()
            if visible then play_history_item(i) else mp.get_property("path") end
        end)
    end
    mp.add_forced_key_binding("0", "history_play_10", function()
        if visible then play_history_item(10) end
    end)
    mp.add_forced_key_binding("UP", "history_up", function()
        if visible then move_selection(-1) end
    end)
    mp.add_forced_key_binding("DOWN", "history_down", function()
        if visible then move_selection(1) end
    end)
    mp.add_forced_key_binding("ENTER", "history_enter", function()
        if visible then play_history_item(selected_index) end
    end)
end

-- Unbind number keys when overlay is hidden (so they don't conflict with default mpv)
-- We use forced key bindings that only act when visible, so we need to make 1-9,0 not do default when overlay is shown.
-- Actually in mpv, add_forced_key_binding will override default. So when we press "1" and overlay is visible we play item 1; when overlay is hidden, "1" might still be bound and do nothing. We need to only bind 1-0 when visible, or make the binding check visibility.
-- So: keep one binding for "h" (toggle). For 1-0, we need to either always override and in the handler check visible and if not visible don't do anything (and let the key fall through? No - in mpv the key is consumed). So when overlay is hidden, 1-0 would be bound to a function that does nothing. That would break default mpv behavior (e.g. chapter skip).
-- Better: when showing overlay, add key bindings for 1-0 and arrows and Enter; when hiding, remove those bindings. So we need to add/remove bindings on toggle.
local function add_overlay_keys()
    for i = 1, 10 do
        local key = i == 10 and "0" or tostring(i)
        local idx = i
        mp.add_forced_key_binding(key, "history_play_" .. key, function()
            if visible then play_history_item(idx) end
        end)
    end
    mp.add_forced_key_binding("UP", "history_up", function()
        if visible then move_selection(-1) end
    end)
    mp.add_forced_key_binding("DOWN", "history_down", function()
        if visible then move_selection(1) end
    end)
    mp.add_forced_key_binding("ENTER", "history_enter", function()
        if visible then play_history_item(selected_index) end
    end)
    mp.add_forced_key_binding("ESC", "history_hide", function()
        if visible then hide_history() end
    end)
end

local function remove_overlay_keys()
    for i = 1, 10 do
        local key = i == 10 and "0" or tostring(i)
        mp.remove_key_binding("history_play_" .. key)
    end
    mp.remove_key_binding("history_up")
    mp.remove_key_binding("history_down")
    mp.remove_key_binding("history_enter")
    mp.remove_key_binding("history_hide")
end

-- Wrap toggle to add/remove overlay-specific keys
local function toggle_history_safe()
    if visible then
        hide_history()
        remove_overlay_keys()
    else
        show_history()
        add_overlay_keys()
    end
end

-- Replace toggle with the safe version
local function setup_bindings()
    mp.add_forced_key_binding("h", "history_toggle", toggle_history_safe)
end

-- Add current file to history on file load
mp.register_event("file-loaded", function()
    local path = mp.get_property("path", "")
    local title = mp.get_property("media-title", "")
    if path and path ~= "" then
        add_to_history(path, title ~= "" and title or nil)
    end
end)

-- Init
load_history()
setup_bindings()
msg.info("Playback history: press 'h' to show last 10 files, 1–0 to play, ↑↓ + Enter to select")
