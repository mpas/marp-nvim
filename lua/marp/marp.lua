local browser = require("marp.browser")
local cli = require("marp.cli")
local config = require("marp.config")
local lazy = require("marp.lazy")
local util = require("marp.util")

local M = {}
M.jobid = 0
M._intentional_stop = false

local exit_cleanup_registered = false

local function ensure_exit_cleanup()
  if exit_cleanup_registered then
    return
  end
  exit_cleanup_registered = true

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("MarpExit", { clear = true }),
    callback = function()
      M.shutdown()
    end,
  })
end

local function stop_jobs()
  M._intentional_stop = true

  browser.close_preview()

  if M.jobid > 0 then
    pcall(vim.fn.jobstop, M.jobid)
    M.jobid = 0
  end
end

local function on_job_exit(_, exit_code, _)
  M.jobid = 0

  browser.close_preview()

  if M._intentional_stop then
    M._intentional_stop = false
    return
  end

  if exit_code ~= 0 then
    util.log_warn("server exited unexpectedly (code=" .. exit_code .. ")")
  end
end

local function marp_running()
  return M.jobid ~= 0
end

--[[
    Toggles the Marp server.
    @usage
    ```lua
    local marp = require("marp")
    marp.toggle()
    ```
]]
function M.toggle()
  if marp_running() then
    M.stop()
  else
    M.start()
  end
end

--[[
    Starts the Marp server.
    @usage
    ```lua
    local marp = require("marp")
    marp.start()
    ```
]]
function M.start()
  lazy.apply()

  local server_dir = util.resolve_server_dir()

  if not util.can_start_server() then
    local dir = util.display_server_dir(server_dir)
    local where = dir == "/." and "the current directory" or dir
    util.log_warn("no markdown files found in " .. where)
    return
  end

  if marp_running() then
    M.open()
    return
  end

  local port = config.options.port
  local wait_for_response_timeout = config.options.wait_for_response_timeout
  local wait_for_response_delay = config.options.wait_for_response_delay

  local argv, env, err = cli.server_argv(port, server_dir)
  if not argv then
    util.log_error(err or "could not resolve Marp CLI")
    return
  end

  util.log_info(
    "starting server on http://localhost:" .. port .. " (" .. util.display_server_dir(server_dir) .. ")"
  )

  M.jobid = vim.fn.jobstart(argv, {
    env = env,
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = on_job_exit,
  })

  if M.jobid <= 0 then
    util.log_error("failed to start Marp server")
    return
  end

  ensure_exit_cleanup()

  if not util.wait_for_response(util.local_url(port), wait_for_response_timeout, wait_for_response_delay) then
    stop_jobs()
    return
  end

  browser.open_preview(util.preview_url(port))
end

--[[
    Opens the Marp preview in the browser when the server is already running.
    Useful after accidentally closing a dedicated preview window.
    @usage
    ```lua
    local marp = require("marp")
    marp.open()
    ```
]]
function M.open()
  lazy.apply()

  if not marp_running() then
    util.log_info("not running; use :MarpStart")
    return
  end

  local port = config.options.port
  if not util.wait_for_response(util.local_url(port), 5, 0.2) then
    util.log_warn("server not responding")
    return
  end

  browser.open_preview(util.preview_url(port), { reopen = true })
  util.log_info("preview opened")
end

--[[
    Stops the Marp server.
    @usage
    ```lua
    local marp = require("marp")
    marp.stop()
    ```
]]
function M.stop()
  if M.jobid == 0 then
    util.log_info("not running")
    return
  end

  stop_jobs()
  util.log_info("server stopped")
end

--[[
    Stops Marp silently when Neovim exits.
]]
function M.shutdown()
  if M.jobid == 0 and not browser.dedicated_open() then
    return
  end

  stop_jobs()
end

--[[
    Logs the status of the Marp server.
    @usage
    ```lua
    local marp = require("marp")
    marp.status()
    ```
]]
function M.status()
  if M.jobid == 0 then
    util.log_info("not running")
  else
    util.log_info("running")
  end
end

return M
