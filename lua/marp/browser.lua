local config = require("marp.config")
local util = require("marp.util")

local M = {}

local PROFILE_DIR_NAME = "marp-nvim-preview"

local WSL_EDGE_PATHS = {
  "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe",
}

local PATH_BROWSER_NAMES = {
  "google-chrome-stable",
  "google-chrome",
  "chromium-browser",
  "chromium",
  "microsoft-edge-stable",
  "microsoft-edge",
}

local MAC_BROWSER_PATHS = {
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
}

M._dedicated_open = false

--- Marker string embedded in the --user-data-dir path for process cleanup.
function M.profile_marker()
  return PROFILE_DIR_NAME
end

function M.platform()
  if util.is_wsl() then
    return "wsl"
  end
  if vim.fn.has("mac") == 1 then
    return "mac"
  end
  if vim.fn.has("unix") == 1 then
    return "unix"
  end
  return "other"
end

--- Convert a Windows path (C:\foo) to a WSL /mnt/c/foo path.
function M.win_to_wsl(path)
  path = path:gsub("\r", ""):gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if path == "" then
    return nil
  end

  local drive, rest = path:match("^(%a):(.*)$")
  if not drive then
    return nil
  end

  rest = rest:gsub("\\", "/")
  if rest:sub(1, 1) ~= "/" then
    rest = "/" .. rest
  end

  return "/mnt/" .. drive:lower() .. rest
end

