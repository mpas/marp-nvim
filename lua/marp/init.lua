local cli = require("marp.cli")
local config = require("marp.config")
local install = require("marp.install")
local lazy = require("marp.lazy")
local marp = require("marp.marp")

local M = {}

M.setup = config.setup
M.start = marp.start
M.open = marp.open
M.stop = marp.stop
M.status = marp.status
M.toggle = marp.toggle
M.install = install.sync

local function register_commands()
  if vim.g.marp_commands_registered then
    return
  end
  vim.g.marp_commands_registered = true

  vim.api.nvim_create_user_command("MarpStart", M.start, { desc = "Start Marp" })
  vim.api.nvim_create_user_command("MarpOpen", M.open, { desc = "Open Marp preview in the browser" })
  vim.api.nvim_create_user_command("MarpStop", M.stop, { desc = "Stop Marp" })
  vim.api.nvim_create_user_command("MarpStatus", M.status, { desc = "Show Marp status" })
  vim.api.nvim_create_user_command("MarpToggle", M.toggle, { desc = "Toggle Marp (start/stop)" })

  if cli.needs_install() then
    vim.api.nvim_create_user_command("MarpInstall", function(opts)
      local ok, err = install.sync(opts.args ~= "" and opts.args or nil)
      if ok then
        vim.notify("Marp CLI is installed", vim.log.levels.INFO)
        pcall(vim.api.nvim_del_user_command, "MarpInstall")
      else
        vim.notify("Marp install failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
      end
    end, { desc = "Install bundled Marp CLI", nargs = "?" })
  end
end

function M.setup(options)
  config.setup(options)
  vim.g.marp_lazy_opts_applied = true
  register_commands()
end

lazy.apply()
register_commands()

return M
