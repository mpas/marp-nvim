local util = require("marp/util")
local config = require("marp/config")

local M = {}
M.jobid = 0

local function _is_marp_running()
  return M.jobid ~= 0
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
  if _is_marp_running() then
    util.log_info("already running")
    return
  end

  local port = config.options.port

  local marp_start_command = "PORT=" .. port .. " marp --server " .. vim.fn.getcwd()

  util.log_info("starting server on http://localhost:" .. port)

  M.jobid = vim.fn.jobstart(marp_start_command, {
    on_exit = function(_, exit_code, _)
      M.jobid = 0
      util.log_info("exit (code=" .. exit_code .. ")")
    end,
  })

  util.wait_for_response("http://localhost:" .. port, 30, 1)
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
    Returns the status of the Marp server.
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
