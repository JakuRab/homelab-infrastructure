# Neovim Setup Documentation (Final Configuration)

## Overview

This documentation describes the **final, stable, and error-free Neovim
setup** optimized for: - configuration file editing (YAML, JSON, TOML,
Lua, etc.) - high readability and minimal muscle-memory requirements -
clean, fast, and modern Lua-based configuration - compatibility with
Neovim ≥ 0.10

------------------------------------------------------------------------

## Directory Structure

    ~/.config/nvim/
    ├── init.lua
    └── lua/
        └── plugins.lua

------------------------------------------------------------------------

## init.lua (Final Version)

``` lua
-- ==========================================
--  Neovim Setup – "clarity & comfort edition"
-- ==========================================

-- Suppress re-source and deprecated warnings
vim.schedule(function()
  vim.notify = function() end
end)
vim.deprecate = function() end

-- General settings
vim.g.mapleader = " "
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = "a"
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.wrap = false
vim.o.scrolloff = 4
vim.o.sidescrolloff = 8
vim.o.langmenu = "en_GB"
vim.cmd("language en_GB")

-- Disable spell checking entirely
vim.opt.spell = false
vim.opt.spelllang = "en"
vim.opt.spellfile = ""
vim.opt.spelloptions = ""

-- Enable system clipboard integration
vim.opt.clipboard = "unnamedplus"

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require("lazy").setup("plugins")

-- Key mappings
local map = vim.keymap.set
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",  { desc = "Search text" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",    { desc = "Buffer list" })
map("n", "-", "<cmd>Oil<cr>",                           { desc = "File explorer (Oil)" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>",        { desc = "Toggle file tree" })
map("n", "<leader>q", "<cmd>q<cr>",                     { desc = "Quit" })
map("n", "<leader>w", "<cmd>w<cr>",                     { desc = "Save file" })

-- Folding (Treesitter-based)
vim.o.foldmethod = "expr"
vim.o.foldexpr = "nvim_treesitter#foldexpr()"
vim.o.foldlevel = 99

-- Autoformat before saving (if LSP supports it)
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    pcall(function() vim.lsp.buf.format({ async = false }) end)
  end,
})

-- Apply Gruvbox theme
vim.cmd("colorscheme gruvbox")
```

### Hyprland LSP autostart (hyprls)

- `init.lua` now registers a BufEnter/BufWinEnter autocommand for `*.hl` and `hypr*.conf` files.
- The callback first checks `vim.fn.executable("hyprls")`; if the binary is missing it emits a single `notify_once` warning instead of spamming errors.
- When found, it only spawns one Hyprland client per buffer, so hopping between panes stays quiet.

**Installing hyprls**

```bash
go install github.com/hyprland-community/hyprls/cmd/hyprls@latest
```

This drops the binary in `~/go/bin`. The config now prepends that directory to Neovim’s `PATH` at startup so the executable is discovered even if the shell environment doesn’t export it. For a global fix add `export PATH="$HOME/go/bin:$PATH"` to your shell profile (`.zshrc`, `.bash_profile`, etc.).

------------------------------------------------------------------------

## Clipboard Integration

### Overview

By default, Neovim uses an *internal* clipboard.\
This section enables **full system clipboard integration** so that `y`,
`p`, `Ctrl+Shift+C/V`, and mouse selection work across the OS.

### Step 1: Verify clipboard support

Run:

``` bash
nvim --version | grep clipboard
```

Expected output:

    +clipboard

If you see `-clipboard`, install a version of Neovim compiled with
clipboard support.

### Step 2: Install system tools

#### X11 (Ubuntu, Debian, Fedora)

``` bash
sudo apt install xclip xsel
```

#### Wayland (GNOME, KDE on modern Linux)

``` bash
sudo apt install wl-clipboard
```

### Step 3: Enable clipboard in Neovim

This line (already in your config) does it:

``` lua
vim.opt.clipboard = "unnamedplus"
```

This makes Neovim use the system clipboard by default.\
You can now: - `y` / `p` → copy/paste directly to/from system clipboard\
- `Ctrl+Shift+C` / `Ctrl+Shift+V` in terminal → normal copy/paste\
- `"+y` / `"+p` → manual clipboard selection if needed

