local util = require("marp/util")
local config = require("marp/config")

local M = {}
M.jobid = 0

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
  if not util.dir_contains_md_files(vim.fn.getcwd()) then
    util.log_info("no Markdown files found, exiting!")
    return
  end

  if marp_running() then
    util.log_info("already running")
    return
  end

  local port = config.options.port
  local wait_for_response_timeout = config.options.wait_for_response_timeout
  local wait_for_response_delay = config.options.wait_for_response_delay

  local marp_start_command = "PORT=" .. port .. " marp --server " .. vim.fn.getcwd()

  util.log_info("starting server on http://localhost:" .. port)

  M.jobid = vim.fn.jobstart(marp_start_command, {
    on_exit = function(_, exit_code, _)
      M.jobid = 0
      util.log_info("exit (code=" .. exit_code .. ")")
    end,
  })

  util.wait_for_response("http://localhost:" .. port, wait_for_response_timeout, wait_for_response_delay)
  util.open_url_in_browser("http://localhost:" .. port)
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
  vim.fn.jobstop(M.jobid)
  M.jobid = 0
  util.log_info("server stopped")
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
