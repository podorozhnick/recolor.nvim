# recolor.nvim

Change any color in your Neovim colorscheme, right where you see it.

![Preview](https://imgur.com/a/Oy8vhUT)

## Why This Plugin?

I've tried dozens of colorschemes. Every time I settle on one, there's *something* I want to tweak—the background is too dark, comments are hard to read, the cursor line blends in too much. Most colorschemes let you customize things, but each one does it differently.

What I really wanted was:
- **One way to tweak colors across any colorscheme** — not learning each theme's config API
- **Point at something and change it** — see an ugly color? Fix it on the spot
- **Keep my tweaks** — switch themes, restart Neovim, my adjustments stick

So I built this. And it turned out to be more useful than expected. Beyond just setting up a colorscheme once, I now constantly refine colors as I work. Cursor line too bright today? Two keypresses. Don't like how strings look in this file? Quick fix. Sometimes I experiment with wild changes, then undo them. The barrier to adjusting colors dropped to nearly zero.

If you've ever wanted to just *point at a color and change it*, this plugin is for you.

## Features

- **Inspect and edit colors at cursor** — see something you don't like? `<leader>ci` to inspect it, adjust immediately
- **Browse all 600+ highlight groups** — fuzzy search through everything, including Treesitter and LSP semantic tokens
- **HSL-based adjustments** — shift hue, saturation, and brightness with single keypresses
- **Per-colorscheme persistence** — tweaks save automatically to a JSON file and reapply when you switch themes
- **Edit fg, bg, or special** — Tab through color channels for any highlight group
- **Copy/paste hex colors** — grab colors from other sources or share them
- **Undo support** — restore individual groups or everything at once

![Features](https://imgur.com/0XSbL8I)

## Requirements

- Neovim >= 0.9.0
- No external dependencies

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
  'podorozhnick/recolor.nvim',
  config = function()
    require('recolor').setup()
  end,
  -- Optional: lazy load on command or keymap
  cmd = { 'Recolor', 'RecolorInspect', 'RecolorBrowse', 'RecolorEdited' },
  keys = {
    { '<leader>cc', '<Cmd>Recolor<CR>', desc = 'Recolor: Open picker' },
    { '<leader>ci', '<Cmd>RecolorInspect<CR>', desc = 'Recolor: Inspect at cursor' },
  },
}
```

</details>

<details>
<summary>packer.nvim</summary>

```lua
use {
  'podorozhnick/recolor.nvim',
  config = function()
    require('recolor').setup()
  end
}
```

</details>

<details>
<summary>vim-plug</summary>

```vim
Plug 'podorozhnick/recolor.nvim'

" In your init.lua or after/plugin:
lua require('recolor').setup()
```

</details>

## Quick Start

1. Open any file in Neovim
2. Press `<leader>ci` to inspect colors at your cursor position
3. Use `,`/`.` to shift hue, `[`/`]` to adjust brightness
4. Your changes save automatically

That's it. The color will persist across sessions and reapply whenever you use this colorscheme.

## Commands

| Command | Description |
|---------|-------------|
| `:Recolor` | Open picker with curated highlight groups |
| `:RecolorInspect` | Inspect and edit colors at cursor position |
| `:RecolorBrowse` | Browse all highlight groups with fuzzy search |
| `:RecolorEdited` | View only groups you've modified |
| `:RecolorUndo` | Undo all tweaks for current colorscheme |

## Default Keymaps

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>cc` | `:Recolor` | Curated highlight groups |
| `<leader>ci` | `:RecolorInspect` | Inspect at cursor |
| `<leader>ca` | `:RecolorBrowse` | All groups (fuzzy search) |
| `<leader>ce` | `:RecolorEdited` | Edited groups only |

You can customize or disable these in setup:

```lua
require('recolor').setup({
  keymaps = {
    categories = '<leader>cc',  -- or false to disable
    inspect = '<leader>ci',
    browse = '<leader>ca',
    edited = '<leader>ce',
  },
})
```

## Picker Controls

![Picker](https://imgur.com/TlLsGpV)

### Standard Mode (curated, inspect, edited views)

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate groups |
| `,` / `.` | Shift hue left/right |
| `[` / `]` | Darken / brighten |
| `{` / `}` | Desaturate / saturate |
| `Tab` / `S-Tab` | Cycle channel (fg → bg → sp) |
| `#` | Enter hex color directly |
| `y` | Copy hex to clipboard |
| `p` | Paste hex from clipboard |
| `u` | Undo tweaks for this group |
| `U` | Undo all tweaks (edited view only) |
| `q` / `Esc` | Close |

### Browse Mode (all 600+ groups)

In browse mode, all letters filter the list. Commands use Ctrl:

| Key | Action |
|-----|--------|
| (type) | Filter groups |
| `<C-j>` / `<C-k>` | Navigate |
| `<C-y>` | Copy hex |
| `<C-p>` | Paste hex |
| `<C-u>` | Undo tweaks |
| `<C-c>` | Clear search |
| `Esc` | Close |

Color adjustment keys (`,`/`.`/`[`/`]`/`{`/`}`) work the same in both modes.

## Configuration

```lua
require('recolor').setup({
  -- Adjustment step sizes
  brightness_step = 0.05,  -- 5% per keypress
  hue_step = 10,           -- 10 degrees per keypress
  saturation_step = 0.05,  -- 5% per keypress

  -- Where to save tweaks
  -- Default: ~/.config/nvim/recolor.json (trackable in your dotfiles)
  tweaks_path = nil,  -- or vim.fn.stdpath('data') .. '/recolor.json'

  -- Keymaps (false to disable)
  keymaps = {
    categories = '<leader>cc',
    inspect = '<leader>ci',
    browse = '<leader>ca',
    edited = '<leader>ce',
  },
})
```

## How Colors Are Stored

Tweaks persist in a JSON file, organized by colorscheme:

```json
{
  "catppuccin-mocha": {
    "Normal": { "bg": "#1a1a2e" },
    "Comment": { "fg": "#7c7c9c" }
  },
  "tokyonight": {
    "CursorLine": { "bg": "#292e42" }
  }
}
```

This means:
- Switch colorschemes freely — each has its own tweaks
- Tweaks auto-apply when Neovim starts or when you `:colorscheme`
- Store in `~/.config/nvim/` to track with your dotfiles, or in `stdpath('data')` to keep separate

## Understanding HSL

The plugin adjusts colors in HSL (Hue, Saturation, Lightness) space:

| Component | What It Does | Keys |
|-----------|--------------|------|
| **Hue** | The color itself — red → orange → yellow → green → cyan → blue → purple → red | `,` `.` |
| **Lightness** | How light or dark — black ↔ white | `[` `]` |
| **Saturation** | How vivid — gray ↔ pure color | `{` `}` |

## UI Reference

```
╭─ Recolor ─────────────────────────────────────────╮
│ j/k:move  ,/.:hue  [/]:bright  {/}:sat            │
│ Tab:channel  y:copy  p:paste  u:undo  #:hex  q:quit│
│                                                   │
│ Base UI                                           │
│   •Normal              [bg]#1e1e2e█               │
│    NormalFloat         [bg]#313244█               │
│ > •CursorLine          [bg]#45475a█               │
│                                                   │
╰───────────────────────────────────────────────────╯
```

- `>` marks the selected group
- `•` indicates saved tweaks for this group
- `[bg]` shows active channel (fg/bg/sp)
- `█` colored block shows actual color value

## Use Cases

**Initial colorscheme setup** — Browse through groups, adjust what bothers you, done. Your tweaks persist.

**On-the-fly adjustments** — Working late and the bright background hurts? Dim it. Reading code with low-contrast comments? Boost them. Takes seconds.

**Experimenting** — Try wild color changes. If you don't like them, `u` undoes per-group, `:RecolorUndo` undoes everything.

**Finding what to tweak** — Not sure which highlight group controls something? `<leader>ci` on it, and you'll see exactly which groups affect that text.

## Health Check

Run `:checkhealth recolor` to verify the plugin is set up correctly.

## Acknowledgments

This plugin was developed with substantial assistance from [Claude Code](https://claude.ai/code), Anthropic's AI coding assistant. The Lua implementation, color manipulation algorithms, and overall architecture were shaped through collaborative development. The idea, design decisions, and testing were human-driven.

## Related Projects

- [lush.nvim](https://github.com/rktjmp/lush.nvim) — Create colorschemes with real-time feedback
- [colorbuddy.nvim](https://github.com/tjdevries/colorbuddy.nvim) — Colorscheme helper with color relationships
- [nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) — Highlight color codes in buffers

## License

MIT
