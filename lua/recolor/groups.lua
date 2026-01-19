-- Curated highlight group definitions for recolor
-- Organized by category with fg/bg attribute specification

local M = {}

-- Categories of highlight groups
-- attr: which color attribute to adjust ('fg' or 'bg')
M.categories = {
  {
    name = 'Base UI',
    groups = {
      { name = 'Normal', attr = 'bg' },
      { name = 'NormalFloat', attr = 'bg' },
      { name = 'CursorLine', attr = 'bg' },
      { name = 'CursorColumn', attr = 'bg' },
      { name = 'Visual', attr = 'bg' },
      { name = 'Search', attr = 'bg' },
      { name = 'IncSearch', attr = 'bg' },
      { name = 'MatchParen', attr = 'bg' },
    },
  },
  {
    name = 'Gutter',
    groups = {
      { name = 'LineNr', attr = 'fg' },
      { name = 'CursorLineNr', attr = 'fg' },
      { name = 'SignColumn', attr = 'bg' },
      { name = 'Folded', attr = 'bg' },
    },
  },
  {
    name = 'Syntax',
    groups = {
      { name = 'Comment', attr = 'fg' },
      { name = 'String', attr = 'fg' },
      { name = 'Function', attr = 'fg' },
      { name = 'Keyword', attr = 'fg' },
      { name = 'Type', attr = 'fg' },
      { name = 'Constant', attr = 'fg' },
      { name = 'Identifier', attr = 'fg' },
      { name = 'Operator', attr = 'fg' },
    },
  },
  {
    name = 'Treesitter',
    groups = {
      { name = '@comment', attr = 'fg' },
      { name = '@string', attr = 'fg' },
      { name = '@function', attr = 'fg' },
      { name = '@keyword', attr = 'fg' },
      { name = '@type', attr = 'fg' },
      { name = '@constant', attr = 'fg' },
      { name = '@variable', attr = 'fg' },
    },
  },
  {
    name = 'Diagnostics',
    groups = {
      { name = 'DiagnosticError', attr = 'fg' },
      { name = 'DiagnosticWarn', attr = 'fg' },
      { name = 'DiagnosticInfo', attr = 'fg' },
      { name = 'DiagnosticHint', attr = 'fg' },
    },
  },
  {
    name = 'UI Feedback',
    groups = {
      { name = 'Pmenu', attr = 'bg' },
      { name = 'PmenuSel', attr = 'bg' },
      { name = 'FloatBorder', attr = 'fg' },
      { name = 'ErrorMsg', attr = 'fg' },
      { name = 'WarningMsg', attr = 'fg' },
    },
  },
}

--- Get color from a highlight group
---@param group string Highlight group name
---@param attr string 'fg', 'bg', or 'sp'
---@return string|nil Hex color or nil if not set
function M.get_color(group, attr)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  local color = hl[attr]
  if color then
    return string.format('#%06x', color)
  end
  return nil
end

--- Get all colors for a highlight group
---@param group string Highlight group name
---@return table {fg = hex|nil, bg = hex|nil, sp = hex|nil}
function M.get_all_colors(group)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return {
    fg = hl.fg and string.format('#%06x', hl.fg) or nil,
    bg = hl.bg and string.format('#%06x', hl.bg) or nil,
    sp = hl.sp and string.format('#%06x', hl.sp) or nil,
  }
end

--- Get available channels for a group (ones that have colors)
---@param group string Highlight group name
---@return string[] List of available channels ('fg', 'bg', 'sp')
function M.get_available_channels(group)
  local colors = M.get_all_colors(group)
  local channels = {}
  if colors.fg then table.insert(channels, 'fg') end
  if colors.bg then table.insert(channels, 'bg') end
  if colors.sp then table.insert(channels, 'sp') end
  return channels
end

--- Set color on a highlight group
---@param group string Highlight group name
---@param attr string 'fg', 'bg', or 'sp'
---@param hex string Hex color
function M.set_color(group, attr, hex)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  hl[attr] = hex
  vim.api.nvim_set_hl(0, group, hl)
end

--- Build flat list of all groups for navigation
---@return table[] List of {category_idx, group_idx, category_name, group}
function M.build_flat_list()
  local list = {}
  for cat_idx, category in ipairs(M.categories) do
    for grp_idx, group in ipairs(category.groups) do
      table.insert(list, {
        category_idx = cat_idx,
        group_idx = grp_idx,
        category_name = category.name,
        group = group,
      })
    end
  end
  return list
end

return M
