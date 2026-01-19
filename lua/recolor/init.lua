-- recolor: Interactive colorscheme adjustment plugin
-- Adjust background color hue and brightness with vim-style keymaps

local colors = require 'recolor.colors'
local picker = require 'recolor.picker'
local inspect = require 'recolor.inspect'
local persistence = require 'recolor.persistence'

local M = {}

-- Default configuration
M.config = {
  brightness_step = 0.05, -- 5% lightness change
  hue_step = 10, -- 10 degree hue rotation
  -- Config file path for persisted tweaks
  -- Default: stdpath('config') .. '/recolor.json' (git-trackable)
  -- Alternative: vim.fn.stdpath('data') .. '/recolor.json' (runtime data)
  tweaks_path = nil,
}

--- Get current background color from Normal highlight group
---@return string|nil hex color or nil if not set
local function get_bg_color()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
  if normal.bg then
    return string.format('#%06x', normal.bg)
  end
  return nil
end

--- Set background color on Normal highlight group
---@param hex string Color in hex format
local function set_bg_color(hex)
  vim.api.nvim_set_hl(0, 'Normal', { bg = hex })
  vim.notify('Background: ' .. hex, vim.log.levels.INFO)
end

--- Adjust background brightness
---@param delta number Amount to adjust (positive = lighter, negative = darker)
function M.adjust_bg_brightness(delta)
  local current = get_bg_color()
  if not current then
    vim.notify('No background color set', vim.log.levels.WARN)
    return
  end

  local new_color = colors.adjust_brightness(current, delta)
  set_bg_color(new_color)
end

--- Adjust background hue
---@param delta number Amount to adjust in degrees (positive = right, negative = left)
function M.adjust_bg_hue(delta)
  local current = get_bg_color()
  if not current then
    vim.notify('No background color set', vim.log.levels.WARN)
    return
  end

  local new_color = colors.adjust_hue(current, delta)
  set_bg_color(new_color)
end

--- Open color picker to set background color
function M.pick_bg_color()
  local current = get_bg_color() or '#ffffff'
  vim.ui.input({ prompt = 'Background color: ', default = current }, function(value)
    if value and value:match '^#?%x%x%x%x%x%x$' then
      if not value:match '^#' then
        value = '#' .. value
      end
      set_bg_color(value)
    elseif value then
      vim.notify('Invalid hex color. Use format: #RRGGBB', vim.log.levels.ERROR)
    end
  end)
end

--- Setup the plugin with optional configuration
---@param opts table|nil Optional configuration overrides
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Set custom config path if provided
  if M.config.tweaks_path then
    persistence.set_config_path(M.config.tweaks_path)
  end

  local step_b = M.config.brightness_step
  local step_h = M.config.hue_step

  -- Brightness keymaps (k = up/lighter, j = down/darker)
  vim.keymap.set('n', '<leader>ck', function()
    M.adjust_bg_brightness(step_b)
  end, { desc = 'Color: Brighten background' })

  vim.keymap.set('n', '<leader>cj', function()
    M.adjust_bg_brightness(-step_b)
  end, { desc = 'Color: Darken background' })

  -- Hue keymaps (l = right, h = left)
  vim.keymap.set('n', '<leader>cl', function()
    M.adjust_bg_hue(step_h)
  end, { desc = 'Color: Shift hue right' })

  vim.keymap.set('n', '<leader>ch', function()
    M.adjust_bg_hue(-step_h)
  end, { desc = 'Color: Shift hue left' })

  -- Color picker
  vim.keymap.set('n', '<leader>cp', function()
    M.pick_bg_color()
  end, { desc = 'Color: Pick background color' })

  -- Open highlight group picker
  vim.keymap.set('n', '<leader>cc', function()
    picker.open()
  end, { desc = 'Color: Open group picker' })

  -- Inspect and edit colors at cursor
  vim.keymap.set('n', '<leader>ci', function()
    local groups_at_cursor, context = inspect.get_groups_at_cursor()
    picker.open_cursor(groups_at_cursor, context)
  end, { desc = 'Color: Inspect at cursor' })

  -- Browse all highlight groups with search
  vim.keymap.set('n', '<leader>ca', function()
    picker.open_browse()
  end, { desc = 'Color: Browse all groups' })

  -- View edited groups for current colorscheme
  vim.keymap.set('n', '<leader>ce', function()
    picker.open_edited()
  end, { desc = 'Color: View edited groups' })

  -- Setup ColorScheme autocmd to apply tweaks when colorscheme changes
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('RecolorPersist', { clear = true }),
    callback = function()
      -- Small delay to ensure colorscheme fully loaded
      vim.defer_fn(function()
        persistence.invalidate_cache()
        persistence.apply_tweaks()
      end, 10)
    end,
  })

  -- Apply tweaks on initial setup (for current colorscheme)
  vim.defer_fn(function()
    persistence.apply_tweaks()
  end, 10)
end

return M
