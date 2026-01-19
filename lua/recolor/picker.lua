-- Floating window picker for recolor
-- Navigate highlight groups and adjust colors interactively
-- Supports curated list, cursor inspection, and browse all modes

local colors = require 'recolor.colors'
local groups = require 'recolor.groups'
local persistence = require 'recolor.persistence'

local M = {}

-- State
local state = {
  bufnr = nil,
  winid = nil,
  preview_bufnr = nil,
  preview_winid = nil,
  flat_list = nil,
  selected = 1,
  mode = 'categories', -- 'categories', 'cursor', 'browse', or 'edited'
  preview_context = nil,
  -- Browse mode specific
  search_query = '',
  all_groups = nil,
  total_count = 0,
  -- Multi-channel support (per-group)
  group_channels = {}, -- maps group name -> active channel
}

-- Config
local config = {
  width = 75,
  height = 25,
  preview_width = 50,
  name_width = 26, -- width for group name column
  -- Browse mode gets wider window and name column
  browse_width = 100,
  browse_name_width = 46,
  brightness_step = 0.05,
  hue_step = 10,
  saturation_step = 0.05,
}

--- Get the active channel for a group, initializing if needed
---@param group_name string
---@return string Active channel ('fg', 'bg', or 'sp')
local function get_group_channel(group_name)
  if state.group_channels[group_name] then
    return state.group_channels[group_name]
  end
  -- Initialize to first available channel
  local available = groups.get_available_channels(group_name)
  local channel = available[1] or 'fg'
  state.group_channels[group_name] = channel
  return channel
end

--- Format channels display for a group
--- Shows only channels that have colors, with active one bracketed: [fg]#aabbcc█  bg #ddeeff█
---@param group_name string
---@return string Formatted channel display
---@return table Color positions for highlighting: {{offset, color}, ...}
local function format_channels(group_name)
  local all_colors = groups.get_all_colors(group_name)
  local active_channel = get_group_channel(group_name)
  local parts = {}
  local color_positions = {}
  local current_offset = 0

  for _, ch in ipairs { 'fg', 'bg', 'sp' } do
    local color = all_colors[ch]
    if color then
      local part
      if ch == active_channel then
        -- Selected: [fg]#aabbcc█ (4 chars before #)
        part = '[' .. ch .. ']' .. color .. '█'
      else
        -- Not selected:  fg #aabbcc█ (4 chars before #)
        part = ' ' .. ch .. ' ' .. color .. '█'
      end
      table.insert(parts, part)

      -- Calculate position of the █ character (at end of this part, before space)
      local square_offset = current_offset + #part - 3 -- █ is 3 bytes in UTF-8
      table.insert(color_positions, { offset = square_offset, color = color })

      current_offset = current_offset + #part + 1 -- +1 for space separator
    end
  end

  if #parts == 0 then
    return '(none)', {}
  end

  return table.concat(parts, ' '), color_positions
end

--- Cycle to next available channel for current group
local function cycle_channel(reverse)
  local group_name = nil
  if state.flat_list and state.flat_list[state.selected] then
    local item = state.flat_list[state.selected]
    group_name = item.group and item.group.name or item.name
  end

  if not group_name then return end

  local available = groups.get_available_channels(group_name)
  if #available <= 1 then return end -- No point cycling with 0 or 1 channel

  local current_channel = get_group_channel(group_name)

  -- Find current channel index
  local current_idx = 1
  for i, ch in ipairs(available) do
    if ch == current_channel then
      current_idx = i
      break
    end
  end

  -- Cycle to next/prev
  if reverse then
    current_idx = current_idx - 1
    if current_idx < 1 then current_idx = #available end
  else
    current_idx = current_idx + 1
    if current_idx > #available then current_idx = 1 end
  end

  state.group_channels[group_name] = available[current_idx]
  vim.notify(group_name .. ' channel: ' .. available[current_idx], vim.log.levels.INFO)
end

