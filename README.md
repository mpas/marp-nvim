# 🔌 Marp.nvim
A [neovim](https://neovim.io/) plugin for [Marp](https://marp.app/).

## ✨ Features
- start/stop the Marp server
- toggle the Marp server (start/stop)
- see if Marp server is running
- browser window opens when Marp is running and ready
- automatically installs Marp CLI into the plugin when needed
- opens the preview in your system browser, or optionally in a dedicated Chromium-based window (`preview_browser`)

## ⚡️ Requirements

- [Node.js](https://nodejs.org/) v18+ and `npm` (for automatic Marp CLI installation)
- Alternatively, install [Marp CLI](https://marp.app/) globally and the plugin will use it from your `PATH`

## 📦 Installation

Install the plugin with your preferred package manager:

Packer:
```lua
  use({
    "alexesba/marp-nvim",
    cmd = { "MarpStart", "MarpOpen", "MarpStop", "MarpToggle", "MarpStatus" },
    config = true,
    run = function()
      require("marp").install()
    end,
  }),
```

Lazy (recommended — load on `:MarpStart` and related commands, or on Markdown buffers with `ft`):

```lua
  {
    "alexesba/marp-nvim",
    cmd = { "MarpStart", "MarpOpen", "MarpStop", "MarpToggle", "MarpStatus" },
    ft = "markdown", -- optional: also load when opening a Markdown buffer
    build = function(plugin)
      require("marp").install(plugin.dir)
    end,
    config = true,
  },
```

With lazy.nvim `opts` (no separate `config` function needed):

```lua
  {
    "alexesba/marp-nvim",
    cmd = { "MarpStart", "MarpOpen", "MarpStop", "MarpToggle", "MarpStatus" },
    opts = {
      preview_browser = "dedicated",
    },
    build = function(plugin)
      require("marp").install(plugin.dir)
    end,
  },
```

If Marp CLI is not found on your `PATH` and is not yet installed in the plugin, `:MarpInstall` is registered automatically so you can install it manually.

## ⚙️ Configuration

The following defaults are provided:

```lua
{
  port = 8080, -- the port on which the Marp server should listen
  wait_for_response_timeout = 30, -- how long to wait for a response from the server before giving up
  wait_for_response_delay = 1, -- how long to wait between attempts to connect to the server
  marp_command = nil, -- override Marp executable; nil auto-resolves PATH, bundled, then npx
  auto_install = true, -- install @marp-team/marp-cli into plugin deps when missing
  use_npx_fallback = true, -- use npx when marp is not on PATH and bundled install is unavailable
  marp_version = "latest", -- npx package version when falling back to npx
  preview_browser = "system", -- "system" | "dedicated" (isolated browser; closes on :MarpStop)
  dedicated_browser = nil, -- optional; nil auto-detects Chrome/Chromium/Edge via PATH (exepath)
  dedicated_preview_profile = nil, -- optional; nil uses a temp marp-nvim-preview profile
  preview_host = nil, -- browser preview hostname; nil auto-detects (WSL uses the VM IP)
  server_dir = nil, -- directory passed to marp --server; nil uses resolve_server_dir()
  use_buffer_dir = true, -- serve the current Markdown buffer's directory instead of cwd
}
```

Marp CLI resolution order when `marp_command` is not set:

1. `marp` on your `PATH`
2. Bundled install in the plugin's `deps/` directory
3. Auto-install into `deps/` if `auto_install` is true
4. `npx @marp-team/marp-cli@<marp_version>` if `use_npx_fallback` is true

### Server directory in large projects

By default, `:MarpStart` runs `marp --server` on the **current Markdown buffer's directory**, not Neovim's working directory. This avoids serving an entire repository (for example a Rails app root with `node_modules/`, `tmp/`, and thousands of files).

Override when needed:

```lua
require("marp").setup({
  server_dir = "/path/to/slides", -- always serve this directory
  use_buffer_dir = false,         -- use vim.fn.getcwd() instead of the buffer path
})
```

### Preview browser

Two modes:

| `preview_browser` | `:MarpStart` | `:MarpStop` |
|---|---|---|
| `"system"` (default) | Opens in your OS default browser | Stops Marp only; the tab stays open |
| `"dedicated"` | Opens Chrome/Chromium/Edge in a temp profile | Stops Marp and closes that browser window |

**System** (default) matches Marp CLI: simple tab open, no cleanup on stop.

**Dedicated** launches an isolated Chromium-based browser on **WSL, macOS, and Linux** with the same behavior:

- App mode (`--app=...`) — no address bar, single window
- Temporary profile — no bookmarks bar, no bookmark import
- `:MarpStop` closes the preview window and sanitizes the profile

You usually only need:

```lua
require("marp").setup({
  preview_browser = "dedicated",
})
```

No browser path configuration is required — the plugin auto-detects a suitable browser (see below).

How dedicated mode works:

1. Marp runs on `port` (default `8080`)
2. A Chromium-based browser opens in **app mode** (`--app=...`) with `--user-data-dir=.../marp-nvim-preview` — no address bar, no bookmarks bar, and a single window without an extra blank tab
3. `:MarpStop` kills only processes using that profile (presenter popups included)
4. The profile is sanitized after each stop so the browser does not show a "Restore pages" prompt on the next preview

If you close the preview window by mistake while Marp is still running, run `:MarpOpen` or `:MarpStart` again to reopen it.

Dedicated mode requires a **Chromium-based** browser (Chrome, Chromium, or Edge). Safari and Firefox are not supported.

#### Browser auto-detection

When `dedicated_browser` is **not** set, the plugin finds a browser automatically on every platform.

Lookup order:

1. `google-chrome-stable`
2. `google-chrome`
3. `chromium-browser`
4. `chromium`
5. `microsoft-edge-stable`
6. `microsoft-edge`

Each name is resolved from your `PATH` via Neovim's `exepath` (equivalent to `which`).

On **macOS**, these application paths are also checked:

- `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
- `/Applications/Chromium.app/Contents/MacOS/Chromium`
- `/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge`

On **WSL**, Microsoft Edge under `/mnt/c/Program Files/...` is checked if nothing is found on `PATH`.

Default profile directory:

| Platform | Default `--user-data-dir` |
|---|---|
| WSL | `%TEMP%\marp-nvim-preview` (Windows temp) |
| macOS / Linux | `$TMPDIR/marp-nvim-preview` |

If auto-detection fails, the plugin logs a warning and falls back to your system default browser.

#### Optional overrides

Set these only when auto-detection fails or you want a specific browser or profile path:

```lua
require("marp").setup({
  preview_browser = "dedicated",
  dedicated_browser = "/usr/bin/google-chrome-stable",
  dedicated_preview_profile = "/tmp/marp-nvim-preview", -- on WSL use a Windows path, e.g. C:\\Temp\\marp-nvim-preview
})
```

On **WSL**, the preview URL uses the WSL VM IP so Windows can reach the server (see below).

### WSL (Windows)

Neovim in WSL opens the preview in your **Windows** browser. `127.0.0.1` in WSL is not reachable from Windows, so the plugin uses the WSL VM IP for preview URLs.

On WSL the plugin automatically:

1. Opens the browser using the WSL VM IP (from `hostname -I`)
2. With `preview_browser = "dedicated"`, launches a dedicated Chromium-based browser window (same behavior as macOS/Linux)

If auto-detection fails, set the host manually:

```lua
require("marp").setup({
  preview_host = "172.21.17.252", -- output of: hostname -I | awk '{print $1}'
})
```

## ⌨️ Keybindings
This plugin does not set any keybindings by default. You can set them yourself like this:

```lua
vim.keymap.set("n", "<leader>MT", "<cmd>MarpToggle<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>MS", "<cmd>MarpStatus<cr>", { noremap = true, silent = true })
...
```

The following commands are available:
- `:MarpStart` - start the Marp server (reopens the preview if already running)
- `:MarpOpen` - open the preview in the browser while the server is running
- `:MarpStop` - stop the Marp server
- `:MarpToggle` - toggle the Marp server (start/stop)
- `:MarpStatus` - see if Marp server is running
- `:MarpInstall [plugin_dir]` - install the bundled Marp CLI (only registered when Marp is not already available); optionally pass a custom plugin directory to install into, mainly useful for advanced/internal setups, otherwise the plugin's own directory is used

## 🎨 Theming
Marp CLI can recognize custom themes that are in the `themes/` directory in your project's root directory. For example, if you open neovim in the `presentations` directory, created a directory inside of `presentations` called `themes` and place the theme CSS files inside of this directory. They should be automatically loaded by Marp and applied to presentations with the theme specified.

## 💡Inspiration

This plugin is inspired by [aca/marp.nvim](https://github.com/aca/marp.nvim) and [mpas/marp-nvim](https://github.com/mpas/marp-nvim)!
