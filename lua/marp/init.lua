local config = require("marp/config")
local marp = require("marp/marp")

local M = {}

M.setup = config.setup
M.start = marp.start
M.stop = marp.stop
M.status = marp.status
M.toggle = marp.toggle

-- create MarpStart command
vim.api.nvim_create_user_command("MarpStart", M.start, { desc = "Start Marp" })
vim.api.nvim_create_user_command("MarpStop", M.stop, { desc = "Stop Marp" })
vim.api.nvim_create_user_command("MarpStatus", M.status, { desc = "Show Marp status" })
vim.api.nvim_create_user_command("MarpToggle", M.toggle, { desc = "Toggle Marp (start/stop)" })

return M
