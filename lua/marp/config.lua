local M = {}

local defaults = {
  port = 8080, -- the port on which the Marp server should listen
}

M.options = {}

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
