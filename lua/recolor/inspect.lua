-- Cursor inspection for recolor
-- Extract highlight groups at current cursor position

local groups = require 'recolor.groups'

local M = {}

--- Get all highlight groups at the current cursor position
---@return table groups List of {name, attr, source} for each highlight group
---@return table context Preview context {bufnr, row, col, lines}
function M.get_groups_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]

  -- Get all highlights at position
  local result = vim.inspect_pos(bufnr, row, col, {
    syntax = true,
    treesitter = true,
    extmarks = true,
    semantic_tokens = true,
  })

  local seen = {}
  local group_list = {}

  -- Helper to add a group if not already seen
  local function add_group(name, source)
    if not name or name == '' or seen[name] then
      return
    end
    seen[name] = true

    -- Determine if this is primarily a fg or bg highlight
    -- Most syntax/treesitter groups are fg, check if it has a color
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    local attr = 'fg'
    if hl.bg and not hl.fg then
      attr = 'bg'
    end

    table.insert(group_list, {
      name = name,
      attr = attr,
      source = source,
    })
  end

  -- Process treesitter captures
  if result.treesitter then
    for _, item in ipairs(result.treesitter) do
      local hl_group = item.hl_group or item.capture
      add_group(hl_group, 'treesitter')
      -- Also add the capture name if different
      if item.capture and item.capture ~= hl_group then
        add_group(item.capture, 'treesitter')
      end
    end
  end

  -- Process syntax groups
  if result.syntax then
    for _, item in ipairs(result.syntax) do
      add_group(item.hl_group, 'syntax')
      -- Add linked group too
      if item.hl_group_link and item.hl_group_link ~= item.hl_group then
        add_group(item.hl_group_link, 'syntax (link)')
      end
    end
  end

  -- Process semantic tokens
  if result.semantic_tokens then
    for _, item in ipairs(result.semantic_tokens) do
      add_group(item.hl_group, 'semantic')
    end
  end

  -- Process extmarks (gitsigns, diagnostics, etc.)
  if result.extmarks then
    for _, item in ipairs(result.extmarks) do
      if item.opts and item.opts.hl_group then
        add_group(item.opts.hl_group, 'extmark')
      end
    end
  end

  -- Build preview context - get lines around cursor
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(0, row - 2)
  local end_line = math.min(total_lines, row + 3)
  local preview_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local context = {
    bufnr = bufnr,
    row = row,
    col = col,
    start_line = start_line,
    cursor_line_in_preview = row - start_line + 1,
    lines = preview_lines,
    filetype = vim.bo[bufnr].filetype,
  }

  return group_list, context
end

--- Resolve a highlight group to its final definition (follow links)
---@param name string Highlight group name
---@return string Final highlight group name
function M.resolve_link(name)
  local max_depth = 10
  local current = name

  for _ = 1, max_depth do
    local hl = vim.api.nvim_get_hl(0, { name = current })
    if hl.link then
      current = hl.link
    else
      break
    end
  end

  return current
end

return M
