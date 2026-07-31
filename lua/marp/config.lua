local M = {}

local defaults = {
  port = 8080, -- the port on which the Marp server should listen
  wait_for_response_timeout = 30, -- how long to wait for a response from the server before giving up
  wait_for_response_delay = 1, -- how long to wait between attempts to connect to the server
  marp_command = nil, -- override Marp executable; nil auto-resolves PATH, bundled, then npx
  auto_install = true, -- install @marp-team/marp-cli into plugin deps when missing
  use_npx_fallback = true, -- use npx when marp is not on PATH and bundled install is unavailable
  marp_version = "latest", -- npx package version when falling back to npx
  preview_browser = "system", -- "system" | "dedicated" (isolated browser; closes on :MarpStop)
  dedicated_browser = nil, -- optional; nil auto-detects Chrome/Chromium/Edge via PATH (exepath)
  dedicated_preview_profile = nil, -- optional; nil uses a temp marp-nvim-preview profile
  preview_host = nil, -- browser preview hostname; nil auto-detects (WSL uses the VM IP)
  server_dir = nil, -- directory passed to marp --server; nil uses resolve_server_dir()
  use_buffer_dir = true, -- serve the current Markdown buffer's directory instead of cwd
}

M.options = {}

local function normalize_preview_browser(opts)
  if opts.preview_browser ~= "system" and opts.preview_browser ~= "dedicated" then
    vim.notify(
      'marp-nvim: invalid preview_browser "' .. tostring(opts.preview_browser) .. '"; using "system"',
      vim.log.levels.WARN
    )
    opts.preview_browser = "system"
  end
end

function M.setup(options)
  local opts = vim.tbl_deep_extend("force", {}, defaults, options or {})
  normalize_preview_browser(opts)
  M.options = opts
end

M.setup()

return M
