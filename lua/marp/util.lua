local M = {}

--- Whether Neovim is running inside WSL (Windows browser is opened via wslview).
function M.is_wsl()
  if vim.fn.has("wsl") == 1 then
    return true
  end

  local version_file = io.open("/proc/version", "r")
  if not version_file then
    return false
  end

  local version = version_file:read("*a") or ""
  version_file:close()
  return version:lower():match("microsoft") ~= nil
end

--- First IPv4 address of the WSL instance (reachable from the Windows host).
function M.wsl_ip()
  local result = vim.system({ "hostname", "-I" }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout then
    return nil
  end

  return result.stdout:match("%S+")
end

--- Hostname used in preview URLs opened in the browser.
function M.preview_host()
  local opts = require("marp.config").options
  if opts.preview_host and opts.preview_host ~= "" then
    return opts.preview_host
  end

  if M.is_wsl() then
    return M.wsl_ip() or "127.0.0.1"
  end

  return "127.0.0.1"
end

--- Build a browser-facing preview URL for the given port.
function M.preview_url(port)
  return "http://" .. M.preview_host() .. ":" .. port .. "/"
end

--- Local URL for health checks from inside Neovim's environment.
function M.local_url(port, path)
  path = path or "/"
  return "http://127.0.0.1:" .. port .. path
end

--[[
    Opens a URL in a browser.
    @param url (string) The URL to open.
    @usage
    ```lua
    local browser = require("marp.browser")
    browser.open("https://example.com")
    ```
]]
function M.open_url_in_browser(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end

  if vim.fn.has("mac") == 1 then
    vim.fn.jobstart({ "open", url }, { detach = true })
  elseif vim.fn.has("unix") == 1 then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  elseif vim.fn.has("win32") == 1 then
    vim.fn.jobstart({ "cmd", "/c", "start", "", url }, { detach = true })
  else
    M.log_error("unsupported operating system")
  end
end

--[[
    Delays execution for a specified number of seconds.

    @param seconds (number) The number of seconds to wait.
    @usage
    ```lua
    print("Waiting for 3 seconds...")
    _wait(3)
    print("Done waiting!")
    ```
]]
function M.wait(seconds)
  local start = os.clock()
  while os.clock() - start <= seconds do
  end
end

--[[
    Waits for a server to respond to a request.

    @param url (string) The URL to request.
    @param max_attempts (number) The maximum number of times to attempt the request.
    @param delay_between_attempts (number) The number of seconds to wait between attempts.
    @usage
    ```lua
    local browser = require("marp.browser")
    browser.wait_for_response("https://example.com", 5, 1)
    ```
]]
function M.wait_for_response(url, max_attempts, delay_between_attempts)
  local null_device = vim.fn.has("win32") == 1 and "NUL" or "/dev/null"

  for attempt = 1, max_attempts do
    local result = vim.system({
      "curl",
      "-s",
      "-o",
      null_device,
      "-w",
      "%{http_code}",
      url,
    }, { text = true }):wait()

    if result.stdout == "200" then
      return true
    end

    if attempt < max_attempts then
      M.wait(delay_between_attempts)
    end
  end

  M.log_warn("server did not respond in time")
  return false
end

--[[]
    Resolves the directory to pass to `marp --server`.
    Prefers the current Markdown buffer's directory over cwd so large projects
    (e.g. Rails repos) are not served from the repository root.
]]
function M.resolve_server_dir()
  local opts = require("marp.config").options

  if opts.server_dir then
    return vim.fn.fnamemodify(opts.server_dir, ":p")
  end

  if opts.use_buffer_dir then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= "" and vim.bo.filetype == "markdown" then
      local dir = vim.fn.fnamemodify(bufname, ":p:h")
      if vim.fn.isdirectory(dir) == 1 then
        return dir
      end
    end
  end

  return vim.fn.getcwd()
end

function M.can_start_server()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" and vim.bo.filetype == "markdown" and vim.fn.filereadable(bufname) == 1 then
    return true
  end

  return M.dir_contains_md_files(M.resolve_server_dir())
end

--- Path relative to cwd for display (e.g. `/slides` instead of the full absolute path).
function M.display_server_dir(server_dir)
  local function strip_slash(path)
    if path:sub(-1) == "/" then
      return path:sub(1, -2)
    end
    return path
  end

  local abs_cwd = strip_slash(vim.fn.fnamemodify(vim.fn.getcwd(), ":p"))
  local abs_dir = strip_slash(vim.fn.fnamemodify(server_dir, ":p"))

  if abs_dir == abs_cwd then
    return "/."
  end

  if vim.fs and vim.fs.relpath then
    local rel, err = vim.fs.relpath(abs_dir, abs_cwd)
    if rel and not err and not rel:match("^%.%.") then
      rel = strip_slash(rel)
      if rel ~= "" then
        return "/" .. rel
      end
    end
  end

  if abs_dir:sub(1, #abs_cwd) == abs_cwd then
    local suffix = abs_dir:sub(#abs_cwd + 1):gsub("^/", "")
    if suffix ~= "" then
      return "/" .. suffix
    end
  end

  return "/" .. vim.fn.fnamemodify(abs_dir, ":t")
end

--[[]
    Determines whether a directory contains Markdown files.
    @param current_dir (string) The directory to check.
    @return (boolean) Whether the directory contains Markdown files.
    @usage
    ```lua
    local util = require("marp.util")
    local contains_md_files = util.dir_contains_md_files(vim.fn.getcwd())
    ```
]]
function M.dir_contains_md_files(current_dir)
  local files = vim.fn.readdir(current_dir)
  for _, file in ipairs(files) do
    if file ~= "." and file ~= ".." then
      local path = current_dir .. "/" .. file
      local is_file = vim.fn.isdirectory(path)

      if is_file == 0 and file:match("%.md$") then
        return true
      end
    end
  end
  return false
end

local hl_to_level = {
  InfoMsg = vim.log.levels.INFO,
  WarningMsg = vim.log.levels.WARN,
  ErrorMsg = vim.log.levels.ERROR,
}

--[[
    Logs a message via vim.notify when available, otherwise the command line.
    @param msg (string) The message to log.
    @param hl (string) The highlight group to use for command-line fallback.
    @usage
    ```lua
    local util = require("marp.util")
    util.log("Hello, world!", "InfoMsg")
    ```
]]
function M.log(msg, hl)
  if vim.notify then
    vim.notify(msg, hl_to_level[hl] or vim.log.levels.INFO, { title = "Marp" })
    return
  end

  vim.api.nvim_echo({ { "Marp: ", hl }, { msg } }, true, {})
end

--[[
    Logs an informational message.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp.util")
    util.log_info("Hello, world!")
    ```
]]
function M.log_info(msg)
  M.log(msg, "InfoMsg")
end

--[[
    Logs a warning message.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp.util")
    util.log_warn("Hello, world!")
    ```
]]
function M.log_warn(msg)
  M.log(msg, "WarningMsg")
end

--[[
    Logs an error message.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp.util")
    util.log_error("Hello, world!")
    ```
]]
function M.log_error(msg)
  M.log(msg, "ErrorMsg")
end

return M