--- Render the picker content for categories mode
local function render_categories()
  local lines = {}
  local highlights = {}
  local selection_line = nil

  -- Help text at top (always visible)
  table.insert(lines, ' j/k:move  ,/.:hue  [/]:bright  {/}:sat')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, ' Tab:channel  y:copy  p:paste  u:undo  #:pick  q:quit')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, '')

  local flat_idx = 1
  for _, category in ipairs(groups.categories) do
    -- Category header
    table.insert(lines, ' ' .. category.name)
    table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Title' })

    -- Groups in category
    for _, group in ipairs(category.groups) do
      local channels_str, color_positions = format_channels(group.name)
      local prefix = flat_idx == state.selected and ' > ' or '   '
      local indicator = persistence.is_group_tweaked(group.name) and '•' or ' '
      local fmt = '%s%s%-' .. config.name_width .. 's %s'
      local line = string.format(fmt, prefix, indicator, group.name, channels_str)
      table.insert(lines, line)

      if flat_idx == state.selected then
        selection_line = #lines
        table.insert(highlights, { line = #lines, col = 0, end_col = #line, hl = 'CursorLine' })
      end

      -- Add color preview highlights for squares
      -- prefix (3) + indicator (1 char but • is 3 bytes) + group name field + space (1)
      local indicator_len = persistence.is_group_tweaked(group.name) and 3 or 1
      local base_col = 3 + indicator_len + config.name_width + 1
      for i, pos in ipairs(color_positions) do
        local hl_name = 'RecolorPreview' .. flat_idx .. '_' .. i
        vim.api.nvim_set_hl(0, hl_name, { fg = pos.color })
        table.insert(highlights, { line = #lines, col = base_col + pos.offset, end_col = base_col + pos.offset + 3, hl = hl_name })
      end

      flat_idx = flat_idx + 1
    end

    table.insert(lines, '')
  end

  return lines, highlights, selection_line
end

--- Render the picker content for cursor mode (flat list)
local function render_cursor()
  local lines = {}
  local highlights = {}
  local selection_line = nil

  -- Help text at top (always visible)
  table.insert(lines, ' j/k:move  ,/.:hue  [/]:bright  {/}:sat')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, ' Tab:channel  y:copy  p:paste  u:undo  #:pick  q:quit')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, '')

  table.insert(lines, ' Groups at cursor')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Title' })
  table.insert(lines, '')

  for idx, item in ipairs(state.flat_list) do
    local channels_str, color_positions = format_channels(item.name)
    local prefix = idx == state.selected and ' > ' or '   '
    local indicator = persistence.is_group_tweaked(item.name) and '•' or ' '
    local fmt = '%s%s%-' .. config.name_width .. 's %s'
    local line = string.format(fmt, prefix, indicator, item.name, channels_str)
    table.insert(lines, line)

    if idx == state.selected then
      selection_line = #lines
      table.insert(highlights, { line = #lines, col = 0, end_col = #line, hl = 'CursorLine' })
    end

    -- Add color preview highlights for squares
    -- prefix (3) + indicator (1 char but • is 3 bytes) + group name field + space (1)
    local indicator_len = persistence.is_group_tweaked(item.name) and 3 or 1
    local base_col = 3 + indicator_len + config.name_width + 1
    for i, pos in ipairs(color_positions) do
      local hl_name = 'RecolorCursor' .. idx .. '_' .. i
      vim.api.nvim_set_hl(0, hl_name, { fg = pos.color })
      table.insert(highlights, { line = #lines, col = base_col + pos.offset, end_col = base_col + pos.offset + 3, hl = hl_name })
    end
  end

  return lines, highlights, selection_line
end

--- Render the picker content for browse mode (with search)
local function render_browse()
  local lines = {}
  local highlights = {}
  local selection_line = nil

  -- Search input line (type to filter)
  local search_display = state.search_query == '' and '(type to filter)' or state.search_query
  table.insert(lines, ' Search: ' .. search_display .. '_')
  table.insert(highlights, { line = #lines, col = 0, end_col = 9, hl = 'Title' })
  if state.search_query ~= '' then
    table.insert(highlights, { line = #lines, col = 9, end_col = 9 + #state.search_query, hl = 'String' })
  end

  -- Separator
  table.insert(lines, ' ' .. string.rep('-', config.browse_width - 4))
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })

  -- Groups list
  local max_display = config.height - 7 -- Reserve space for header, separator, footer (2 help lines)
  local total_items = #state.flat_list

  -- Calculate scroll offset to keep selection visible
  local scroll_offset = 0
  if state.selected > max_display then
    scroll_offset = state.selected - max_display
  end

  local start_idx = scroll_offset + 1
  local end_idx = math.min(scroll_offset + max_display, total_items)

  for idx = start_idx, end_idx do
    local item = state.flat_list[idx]

    local prefix = idx == state.selected and ' > ' or '   '
    local indicator = persistence.is_group_tweaked(item.name) and '•' or ' '
    local line
    local color_positions = {}
    local fmt = '%s%s%-' .. config.browse_name_width .. 's %s'

    if item.is_link then
      line = string.format(fmt, prefix, indicator, item.name, '-> ' .. (item.link_target or '?'))
    else
      local channels_str
      channels_str, color_positions = format_channels(item.name)
      line = string.format(fmt, prefix, indicator, item.name, channels_str)
    end

    table.insert(lines, line)

    if idx == state.selected then
      selection_line = #lines
      table.insert(highlights, { line = #lines, col = 0, end_col = #line, hl = 'CursorLine' })
    end

    -- Add color preview highlights for squares
    -- prefix (3) + indicator (1 char but • is 3 bytes) + group name field + space (1)
    local indicator_len = persistence.is_group_tweaked(item.name) and 3 or 1
    local base_col = 3 + indicator_len + config.browse_name_width + 1
    for i, pos in ipairs(color_positions) do
      local hl_name = 'RecolorBrowse' .. idx .. '_' .. i
      vim.api.nvim_set_hl(0, hl_name, { fg = pos.color })
      table.insert(highlights, { line = #lines, col = base_col + pos.offset, end_col = base_col + pos.offset + 3, hl = hl_name })
    end
  end

  -- Footer with count
  table.insert(lines, '')
  local count_msg
  if total_items == state.total_count then
    count_msg = string.format(' %d-%d of %d groups', start_idx, end_idx, total_items)
  else
    count_msg = string.format(' %d-%d of %d (filtered from %d)', start_idx, end_idx, total_items, state.total_count)
  end
  table.insert(lines, count_msg)
  table.insert(highlights, { line = #lines, col = 0, end_col = #count_msg, hl = 'Comment' })

  table.insert(lines, ' C-j/k:move  ,/.:hue  [/]:bright  {/}:sat  C-c:clear')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, ' Tab:channel  C-y:copy  C-p:paste  C-u:undo  #:pick  Esc:quit')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })

  return lines, highlights, selection_line
end

--- Render the picker content for edited mode (tweaked groups only)
local function render_edited()
  local lines = {}
  local highlights = {}
  local selection_line = nil

  -- Help text at top (always visible)
  local scheme = persistence.get_colorscheme()
  table.insert(lines, ' Edited Colors (' .. scheme .. ')')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Title' })
  table.insert(lines, '')
  table.insert(lines, ' j/k:move  ,/.:hue  [/]:bright  {/}:sat')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, ' Tab:channel  y:copy  p:paste  u:undo  U:undo all  #:pick  q:quit')
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })
  table.insert(lines, '')

  for idx, item in ipairs(state.flat_list) do
    local channels_str, color_positions = format_channels(item.name)
    local prefix = idx == state.selected and ' > ' or '   '
    -- All items in edited view are tweaked, so always show •
    local fmt = '%s•%-' .. config.name_width .. 's %s'
    local line = string.format(fmt, prefix, item.name, channels_str)
    table.insert(lines, line)

    if idx == state.selected then
      selection_line = #lines
      table.insert(highlights, { line = #lines, col = 0, end_col = #line, hl = 'CursorLine' })
    end

    -- Add color preview highlights for squares
    -- prefix (3) + indicator (• is 3 bytes) + group name field + space (1)
    local base_col = 3 + 3 + config.name_width + 1
    for i, pos in ipairs(color_positions) do
      local hl_name = 'RecolorEdited' .. idx .. '_' .. i
      vim.api.nvim_set_hl(0, hl_name, { fg = pos.color })
      table.insert(highlights, { line = #lines, col = base_col + pos.offset, end_col = base_col + pos.offset + 3, hl = hl_name })
    end
  end

  -- Footer with count
  table.insert(lines, '')
  table.insert(lines, string.format(' %d tweaked groups', #state.flat_list))
  table.insert(highlights, { line = #lines, col = 0, end_col = #lines[#lines], hl = 'Comment' })

  return lines, highlights, selection_line
end

--- Render the picker content
local function render()
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  local lines, highlights, selection_line
  if state.mode == 'categories' then
    lines, highlights, selection_line = render_categories()
  elseif state.mode == 'browse' then
    lines, highlights, selection_line = render_browse()
  elseif state.mode == 'edited' then
    lines, highlights, selection_line = render_edited()
  else
    lines, highlights, selection_line = render_cursor()
  end

  -- Set buffer content
  vim.api.nvim_set_option_value('modifiable', true, { buf = state.bufnr })
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = state.bufnr })

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace 'recolor_picker'
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.bufnr, ns, hl.hl, hl.line - 1, hl.col, hl.end_col)
  end

  -- Move cursor to selection
  if selection_line and state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_set_cursor(state.winid, { selection_line, 0 })
  end
end

--- Render the preview window content
local function render_preview()
  if not state.preview_bufnr or not vim.api.nvim_buf_is_valid(state.preview_bufnr) then
    return
  end
  if not state.preview_context then
    return
  end

  local ctx = state.preview_context
  local lines = {}

  -- Add header
  table.insert(lines, ' Preview')
  table.insert(lines, '')

  -- Add source lines with line numbers
  for i, line in ipairs(ctx.lines) do
    local line_num = ctx.start_line + i
    local prefix = (i == ctx.cursor_line_in_preview) and '>' or ' '
    local formatted = string.format('%s%3d: %s', prefix, line_num, line)
    table.insert(lines, formatted)
  end

  -- Add cursor indicator
  table.insert(lines, '')
  local cursor_col = ctx.col + 6 -- account for prefix and line number
  local indicator = string.rep(' ', cursor_col) .. '^'
  table.insert(lines, indicator)

  -- Set buffer content
  vim.api.nvim_set_option_value('modifiable', true, { buf = state.preview_bufnr })
  vim.api.nvim_buf_set_lines(state.preview_bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = state.preview_bufnr })

  -- Apply syntax highlighting if we know the filetype
  if ctx.filetype and ctx.filetype ~= '' then
    vim.api.nvim_set_option_value('filetype', ctx.filetype, { buf = state.preview_bufnr })
  end

  -- Highlight header
  local ns = vim.api.nvim_create_namespace 'recolor_preview'
  vim.api.nvim_buf_clear_namespace(state.preview_bufnr, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(state.preview_bufnr, ns, 'Title', 0, 0, -1)

  -- Highlight cursor line indicator
  if ctx.cursor_line_in_preview then
    local cursor_line_idx = ctx.cursor_line_in_preview + 1 -- +1 for header, +1 for empty line, -1 for 0-index = +1
    vim.api.nvim_buf_add_highlight(state.preview_bufnr, ns, 'CursorLine', cursor_line_idx, 0, -1)
  end
end

--- Get currently selected group info
---@return table|nil {name, attr, source} or {group, attr, category_name}
local function get_selected()
  if not state.flat_list or not state.flat_list[state.selected] then
    return nil
  end

  local item = state.flat_list[state.selected]

  -- Normalize to consistent format
  if item.group then
    -- Categories mode format
    return { name = item.group.name, attr = item.group.attr }
  else
    -- Cursor mode format
    return { name = item.name, attr = item.attr }
  end
end

--- Move selection
---@param delta number Amount to move (positive = down, negative = up)
local function move_selection(delta)
  local max = #state.flat_list
  if max == 0 then return end

  state.selected = state.selected + delta
  if state.selected < 1 then
    state.selected = max
  elseif state.selected > max then
    state.selected = 1
  end
  render()
end

--- Adjust the selected group's color hue
---@param delta number Hue adjustment in degrees
local function adjust_hue(delta)
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local current = groups.get_color(sel.name, channel)
  if not current then
    vim.notify('No ' .. channel .. ' color set for ' .. sel.name, vim.log.levels.WARN)
    return
  end

  local new_color = colors.adjust_hue(current, delta)
  groups.set_color(sel.name, channel, new_color)
  persistence.set_tweak(sel.name, channel, new_color)
  vim.notify(sel.name .. ' ' .. channel .. ': ' .. new_color, vim.log.levels.INFO)
  render()
  render_preview()
end

--- Adjust the selected group's color brightness
---@param delta number Brightness adjustment (-1 to 1)
local function adjust_brightness(delta)
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local current = groups.get_color(sel.name, channel)
  if not current then
    vim.notify('No ' .. channel .. ' color set for ' .. sel.name, vim.log.levels.WARN)
    return
  end

  local new_color = colors.adjust_brightness(current, delta)
  groups.set_color(sel.name, channel, new_color)
  persistence.set_tweak(sel.name, channel, new_color)
  vim.notify(sel.name .. ' ' .. channel .. ': ' .. new_color, vim.log.levels.INFO)
  render()
  render_preview()
end

--- Adjust the selected group's color saturation
---@param delta number Saturation adjustment (-1 to 1)
local function adjust_saturation(delta)
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local current = groups.get_color(sel.name, channel)
  if not current then
    vim.notify('No ' .. channel .. ' color set for ' .. sel.name, vim.log.levels.WARN)
    return
  end

  local new_color = colors.adjust_saturation(current, delta)
  groups.set_color(sel.name, channel, new_color)
  persistence.set_tweak(sel.name, channel, new_color)
  vim.notify(sel.name .. ' ' .. channel .. ': ' .. new_color, vim.log.levels.INFO)
  render()
  render_preview()
end

--- Copy selected group's active channel color to clipboard
local function copy_hex()
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local current = groups.get_color(sel.name, channel)
  if not current then
    vim.notify('No ' .. channel .. ' color set for ' .. sel.name, vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', current)
  vim.fn.setreg('"', current)
  vim.notify('Copied: ' .. current, vim.log.levels.INFO)
end

--- Paste color from clipboard to selected group's active channel
local function paste_hex()
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local clipboard = vim.fn.getreg('+')

  -- Clean up and validate
  clipboard = clipboard:gsub('%s+', '') -- remove whitespace
  if not clipboard:match('^#') then
    clipboard = '#' .. clipboard
  end

  if not clipboard:match('^#%x%x%x%x%x%x$') then
    vim.notify('Invalid hex color in clipboard: ' .. clipboard, vim.log.levels.ERROR)
    return
  end

  groups.set_color(sel.name, channel, clipboard)
  persistence.set_tweak(sel.name, channel, clipboard)
  vim.notify(sel.name .. ' ' .. channel .. ': ' .. clipboard, vim.log.levels.INFO)
  render()
  render_preview()
end

--- Open color picker for selected group
local function pick_color()
  local sel = get_selected()
  if not sel then return end

  local channel = get_group_channel(sel.name)
  local current = groups.get_color(sel.name, channel) or '#ffffff'
  vim.ui.input({ prompt = sel.name .. ' (' .. channel .. '): ', default = current }, function(value)
    if value and value:match '^#?%x%x%x%x%x%x$' then
      if not value:match '^#' then
        value = '#' .. value
      end
      groups.set_color(sel.name, channel, value)
      persistence.set_tweak(sel.name, channel, value)
      vim.notify(sel.name .. ' ' .. channel .. ': ' .. value, vim.log.levels.INFO)
      render()
      render_preview()
    elseif value then
      vim.notify('Invalid hex color. Use format: #RRGGBB', vim.log.levels.ERROR)
    end
  end)
end

--- Undo all tweaks for selected group (all channels)
local function undo_tweak()
  local sel = get_selected()
  if not sel then
    return
  end

  if not persistence.is_group_tweaked(sel.name) then
    vim.notify(sel.name .. ' is not tweaked', vim.log.levels.INFO)
    return
  end

  -- Remove all channels from config for this group
  persistence.remove_group(sel.name)

  -- Reload colorscheme to restore original
  local scheme = persistence.get_colorscheme()
  vim.cmd.colorscheme(scheme)
  -- Re-apply remaining tweaks
  persistence.apply_tweaks()

  vim.notify('Restored ' .. sel.name, vim.log.levels.INFO)

  -- In edited mode, refresh the list (group is no longer edited)
  if state.mode == 'edited' then
    state.flat_list = persistence.get_tweaked_groups()
    -- Close if no more edited groups
    if #state.flat_list == 0 then
      vim.notify('No more tweaked colors', vim.log.levels.INFO)
      M.close()
      return
    end
    -- Adjust selection if needed
    if state.selected > #state.flat_list then
      state.selected = #state.flat_list
    end
  end

  render()
end

--- Undo all tweaks for current colorscheme
local function undo_all_tweaks()
  persistence.clear_scheme()
  local scheme = persistence.get_colorscheme()
  vim.cmd.colorscheme(scheme)
  vim.notify('Restored all colors for ' .. scheme, vim.log.levels.INFO)
  M.close()
end

--- Close the picker window
function M.close()
  if state.preview_winid and vim.api.nvim_win_is_valid(state.preview_winid) then
    vim.api.nvim_win_close(state.preview_winid, true)
  end
  if state.preview_bufnr and vim.api.nvim_buf_is_valid(state.preview_bufnr) then
    vim.api.nvim_buf_delete(state.preview_bufnr, { force = true })
  end
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end

  state.bufnr = nil
  state.winid = nil
  state.preview_bufnr = nil
  state.preview_winid = nil
  state.flat_list = nil
  state.selected = 1
  state.mode = 'categories'
  state.preview_context = nil
  state.search_query = ''
  state.all_groups = nil
  state.total_count = 0
  state.group_channels = {}
end

--- Setup buffer keymaps
local function setup_keymaps()
  local opts = { buffer = state.bufnr, nowait = true }

  vim.keymap.set('n', 'j', function() move_selection(1) end, opts)
  vim.keymap.set('n', 'k', function() move_selection(-1) end, opts)
  vim.keymap.set('n', '<Down>', function() move_selection(1) end, opts)
  vim.keymap.set('n', '<Up>', function() move_selection(-1) end, opts)

  vim.keymap.set('n', ',', function() adjust_hue(-config.hue_step) end, opts)
  vim.keymap.set('n', '.', function() adjust_hue(config.hue_step) end, opts)

  vim.keymap.set('n', '[', function() adjust_brightness(-config.brightness_step) end, opts)
  vim.keymap.set('n', ']', function() adjust_brightness(config.brightness_step) end, opts)

  vim.keymap.set('n', '{', function() adjust_saturation(-config.saturation_step) end, opts)
  vim.keymap.set('n', '}', function() adjust_saturation(config.saturation_step) end, opts)

  vim.keymap.set('n', '#', pick_color, opts)
  vim.keymap.set('n', 'u', undo_tweak, opts)
  vim.keymap.set('n', 'y', copy_hex, opts)
  vim.keymap.set('n', 'p', paste_hex, opts)

  -- Channel cycling
  vim.keymap.set('n', '<Tab>', function()
    cycle_channel(false)
    render()
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    cycle_channel(true)
    render()
  end, opts)

  vim.keymap.set('n', 'q', M.close, opts)
  vim.keymap.set('n', '<Esc>', M.close, opts)
end

--- Open the picker window with curated categories
function M.open()
  -- Close existing if open
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    M.close()
    return
  end

  state.mode = 'categories'
  state.flat_list = groups.build_flat_list()
  state.selected = 1
  state.preview_context = nil

  -- Create buffer
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = state.bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = state.bufnr })

  -- Calculate centered position
  local width = config.width
  local height = config.height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create window
  state.winid = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Recolor ',
    title_pos = 'center',
  })

  vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
  vim.api.nvim_set_option_value('wrap', false, { win = state.winid })

  setup_keymaps()
  render()
end

--- Open the picker window with cursor inspection mode
---@param custom_groups table List of {name, attr, source}
---@param preview_context table|nil {bufnr, row, col, lines, filetype, ...}
function M.open_cursor(custom_groups, preview_context)
  -- Close existing if open
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    M.close()
  end

  if not custom_groups or #custom_groups == 0 then
    vim.notify('No highlight groups at cursor', vim.log.levels.INFO)
    return
  end

  state.mode = 'cursor'
  state.flat_list = custom_groups
  state.selected = 1
  state.preview_context = preview_context

  -- Calculate dimensions
  local has_preview = preview_context ~= nil
  local picker_width = config.width
  local preview_width = has_preview and config.preview_width or 0
  local total_width = picker_width + (has_preview and preview_width + 2 or 0)
  local height = config.height

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  -- Create picker buffer
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = state.bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = state.bufnr })

  -- Create picker window
  state.winid = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = picker_width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Groups at Cursor ',
    title_pos = 'center',
  })

  vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
  vim.api.nvim_set_option_value('wrap', false, { win = state.winid })

  -- Create preview window if we have context
  if has_preview then
    state.preview_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.preview_bufnr })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = state.preview_bufnr })
    vim.api.nvim_set_option_value('swapfile', false, { buf = state.preview_bufnr })

    state.preview_winid = vim.api.nvim_open_win(state.preview_bufnr, false, {
      relative = 'editor',
      width = preview_width,
      height = height,
      row = row,
      col = col + picker_width + 2,
      style = 'minimal',
      border = 'rounded',
      title = ' Preview ',
      title_pos = 'center',
    })

    vim.api.nvim_set_option_value('wrap', false, { win = state.preview_winid })
  end

  setup_keymaps()
  render()
  render_preview()
end

--- Update search and re-filter groups
local function update_search(query)
  state.search_query = query
  state.selected = 1

  if state.all_groups then
    local browse = require 'recolor.browse'
    state.flat_list = browse.filter_groups(state.all_groups, query)
  end

  render()
end

--- Handle character input for search
local function handle_char_input(char)
  update_search(state.search_query .. char)
end

--- Handle backspace for search
local function handle_backspace()
  if #state.search_query > 0 then
    update_search(state.search_query:sub(1, -2))
  end
end

--- Clear search
local function clear_search()
  update_search('')
end

--- Setup browse-specific keymaps (Ctrl commands, all letters for search)
local function setup_browse_keymaps()
  local opts = { buffer = state.bufnr, nowait = true }

  -- Navigation with Ctrl (all letters available for search)
  vim.keymap.set('n', '<C-j>', function() move_selection(1) end, opts)
  vim.keymap.set('n', '<C-k>', function() move_selection(-1) end, opts)
  vim.keymap.set('n', '<C-n>', function() move_selection(1) end, opts)
  vim.keymap.set('n', '<C-p>', paste_hex, opts) -- Also paste
  vim.keymap.set('n', '<Down>', function() move_selection(1) end, opts)
  vim.keymap.set('n', '<Up>', function() move_selection(-1) end, opts)

  -- Color adjustment (non-letter keys, no conflict)
  vim.keymap.set('n', ',', function() adjust_hue(-config.hue_step) end, opts)
  vim.keymap.set('n', '.', function() adjust_hue(config.hue_step) end, opts)

  vim.keymap.set('n', '[', function() adjust_brightness(-config.brightness_step) end, opts)
  vim.keymap.set('n', ']', function() adjust_brightness(config.brightness_step) end, opts)

  vim.keymap.set('n', '{', function() adjust_saturation(-config.saturation_step) end, opts)
  vim.keymap.set('n', '}', function() adjust_saturation(config.saturation_step) end, opts)

  -- Commands with Ctrl
  vim.keymap.set('n', '#', pick_color, opts)
  vim.keymap.set('n', '<C-u>', undo_tweak, opts)
  vim.keymap.set('n', '<C-y>', copy_hex, opts)
  vim.keymap.set('n', '<C-c>', clear_search, opts)

  -- Channel cycling
  vim.keymap.set('n', '<Tab>', function()
    cycle_channel(false)
    render()
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    cycle_channel(true)
    render()
  end, opts)

  -- Only Esc to close (q available for search)
  vim.keymap.set('n', '<Esc>', M.close, opts)

  -- Search input handling
  vim.keymap.set('n', '<BS>', handle_backspace, opts)

  -- Map all printable characters for search input (no exclusions)
  local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@-'
  for i = 1, #chars do
    local char = chars:sub(i, i)
    vim.keymap.set('n', char, function() handle_char_input(char) end, opts)
  end
end

--- Open the picker window in browse mode (all groups with search)
function M.open_browse()
  -- Close existing if open
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    M.close()
    return
  end

  local browse = require 'recolor.browse'

  state.mode = 'browse'
  state.all_groups = browse.get_all_groups()
  state.flat_list = state.all_groups
  state.total_count = #state.all_groups
  state.selected = 1
  state.search_query = ''
  state.preview_context = nil

  -- Create buffer
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = state.bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = state.bufnr })

  -- Calculate centered position (browse mode uses wider window)
  local width = config.browse_width
  local height = config.height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create window
  state.winid = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' All Highlight Groups ',
    title_pos = 'center',
  })

  vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
  vim.api.nvim_set_option_value('wrap', false, { win = state.winid })

  setup_browse_keymaps()
  render()