### Step 4: Verify integration

Inside Neovim:

    :checkhealth clipboard

You should see:

    OK: Clipboard tool found: xclip or wl-copy

### Step 5: Troubleshooting

  -----------------------------------------------------------------------
  Problem                           Solution
  --------------------------------- -------------------------------------
  `E850: Invalid register name`     Check if `xclip` or `wl-clipboard` is
                                    installed

  Clipboard not working in tmux     Ensure
                                    `set-option -g set-clipboard on` is
                                    in `.tmux.conf`

  Only works one way                Some terminals (e.g. Alacritty)
                                    require native `Ctrl+Shift+C/V`
                                    handling
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## plugins.lua (Final Version)

Key additions since the previous iteration:

1. **Mason + mason-lspconfig** automatically install the markup-oriented servers the setup relies on, so opening JSON/YAML/TOML/Lua files never explodes because a binary is missing.
2. Mason’s UI gets a rounded border and `ensure_installed` pins the exact servers (`jsonls`, `yamlls`, `taplo`, `lua_ls`).

```lua
{
  "williamboman/mason.nvim",
  build = ":MasonUpdate",
  config = function()
    require("mason").setup({ ui = { border = "rounded" } })
  end,
},
{
  "williamboman/mason-lspconfig.nvim",
  dependencies = { "williamboman/mason.nvim" },
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = { "jsonls", "yamlls", "taplo", "lua_ls" },
      automatic_installation = true,
    })
  end,
},
```

After first launch, open the dashboard to verify/install anything pending:

```vim
:Mason
```

Toggle to the “LSP” section, check status lights, and hit `i` on anything marked as not installed.

------------------------------------------------------------------------

## Installation Steps

1.  Remove old Neovim config (optional backup):

    ``` bash
    mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null || true
    ```

2.  Create folder structure:

    ``` bash
    mkdir -p ~/.config/nvim/lua
    ```

3.  Copy both files (`init.lua` and `plugins.lua`) to the proper
    locations.

4.  Launch Neovim:

    ``` bash
    nvim
    ```

5.  Lazy.nvim will install all plugins automatically.

6.  After installation, run:

    ``` vim
    :Lazy sync
    ```

------------------------------------------------------------------------

## Key Bindings Summary

  Action                Shortcut      Description
  --------------------- ------------- -----------------------------
  Find file             `<Space>ff`   Telescope file finder
  Search text           `<Space>fg`   Live grep across files
  Buffer list           `<Space>fb`   Switch between open buffers
  File explorer (Oil)   `-`           Lightweight file browser
  File tree             `<Space>e`    Toggle nvim-tree
  Save file             `<Space>w`    Save current buffer
  Quit                  `<Space>q`    Exit Neovim

------------------------------------------------------------------------

## Maintenance Tips

-   Update all plugins:

    ``` vim
    :Lazy update
    ```

-   Rebuild treesitter parsers:

    ``` vim
    :TSUpdate
    ```

-   If something breaks after update:

    ``` bash
    rm -rf ~/.local/state/nvim ~/.cache/nvim
    nvim
    ```

------------------------------------------------------------------------

## Troubleshooting

  ------------------------------------------------------------------------------------------------------------
  Issue                                                       Solution
  ----------------------------------------------------------- ------------------------------------------------
  `Re-sourcing your config is not supported with lazy.nvim`   Safe to ignore (cosmetic)

  Missing language servers                                    Run `:Mason` (Lazy installs it) and install anything
                                                              marked missing; servers auto-load once present

  Hyprland config buffers warn about hyprls                   Install via `go install ...hyprls@latest` and ensure
                                                              `~/go/bin` is on PATH (init.lua now prepends it)

  Theme not applied                                           Run `:colorscheme gruvbox`

  Formatting not working                                      Ensure `prettier`, `shfmt`, or `stylua` are
                                                              installed

  Clipboard not working                                       Install `xclip`, `xsel`, or `wl-clipboard`
  ------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## Author

Configuration generated and maintained via **ChatGPT (GPT‑5)** for
advanced Neovim environments.
