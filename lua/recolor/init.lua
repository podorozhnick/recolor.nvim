-- recolor: Interactive colorscheme adjustment plugin
-- Adjust highlight group colors with persistent tweaks per colorscheme

local picker = require 'recolor.picker'
local inspect = require 'recolor.inspect'
local persistence = require 'recolor.persistence'

local M = {}

-- Default configuration
M.config = {
  brightness_step = 0.05, -- 5% lightness change
  hue_step = 10, -- 10 degree hue rotation
  saturation_step = 0.05, -- 5% saturation change
  -- Config file path for persisted tweaks
  -- Default: stdpath('config') .. '/recolor.json' (git-trackable)
  -- Alternative: vim.fn.stdpath('data') .. '/recolor.json' (runtime data)
  tweaks_path = nil,
  -- Keymaps (set to false to disable individual keymaps)
  keymaps = {
    categories = '<leader>cc', -- :Recolor
    inspect = '<leader>ci', -- :RecolorInspect
    browse = '<leader>ca', -- :RecolorBrowse
    edited = '<leader>ce', -- :RecolorEdited
  },
}

--- Set a keymap if the lhs is not false/nil
---@param mode string|string[] Mode(s) for the keymap
---@param lhs string|false|nil Left-hand side of keymap
---@param rhs string|function Right-hand side of keymap
---@param opts table Keymap options
local function set_keymap_if_enabled(mode, lhs, rhs, opts)
  if lhs and lhs ~= false then
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

--- Validate configuration options
---@param opts table Configuration options to validate
local function validate_config(opts)
  vim.validate({
    brightness_step = { opts.brightness_step, 'number', true },
    hue_step = { opts.hue_step, 'number', true },
    saturation_step = { opts.saturation_step, 'number', true },
    tweaks_path = { opts.tweaks_path, 'string', true },
    keymaps = { opts.keymaps, 'table', true },
  })
  if opts.keymaps then
    vim.validate({
      ['keymaps.categories'] = { opts.keymaps.categories, { 'string', 'boolean' }, true },
      ['keymaps.inspect'] = { opts.keymaps.inspect, { 'string', 'boolean' }, true },
      ['keymaps.browse'] = { opts.keymaps.browse, { 'string', 'boolean' }, true },
      ['keymaps.edited'] = { opts.keymaps.edited, { 'string', 'boolean' }, true },
    })
  end
end

--- Setup the plugin with optional configuration
---@param opts table|nil Optional configuration overrides
function M.setup(opts)
  opts = opts or {}
  validate_config(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Set custom config path if provided
  if M.config.tweaks_path then
    persistence.set_config_path(M.config.tweaks_path)
  end

  -- User commands
  vim.api.nvim_create_user_command('Recolor', function()
    picker.open()
  end, { desc = 'Open Recolor curated picker' })

  vim.api.nvim_create_user_command('RecolorInspect', function()
    local groups_at_cursor, context = inspect.get_groups_at_cursor()
    picker.open_cursor(groups_at_cursor, context)
  end, { desc = 'Inspect highlight groups at cursor' })

  vim.api.nvim_create_user_command('RecolorBrowse', function()
    picker.open_browse()
  end, { desc = 'Browse all highlight groups' })

  vim.api.nvim_create_user_command('RecolorEdited', function()
    picker.open_edited()
  end, { desc = 'View edited highlight groups' })

  vim.api.nvim_create_user_command('RecolorUndo', function()
    local scheme = persistence.get_colorscheme()
    persistence.clear_scheme()
    vim.cmd.colorscheme(scheme)
    vim.notify('Restored all colors for ' .. scheme, vim.log.levels.INFO)
  end, { desc = 'Undo all tweaks for current colorscheme' })

  -- Keymaps (configurable)
  local keys = M.config.keymaps

  set_keymap_if_enabled('n', keys.categories, '<Cmd>Recolor<CR>', { desc = 'Recolor: Open curated picker' })
  set_keymap_if_enabled('n', keys.inspect, '<Cmd>RecolorInspect<CR>', { desc = 'Recolor: Inspect at cursor' })
  set_keymap_if_enabled('n', keys.browse, '<Cmd>RecolorBrowse<CR>', { desc = 'Recolor: Browse all groups' })
  set_keymap_if_enabled('n', keys.edited, '<Cmd>RecolorEdited<CR>', { desc = 'Recolor: View edited groups' })

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
