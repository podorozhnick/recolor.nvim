-- Browse all highlight groups for recolor
-- Get all highlights and fuzzy filter them

local groups = require 'recolor.groups'

local M = {}

--- Get all defined highlight groups
---@return table List of {name, attr, is_link} sorted alphabetically
function M.get_all_groups()
  local all_hl = vim.api.nvim_get_hl(0, {})
  local group_list = {}

  for name, def in pairs(all_hl) do
    -- Determine if this is a link or has actual colors
    local is_link = def.link ~= nil
    local attr = 'fg'

    if not is_link then
      -- Determine primary attribute (fg or bg)
      if def.bg and not def.fg then
        attr = 'bg'
      end
    end

    table.insert(group_list, {
      name = name,
      attr = attr,
      is_link = is_link,
      link_target = def.link,
    })
  end

  -- Sort alphabetically
  table.sort(group_list, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return group_list
end

--- Filter groups using fuzzy matching
---@param all_groups table Full list of groups
---@param pattern string Search pattern
---@return table Filtered list of groups
function M.filter_groups(all_groups, pattern)
  if not pattern or pattern == '' then
    return all_groups
  end

  -- Extract just the names for matchfuzzy
  local names = {}
  local name_to_group = {}
  for _, group in ipairs(all_groups) do
    table.insert(names, group.name)
    name_to_group[group.name] = group
  end

  -- Use builtin fuzzy matcher
  local matched_names = vim.fn.matchfuzzy(names, pattern)

  -- Convert back to group objects
  local filtered = {}
  for _, name in ipairs(matched_names) do
    table.insert(filtered, name_to_group[name])
  end

  return filtered
end

--- Get color info for display
---@param name string Highlight group name
---@return string Color hex or status string
---@return string|nil Attribute (fg/bg) if color exists
function M.get_color_info(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })

  if hl.link then
    return '-> ' .. hl.link, nil
  end

  local fg = hl.fg and string.format('#%06x', hl.fg) or nil
  local bg = hl.bg and string.format('#%06x', hl.bg) or nil

  if fg and bg then
    return fg .. ' / ' .. bg, 'both'
  elseif fg then
    return fg, 'fg'
  elseif bg then
    return bg, 'bg'
  else
    return '(none)', nil
  end
end

return M
