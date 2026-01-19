-- Health check for recolor plugin
-- Run with :checkhealth recolor

local M = {}

function M.check()
  -- Neovim version check
  vim.health.start('Neovim Version')
  local v = vim.version()
  if v.major > 0 or v.minor >= 9 then
    vim.health.ok('Neovim ' .. v.major .. '.' .. v.minor .. '.' .. v.patch)
  else
    vim.health.error('Neovim >= 0.9.0 required (have ' .. v.major .. '.' .. v.minor .. '.' .. v.patch .. ')')
  end

  -- Config file checks
  vim.health.start('Configuration')
  local persistence = require('recolor.persistence')
  local path = persistence.get_config_path()
  vim.health.info('Config path: ' .. path)

  -- Check parent directory exists
  local parent = vim.fn.fnamemodify(path, ':h')
  if vim.fn.isdirectory(parent) == 1 then
    vim.health.ok('Config directory exists: ' .. parent)
  else
    vim.health.warn('Config directory does not exist: ' .. parent)
  end

  -- Check if config file exists and is valid
  local file = io.open(path, 'r')
  if file then
    local content = file:read('*a')
    file:close()

    if content == '' then
      vim.health.ok('Config file exists (empty)')
    else
      local ok, err = pcall(vim.json.decode, content)
      if ok then
        vim.health.ok('Config file exists and contains valid JSON')
      else
        vim.health.error('Config file contains invalid JSON: ' .. tostring(err))
      end
    end

    -- Check writable
    local test_file = io.open(path, 'a')
    if test_file then
      test_file:close()
      vim.health.ok('Config file is writable')
    else
      vim.health.warn('Config file is not writable')
    end
  else
    vim.health.info('Config file does not exist yet (will be created on first tweak)')
  end

  -- Current colorscheme info
  vim.health.start('Current Colorscheme')
  local scheme = persistence.get_colorscheme()
  vim.health.info('Colorscheme: ' .. scheme)

  local tweaked = persistence.get_tweaked_groups()
  local count = #tweaked
  if count > 0 then
    vim.health.ok(count .. ' customized group' .. (count == 1 and '' or 's'))
    for _, group in ipairs(tweaked) do
      local channels = {}
      for channel, _ in pairs(group.tweaks) do
        table.insert(channels, channel)
      end
      vim.health.info('  • ' .. group.name .. ' (' .. table.concat(channels, ', ') .. ')')
    end
  else
    vim.health.ok('No customizations for this colorscheme')
  end
end

return M
