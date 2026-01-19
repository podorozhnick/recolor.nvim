-- Persistence for recolor plugin
-- Save/load color tweaks per colorscheme

local M = {}

-- In-memory cache of config
local config_cache = nil

-- Configurable path (set via setup)
local config_path = nil

--- Set the config file path
---@param path string|nil Custom path or nil for default
function M.set_config_path(path)
  config_path = path
end

--- Get path to config file
---@return string Path to recolor.json
function M.get_config_path()
  if config_path then
    return config_path
  end
  -- Default to config directory (git-trackable with your nvim config)
  return vim.fn.stdpath('config') .. '/recolor.json'
end

--- Load config from disk (cached)
---@return table Config data
function M.load()
  if config_cache then
    return config_cache
  end

  local path = M.get_config_path()
  local file = io.open(path, 'r')
  if not file then
    config_cache = {}
    return config_cache
  end

  local content = file:read('*a')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and decoded then
    config_cache = decoded
  else
    config_cache = {}
  end

  return config_cache
end

--- Save config to disk
function M.save()
  local path = M.get_config_path()
  local file = io.open(path, 'w')
  if not file then
    vim.notify('Failed to save color tweaks to ' .. path, vim.log.levels.ERROR)
    return
  end

  local ok, encoded = pcall(vim.json.encode, config_cache or {})
  if ok then
    file:write(encoded)
  else
    vim.notify('Failed to encode color tweaks', vim.log.levels.ERROR)
  end
  file:close()
end

--- Get current colorscheme name
---@return string Colorscheme name or 'default'
function M.get_colorscheme()
  return vim.g.colors_name or 'default'
end

--- Set a tweak for current colorscheme
---@param group string Highlight group name
---@param channel string 'fg', 'bg', or 'sp'
---@param color string Hex color
function M.set_tweak(group, channel, color)
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  cfg[scheme] = cfg[scheme] or {}
  cfg[scheme][group] = cfg[scheme][group] or {}
  cfg[scheme][group][channel] = color
  M.save()
end

--- Remove a tweak (single channel)
---@param group string Highlight group name
---@param channel string 'fg', 'bg', or 'sp'
function M.remove_tweak(group, channel)
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  if cfg[scheme] and cfg[scheme][group] then
    cfg[scheme][group][channel] = nil
    -- Remove group entry if no channels left
    if next(cfg[scheme][group]) == nil then
      cfg[scheme][group] = nil
    end
    -- Remove scheme entry if no groups left
    if next(cfg[scheme]) == nil then
      cfg[scheme] = nil
    end
    M.save()
  end
end

--- Remove all tweaks for a group (all channels)
---@param group string Highlight group name
function M.remove_group(group)
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  if cfg[scheme] and cfg[scheme][group] then
    cfg[scheme][group] = nil
    -- Remove scheme entry if no groups left
    if next(cfg[scheme]) == nil then
      cfg[scheme] = nil
    end
    M.save()
  end
end

--- Clear all tweaks for current colorscheme
function M.clear_scheme()
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  cfg[scheme] = nil
  M.save()
end

--- Check if a group/channel is tweaked
---@param group string Highlight group name
---@param channel string 'fg', 'bg', or 'sp'
---@return boolean
function M.is_tweaked(group, channel)
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  return cfg[scheme] and cfg[scheme][group] and cfg[scheme][group][channel] ~= nil
end

--- Check if any channel of a group is tweaked
---@param group string Highlight group name
---@return boolean
function M.is_group_tweaked(group)
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  return cfg[scheme] and cfg[scheme][group] and next(cfg[scheme][group]) ~= nil
end

--- Get all tweaked groups for current colorscheme
---@return table[] List of {name, attr, tweaks}
function M.get_tweaked_groups()
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  local result = {}

  if cfg[scheme] then
    for group, channels in pairs(cfg[scheme]) do
      -- Determine primary attr from what's tweaked
      local attr = 'fg'
      if channels.bg and not channels.fg then
        attr = 'bg'
      end
      table.insert(result, { name = group, attr = attr, tweaks = channels })
    end
  end

  -- Sort alphabetically
  table.sort(result, function(a, b)
    return a.name < b.name
  end)

  return result
end

--- Apply all tweaks for current colorscheme
function M.apply_tweaks()
  local scheme = M.get_colorscheme()
  local cfg = M.load()
  if not cfg[scheme] then
    return
  end

  local groups = require('recolor.groups')
  for group, channels in pairs(cfg[scheme]) do
    for channel, color in pairs(channels) do
      groups.set_color(group, channel, color)
    end
  end
end

--- Invalidate cache (call after colorscheme change before apply)
function M.invalidate_cache()
  config_cache = nil
end

return M