end

--- Setup edited-specific keymaps (includes U for undo all)
local function setup_edited_keymaps()
  local opts = { buffer = state.bufnr, nowait = true }

  vim.keymap.set('n', 'j', function() move_selection(1) end, opts)
  vim.keymap.set('n', 'k', function() move_selection(-1) end, opts)
  vim.keymap.set('n', '<Down>', function() move_selection(1) end, opts)
  vim.keymap.set('n', '<Up>', function() move_selection(-1) end, opts)

  vim.keymap.set('n', ',', function() adjust_hue(-config.hue_step) end, opts)
  vim.keymap.set('n', '.', function() adjust_hue(config.hue_step) end, opts)

  vim.keymap.set('n', '[', function() adjust_brightness(-config.brightness_step) end, opts)
  vim.keymap.set('n', ']', function() adjust_brightness(config.brightness_step) end, opts)

  vim.keymap.set('n', '{', function() adjust_saturation(-config.saturation_step) end, opts)
  vim.keymap.set('n', '}', function() adjust_saturation(config.saturation_step) end, opts)

  vim.keymap.set('n', '#', pick_color, opts)
  vim.keymap.set('n', 'u', undo_tweak, opts)
  vim.keymap.set('n', 'U', undo_all_tweaks, opts)
  vim.keymap.set('n', 'y', copy_hex, opts)
  vim.keymap.set('n', 'p', paste_hex, opts)

  -- Channel cycling
  vim.keymap.set('n', '<Tab>', function()
    cycle_channel(false)
    render()
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    cycle_channel(true)
    render()
  end, opts)

  vim.keymap.set('n', 'q', M.close, opts)
  vim.keymap.set('n', '<Esc>', M.close, opts)
end

--- Open the picker window with edited groups only
function M.open_edited()
  local tweaked = persistence.get_tweaked_groups()
  if #tweaked == 0 then
    vim.notify('No tweaked colors for current scheme', vim.log.levels.INFO)
    return
  end

  -- Close existing if open
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    M.close()
  end

  state.mode = 'edited'
  state.flat_list = tweaked
  state.selected = 1
  state.preview_context = nil

  -- Create buffer
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = state.bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = state.bufnr })

  -- Calculate centered position
  local width = config.width
  local height = config.height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create window
  local scheme = persistence.get_colorscheme()
  state.winid = vim.api.nvim_open_win(state.bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Edited Colors (' .. scheme .. ') ',
    title_pos = 'center',
  })

  vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
  vim.api.nvim_set_option_value('wrap', false, { win = state.winid })

  setup_edited_keymaps()
  render()
end

return M