function M.windows_temp_dir()
  local result = vim.system({ "cmd.exe", "/c", "echo", "%TEMP%" }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout then
    return nil
  end

  local temp = result.stdout:gsub("\r", ""):gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if temp == "" or temp:match("%%") then
    return nil
  end

  return temp
end

function M.default_profile_dir_win()
  local temp = M.windows_temp_dir()
  if not temp then
    return nil
  end

  local sep = temp:sub(-1) == "\\" and "" or "\\"
  return temp .. sep .. PROFILE_DIR_NAME
end

function M.default_profile_dir_unix()
  local tmp = vim.env.TMPDIR or vim.env.TEMP or "/tmp"
  if tmp:sub(-1) == "/" then
    tmp = tmp:sub(1, -2)
  end

  return tmp .. "/" .. PROFILE_DIR_NAME
end

--- Profile path passed to the browser (--user-data-dir). Windows-style on WSL.
function M.profile_launch_path()
  local opts = config.options
  if opts.dedicated_preview_profile and opts.dedicated_preview_profile ~= "" then
    return opts.dedicated_preview_profile
  end

  if M.platform() == "wsl" then
    return M.default_profile_dir_win()
  end

  return M.default_profile_dir_unix()
end

--- Profile path for reading/writing preference files from Neovim.
function M.profile_fs_path()
  local launch_path = M.profile_launch_path()
  if M.platform() == "wsl" then
    return M.win_to_wsl(launch_path) or launch_path
  end

  return launch_path
end

--- Chromium flags for a dedicated preview profile (app mode: no URL bar, single window).
function M.dedicated_launch_flags(profile, url)
  return {
    "--user-data-dir=" .. profile,
    "--no-first-run",
    "--no-default-browser-check",
    "--hide-crash-restore-bubble",
    "--disable-sync",
    "--app=" .. url,
  }
end

local function default_preferences()
  return {
    bookmark_bar = { show_on_all_tabs = false },
    browser = { show_bookmark_bar = false },
    distribution = {
      import_bookmarks = false,
      skip_first_run_ui = true,
    },
    profile = {
      exit_type = "Normal",
      exited_cleanly = true,
    },
  }
end

local function patch_preferences_table(prefs)
  prefs.bookmark_bar = prefs.bookmark_bar or {}
  prefs.bookmark_bar.show_on_all_tabs = false
  prefs.browser = prefs.browser or {}
  prefs.browser.show_bookmark_bar = false
  prefs.distribution = prefs.distribution or {}
  prefs.distribution.import_bookmarks = false
  prefs.distribution.skip_first_run_ui = true
  prefs.profile = prefs.profile or {}
  prefs.profile.exited_cleanly = true
  prefs.profile.exit_type = "Normal"
  return prefs
end

local function write_preferences(path, prefs)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local file = io.open(path, "w")
  if not file then
    return
  end
  file:write(vim.json.encode(prefs))
  file:close()
end

local function prepare_preferences_file(path)
  local file = io.open(path, "r")
  if not file then
    write_preferences(path, default_preferences())
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, prefs = pcall(vim.json.decode, content)
  if ok and type(prefs) == "table" then
    write_preferences(path, patch_preferences_table(prefs))
    return
  end

  content = content:gsub('"exited_cleanly"%s*:%s*false', '"exited_cleanly":true')
  content = content:gsub('"exit_type"%s*:%s*"[^"]*"', '"exit_type":"Normal"')
  content = content:gsub('"show_on_all_tabs"%s*:%s*true', '"show_on_all_tabs":false')
  content = content:gsub('"show_bookmark_bar"%s*:%s*true', '"show_bookmark_bar":false')
  content = content:gsub('"import_bookmarks"%s*:%s*true', '"import_bookmarks":false')

  file = io.open(path, "w")
  if not file then
    return
  end
  file:write(content)
  file:close()
end

local function sanitize_local_state(path)
  local file = io.open(path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  content = content:gsub('"exited_cleanly"%s*:%s*false', '"exited_cleanly":true')
  content = content:gsub('"exit_type"%s*:%s*"[^"]*"', '"exit_type":"Normal"')

  file = io.open(path, "w")
  if not file then
    return
  end
  file:write(content)
  file:close()
end

function M.prepare_chromium_profile(profile_dir, separator)
  separator = separator or "/"
  prepare_preferences_file(profile_dir .. separator .. "Default" .. separator .. "Preferences")
  sanitize_local_state(profile_dir .. separator .. "Local State")
end

function M.prepare_dedicated_profile()
  local fs_path = M.profile_fs_path()
  if fs_path then
    M.prepare_chromium_profile(fs_path, "/")
  end
end

local function resolve_on_path(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  return nil
end

local function readable(path)
  return vim.fn.executable(path) == 1 or vim.fn.filereadable(path) == 1
end

function M.find_dedicated_executable()
  local opts = config.options
  if opts.dedicated_browser and opts.dedicated_browser ~= "" then
    if readable(opts.dedicated_browser) then
      return opts.dedicated_browser
    end
  end

  for _, name in ipairs(PATH_BROWSER_NAMES) do
    local path = resolve_on_path(name)
    if path then
      return path
    end
  end

  for _, path in ipairs(MAC_BROWSER_PATHS) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  if M.platform() == "wsl" then
    for _, path in ipairs(WSL_EDGE_PATHS) do
      if vim.fn.filereadable(path) == 1 then
        return path
      end
    end
  end

  return nil
end

function M.uses_dedicated_preview()
  return config.options.preview_browser == "dedicated"
end

function M.dedicated_supported()
  local platform = M.platform()
  return platform == "wsl" or platform == "mac" or platform == "unix"
end

--- Whether :MarpStop will close a dedicated preview browser instance.
function M.closes_on_stop()
  return M.uses_dedicated_preview() and M.dedicated_supported()
end

function M.kill_dedicated_processes()
  local platform = M.platform()
  if platform == "wsl" then
    local ps = string.format(
      [[Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*%s*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }]],
      PROFILE_DIR_NAME
    )
    vim.system({
      "powershell.exe",
      "-NoProfile",
      "-Command",
      ps,
    }, { text = true }):wait()
    return
  end

  if platform == "mac" or platform == "unix" then
    vim.system({ "pkill", "-f", PROFILE_DIR_NAME }, { text = true }):wait()
  end
end

function M.open_dedicated(url, opts)
  opts = opts or {}

  if not M.dedicated_supported() then
    return false, "dedicated preview is not supported on this platform"
  end

  local browser = M.find_dedicated_executable()
  if not browser then
    return false, "Chromium-based browser not found (try dedicated_browser)"
  end

  local profile = M.profile_launch_path()
  if not profile then
    return false, "could not resolve dedicated preview profile directory"
  end

  if not opts.reopen then
    M.close_dedicated()
  else
    M._dedicated_open = false
  end

  M.prepare_dedicated_profile()

  local argv = vim.list_extend({ browser }, M.dedicated_launch_flags(profile, url))
  local jobid = vim.fn.jobstart(argv, { detach = true })
  if jobid <= 0 then
    return false, "failed to launch dedicated browser"
  end

  M._dedicated_open = true
  return true
end

function M.close_dedicated()
  M._dedicated_open = false
  M.kill_dedicated_processes()
  M.prepare_dedicated_profile()
end

--- Open the Marp preview in a browser appropriate for the current platform.
---@param url string
---@param opts? { reopen?: boolean }
function M.open_preview(url, opts)
  opts = opts or {}

  if M.uses_dedicated_preview() then
    local ok, err = M.open_dedicated(url, opts)
    if ok then
      return true
    end
    util.log_warn((err or "could not open dedicated browser") .. "; using system browser")
  end

  util.open_url_in_browser(url)
  return true
end

--- Close a dedicated preview browser when preview_browser = "dedicated".
function M.close_preview()
  if M.closes_on_stop() then
    M.close_dedicated()
  end
end

function M.dedicated_open()
  return M._dedicated_open
end

return M
