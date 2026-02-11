-- playback-history.lua
-- Persistent playback history with two columns: Local files | Online streams.
-- On empty start, shows history UI instead of auto-playing.
-- Keys: Tab = switch column, ↑↓ = select, Enter = play, Del = remove, H = hide (Esc is not used).

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local history_file
local history = {}           -- list of {path, title}; persisted, no fixed limit
local max_history_cap = 500  -- cap total entries to avoid huge file
local visible = false
local selected_column = 1    -- 1 = local, 2 = stream
local selected_index = 1
local osd_overlay_title
local osd_overlay_left
local osd_overlay_right
local startup_shown = false  -- show history once when mpv starts with no file

-- Stream URL prefixes (online)
local function is_stream_path(path)
    if not path or path == "" then return false end
    local lower = path:lower():gsub("^%s+", "")
    return lower:match("^https?://") or lower:match("^rtmp") or lower:match("^rtsp")
        or lower:match("^mms://") or lower:match("^ftp://") or lower:match("^udp://")
        or lower:match("^srt://") or lower:match("^rtsps?://")
end

local function get_history_path()
    if history_file then return history_file end
    local dir = mp.command_native({"expand-path", "~~/"})
    history_file = dir .. "/playback-history.json"
    return history_file
end

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
            if #history > max_history_cap then
                local t = {}
                for i = 1, max_history_cap do t[i] = history[i] end
                history = t
            end
        end
    end
end

local function save_history()
    local path = get_history_path()
    local f = io.open(path, "w")
    if f then
        f:write(utils.format_json(history))
        f:close()
    end
end

-- Add current file to history (avoid duplicates, put at front). Persistent, no 10 limit.
local function add_to_history(path, title)
    if not path or path == "" then return end
    title = title or path:match("[^/\\]+$") or path

    for i = #history, 1, -1 do
        if history[i] and (history[i].path == path or (history[i].path and history[i].path:gsub("\\", "/") == path:gsub("\\", "/"))) then
            table.remove(history, i)
        end
    end

    table.insert(history, 1, { path = path, title = title })
    while #history > max_history_cap do
        table.remove(history)
    end
    save_history()
end

