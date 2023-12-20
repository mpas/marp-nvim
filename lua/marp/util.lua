local M = {}

--[[
    Opens a URL in a browser.
    @param url (string) The URL to open.
    @usage
    ```lua
    local browser = require("marp/browser")
    browser.open("https://example.com")
    ```
]]
function M.open_url_in_browser(url)
  -- Construct the shell command to open the URL in a browser based on the OS
  local open_cmd = nil
  if vim.fn.has("mac") == 1 then
    open_cmd = "open"
  elseif vim.fn.has("unix") == 1 then
    open_cmd = "xdg-open"
  elseif vim.fn.has("win32") == 1 then
    open_cmd = "start"
  else
    error("Unsupported operating system")
    return
  end

  -- Execute the shell command to open the URL in a browser
  local cmd = string.format("%s %s", open_cmd, url)
  vim.api.nvim_command("! " .. cmd)
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
    local browser = require("marp/browser")
    browser.wait_for_response("https://example.com", 5, 1)
    ```
]]
function M.wait_for_response(url, max_attempts, delay_between_attempts)
  local attempts = 0
  local server_responded = false

  while attempts < max_attempts and not server_responded do
    local success = false
    local response = vim.fn.systemlist('curl -s -o /dev/null -w "%{http_code}" ' .. url)

    if response[1] == "200" then
      success = true
    end

    if success then
      print("Server responded successfully!")
      server_responded = true
    else
      attempts = attempts + 1
      print("Attempt", attempts, "- Server not yet responding. Retrying in", delay_between_attempts, "seconds...")
      M.wait(1)
    end
  end
end

--[[
    Logs a message to the Vim command line.
    @param msg (string) The message to log.
    @param hl (string) The highlight group to use for the message.
    @usage
    ```lua
    local util = require("marp/util")
    util.log("Hello, world!", "InfoMsg")
    ```
]]
function M.log(msg, hl)
  vim.api.nvim_echo({ { "Marp: ", hl }, { msg } }, true, {})
end

--[[
    Logs an informational message to the Vim command line.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp/util")
    util.log_info("Hello, world!")
    ```
]]
function M.log_info(msg)
  M.log(msg, "InfoMsg")
end

--[[
    Logs a warning message to the Vim command line.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp/util")
    util.log_warn("Hello, world!")
    ```
]]
function M.log_warn(msg)
  M.log(msg, "WarningMsg")
end

--[[
    Logs an error message to the Vim command line.
    @param msg (string) The message to log.
    @usage
    ```lua
    local util = require("marp/util")
    util.log_error("Hello, world!")
    ```
]]
function M.log_error(msg)
  M.log(msg, "ErrorMsg")
end

return M
