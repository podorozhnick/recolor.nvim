-- Color manipulation utilities for recolor plugin
-- HSL/RGB conversion functions

local M = {}

--- Parse hex color string to RGB values
---@param hex string Color in "#RRGGBB" or "RRGGBB" format
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
function M.hex_to_rgb(hex)
  hex = hex:gsub('#', '')
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  return r, g, b
end

--- Convert RGB values to hex color string
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return string Hex color in "#RRGGBB" format
function M.rgb_to_hex(r, g, b)
  r = math.max(0, math.min(255, math.floor(r + 0.5)))
  g = math.max(0, math.min(255, math.floor(g + 0.5)))
  b = math.max(0, math.min(255, math.floor(b + 0.5)))
  return string.format('#%02x%02x%02x', r, g, b)
end

--- Convert RGB to HSL
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return number h Hue (0-360)
---@return number s Saturation (0-1)
---@return number l Lightness (0-1)
function M.rgb_to_hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255

  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s, l

  l = (max + min) / 2

  if max == min then
    h, s = 0, 0
  else
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)

    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end

    h = h * 60
  end

  return h, s, l
end

--- Convert HSL to RGB
---@param h number Hue (0-360)
---@param s number Saturation (0-1)
---@param l number Lightness (0-1)
---@return number r Red (0-255)
---@return number g Green (0-255)
---@return number b Blue (0-255)
function M.hsl_to_rgb(h, s, l)
  local r, g, b

  if s == 0 then
    r, g, b = l, l, l
  else
    local function hue_to_rgb(p, q, t)
      if t < 0 then t = t + 1 end
      if t > 1 then t = t - 1 end
      if t < 1 / 6 then return p + (q - p) * 6 * t end
      if t < 1 / 2 then return q end
      if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
      return p
    end

    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q

    r = hue_to_rgb(p, q, h / 360 + 1 / 3)
    g = hue_to_rgb(p, q, h / 360)
    b = hue_to_rgb(p, q, h / 360 - 1 / 3)
  end

  return r * 255, g * 255, b * 255
end

--- Adjust the lightness of a hex color
---@param hex string Color in hex format
---@param delta number Amount to adjust lightness (-1 to 1, e.g., 0.05 for +5%)
---@return string Adjusted hex color
function M.adjust_brightness(hex, delta)
  local r, g, b = M.hex_to_rgb(hex)
  local h, s, l = M.rgb_to_hsl(r, g, b)

  l = math.max(0, math.min(1, l + delta))

  r, g, b = M.hsl_to_rgb(h, s, l)
  return M.rgb_to_hex(r, g, b)
end

--- Adjust the hue of a hex color
---@param hex string Color in hex format
---@param delta number Amount to adjust hue in degrees (-360 to 360)
---@return string Adjusted hex color
function M.adjust_hue(hex, delta)
  local r, g, b = M.hex_to_rgb(hex)
  local h, s, l = M.rgb_to_hsl(r, g, b)

  h = (h + delta) % 360
  if h < 0 then h = h + 360 end

  r, g, b = M.hsl_to_rgb(h, s, l)
  return M.rgb_to_hex(r, g, b)
end

--- Adjust the saturation of a hex color
---@param hex string Color in hex format
---@param delta number Amount to adjust saturation (-1 to 1, e.g., 0.1 for +10%)
---@return string Adjusted hex color
function M.adjust_saturation(hex, delta)
  local r, g, b = M.hex_to_rgb(hex)
  local h, s, l = M.rgb_to_hsl(r, g, b)

  s = math.max(0, math.min(1, s + delta))

  r, g, b = M.hsl_to_rgb(h, s, l)
  return M.rgb_to_hex(r, g, b)
end

return M