-- Build two lists from history: local and stream
local function get_local_and_stream_lists()
    local local_list = {}
    local stream_list = {}
    for _, item in ipairs(history) do
        if not item or not item.path then goto continue end
        if is_stream_path(item.path) then
            stream_list[#stream_list + 1] = item
        else
            local_list[#local_list + 1] = item
        end
        ::continue::
    end
    return local_list, stream_list
end

-- Check if a local file still exists
local function local_file_exists(path)
    if not path or is_stream_path(path) then return true end
    return utils.file_info(path) ~= nil
end

local function truncate_display(str, max_len)
    if #str <= max_len then return str end
    return str:sub(1, max_len - 3) .. "..."
end

-- Build OSD: two separate overlays for left and right columns so \pos is respected and columns don't stick.
-- Each overlay has one column only, so every line's \pos is applied correctly.
local function build_osd()
    if not osd_overlay_title then
        osd_overlay_title = mp.create_osd_overlay("ass-events")
        osd_overlay_left = mp.create_osd_overlay("ass-events")
        osd_overlay_right = mp.create_osd_overlay("ass-events")
    end

    local line_height = 28
    local font_size = 20
    local margin_x = 64
    local margin_y = 80
    local col1_width = 440
    local col_gap = 180
    local col2_x = margin_x + col1_width + col_gap
    local max_name_len = 48

    local local_list, stream_list = get_local_and_stream_lists()

    -- One block per line: {\an7\pos(x,y)\fn...\fsN\c&H...&}Text
    local function line(x, y, fs, bold, color, text)
        local b = (bold and "\\b1" or "\\b0")
        return string.format("{\\an7\\pos(%d,%d)\\fnConsolas\\fs%d%s\\c&H%s&}%s\\N", x, y, fs, b, color, text)
    end

    local function line_strike(x, y, fs, bold, color, text)
        local b = (bold and "\\b1" or "\\b0")
        return string.format("{\\an7\\pos(%d,%d)\\fnConsolas\\fs%d%s\\s1\\c&H%s&}%s\\N", x, y, fs, b, color, text)
    end

    local y = margin_y

    -- Title overlay: one line so \pos works
    local title_ass = line(margin_x, y, font_size, true, "FFFFFF", "Playback history")
    title_ass = title_ass .. line(margin_x + 240, y, font_size - 4, false, "888888", "Tab: switch  ↑↓: select  Enter: play  Del: remove  H: close")
    y = y + line_height * 2

    -- Left column overlay: header, separator, then rows (each line has \pos(margin_x, y))
    local left_ass = line(margin_x, y, font_size - 2, true, "E0E0E0", "Local files")
    y = y + line_height
    local sep = string.rep("-", 50)
    left_ass = left_ass .. line(margin_x, y, font_size - 4, false, "505050", sep)
    y = y + line_height

    local max_rows = math.max(#local_list, #stream_list)
    if max_rows == 0 then
        left_ass = left_ass .. line(margin_x, y, font_size - 2, false, "808080", "(none)")
    end
    for row = 1, max_rows do
        local local_item = local_list[row]
        local local_text = "(empty)"
        local local_color = "FFFFFF"
        local local_bold = false
        local local_strike = false
        if local_item then
            local_text = truncate_display(local_item.title or local_item.path or "?", max_name_len)
            local exists = local_file_exists(local_item.path)
            local is_sel = (visible and selected_column == 1 and selected_index == row)
            if not exists then
                local_color = is_sel and "00D4FF" or "606060"
                local_strike = true
            else
                local_color = is_sel and "00D4FF" or "FFFFFF"
                local_bold = is_sel
            end
        end
        if local_strike then
            left_ass = left_ass .. line_strike(margin_x, y, font_size - 2, local_bold, local_color, local_text)
        else
            left_ass = left_ass .. line(margin_x, y, font_size - 2, local_bold, local_color, local_text)
        end
        y = y + line_height
    end

    -- Right column overlay: same y positions as left, \pos(col2_x, ...)
    local y_right = margin_y + line_height * 2
    local right_ass = line(col2_x, y_right, font_size - 2, true, "E0E0E0", "Online streams")
    y_right = y_right + line_height
    right_ass = right_ass .. line(col2_x, y_right, font_size - 4, false, "505050", sep)
    y_right = y_right + line_height

    if max_rows == 0 then
        right_ass = right_ass .. line(col2_x, y_right, font_size - 2, false, "808080", "(none)")
    end
    for row = 1, max_rows do
        local stream_item = stream_list[row]
        local stream_text = "(empty)"
        local stream_color = "FFFFFF"
        local stream_bold = false
        if stream_item then
            stream_text = truncate_display(stream_item.title or stream_item.path or "?", max_name_len)
            local is_sel = (visible and selected_column == 2 and selected_index == row)
            stream_color = is_sel and "00D4FF" or "FFFFFF"
            stream_bold = is_sel
        end
        right_ass = right_ass .. line(col2_x, y_right, font_size - 2, stream_bold, stream_color, stream_text)
        y_right = y_right + line_height
    end

    osd_overlay_title.data = title_ass
    osd_overlay_title:update()
    osd_overlay_left.data = left_ass
    osd_overlay_left:update()
    osd_overlay_right.data = right_ass
    osd_overlay_right:update()
end

local function show_history()
    load_history()
    visible = true
    local local_list, stream_list = get_local_and_stream_lists()
    selected_column = 1
    selected_index = 1
    if #local_list == 0 and #stream_list > 0 then
        selected_column = 2
    end
    build_osd()
end

local function hide_history()
    visible = false
    if osd_overlay_title then osd_overlay_title:remove() end
    if osd_overlay_left then osd_overlay_left:remove() end
    if osd_overlay_right then osd_overlay_right:remove() end
end

local function toggle_history()
    if visible then
        hide_history()
    else
        show_history()
    end
end

-- Get the currently selected item (path, title)
local function get_selected_item()
    local local_list, stream_list = get_local_and_stream_lists()
    local list = (selected_column == 1) and local_list or stream_list
    if selected_index < 1 or selected_index > #list then return nil end
    return list[selected_index]
end

-- Play selected item (works for both local and stream; for local missing file we still try)
local function play_history_item()
    local item = get_selected_item()
    if not item or not item.path then return end
    local is_stream = is_stream_path(item.path)
    if not is_stream and not local_file_exists(item.path) then
        msg.warn("File no longer exists: " .. item.path)
        -- Still try loadfile in case path is valid again (e.g. reconnected drive)
    end
    hide_history()
    mp.commandv("loadfile", item.path, "replace")
    msg.info("Playing: " .. (item.title or item.path))
end

-- Remove selected item from history
local function remove_selected_from_history()
    local item = get_selected_item()
    if not item or not item.path then return end
    local path_to_remove = item.path
    for i = #history, 1, -1 do
        local p = history[i] and history[i].path
        if p and (p == path_to_remove or p:gsub("\\", "/") == path_to_remove:gsub("\\", "/")) then
            table.remove(history, i)
            break
        end
    end
    save_history()
    local local_list, stream_list = get_local_and_stream_lists()
    local list = (selected_column == 1) and local_list or stream_list
    if selected_index > #list then
        selected_index = math.max(1, #list)
    end
    if #list == 0 then
        selected_column = (selected_column == 1) and 2 or 1
        selected_index = 1
    end
    build_osd()
    msg.info("Removed from history")
end

local function move_selection(delta)
    if not visible then return end
    local local_list, stream_list = get_local_and_stream_lists()
    local list = (selected_column == 1) and local_list or stream_list
    if #list == 0 then return end
    selected_index = selected_index + delta
    if selected_index < 1 then selected_index = 1 end
    if selected_index > #list then selected_index = #list end
    build_osd()
end

local function switch_column()
    if not visible then return end
    local local_list, stream_list = get_local_and_stream_lists()
    selected_column = (selected_column == 1) and 2 or 1
    local list = (selected_column == 1) and local_list or stream_list
    selected_index = math.min(selected_index, math.max(1, #list))
    build_osd()
end

-- Key bindings when overlay is visible
local function add_overlay_keys()
    mp.add_forced_key_binding("TAB", "history_tab", function()
        if visible then switch_column() end
    end)
    mp.add_forced_key_binding("UP", "history_up", function()
        if visible then move_selection(-1) end
    end)
    mp.add_forced_key_binding("DOWN", "history_down", function()
        if visible then move_selection(1) end
    end)
    mp.add_forced_key_binding("ENTER", "history_enter", function()
        if visible then play_history_item() end
    end)
    mp.add_forced_key_binding("KP_ENTER", "history_enter_kp", function()
        if visible then play_history_item() end
    end)
    mp.add_forced_key_binding("DEL", "history_remove", function()
        if visible then remove_selected_from_history() end
    end)
    mp.add_forced_key_binding("BS", "history_remove_bs", function()
        if visible then remove_selected_from_history() end
    end)
    -- Esc is not bound; only H toggles history
end

local function remove_overlay_keys()
    mp.remove_key_binding("history_tab")
    mp.remove_key_binding("history_up")
    mp.remove_key_binding("history_down")
    mp.remove_key_binding("history_enter")
    mp.remove_key_binding("history_enter_kp")
    mp.remove_key_binding("history_remove")
    mp.remove_key_binding("history_remove_bs")
end

local function toggle_history_safe()
    if visible then
        hide_history()
        remove_overlay_keys()
    else
        show_history()
        add_overlay_keys()
    end
end

local function setup_bindings()
    mp.add_forced_key_binding("h", "history_toggle", toggle_history_safe)
end

-- Show history when mpv starts with no file (empty screen)
local function maybe_show_history_on_startup()
    if startup_shown then return end
    local path = mp.get_property("path", "")
    local idle = mp.get_property_native("idle-active", false)
    if (not path or path == "") and idle then
        startup_shown = true
        show_history()
        add_overlay_keys()
    end
end

-- Add current file to history on file load
mp.register_event("file-loaded", function()
    local path = mp.get_property("path", "")
    local title = mp.get_property("media-title", "")
    if path and path ~= "" then
        add_to_history(path, title ~= "" and title or nil)
        -- Hide history overlay when a file/stream is loaded
        if visible then
            hide_history()
            remove_overlay_keys()
        end
    end
end)

-- Init
load_history()
setup_bindings()

-- When started without a file, show history after a short delay
mp.add_timeout(0.5, maybe_show_history_on_startup)
mp.add_timeout(1.0, maybe_show_history_on_startup)
mp.observe_property("idle-active", "bool", function(_, val)
    if val then mp.add_timeout(0.3, maybe_show_history_on_startup) end
end)

msg.info("Playback history: persistent, two columns (Local | Online). Press 'h' to toggle. Tab/↑↓/Enter/Del.")
