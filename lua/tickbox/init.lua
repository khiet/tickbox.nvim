local render = require("tickbox.render")
local toggle = require("tickbox.toggle")

local M = {}

local defaults = {
  filetypes = { "markdown" },
  icons = {
    unchecked = "󰄱",
    in_progress = "\u{F0856}",
    checked = "󰱒",
    cancelled = "\u{F0157}",
  },
}

local started = false

-- Optional. Each call starts from the defaults rather than the previous call's options.
-- `filetypes` replaces the default list; `icons` may set any subset of the four glyphs.
function M.setup(opts)
  if vim.fn.has("nvim-0.10") == 0 then
    error("tickbox.nvim requires Neovim 0.10 or later", 0)
  end
  render.start(vim.tbl_deep_extend("force", defaults, opts or {}))
  started = true
end

-- Internal, for plugin/tickbox.lua. A plugin manager may source that file after the
-- user's init called setup, which must not be overwritten with the defaults.
function M._ensure_started()
  if not started then
    M.setup()
  end
end

M.enable = render.enable
M.disable = render.disable
M.is_enabled = render.is_enabled
M.toggle = toggle.toggle
M.toggle_range = toggle.toggle_range
M.cycle = toggle.cycle
M.cycle_range = toggle.cycle_range

return M
