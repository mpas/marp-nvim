local config = require("marp/config")
local marp = require("marp/marp")

local M = {}

M.setup = config.setup
M.start = marp.start
M.stop = marp.stop
M.status = marp.status
M.toggle = marp.toggle

return M
