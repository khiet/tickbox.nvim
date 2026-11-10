local buffers = require("tickbox.buffers")
local fold = require("tickbox.fold")
local conceal = require("tickbox.conceal")
local render = require("tickbox.render")
local state = require("tickbox.state")
local toggle = require("tickbox.toggle")

local M = {}

local default_icons = {}
for name, entry in pairs(state.states) do
  default_icons[name] = entry.icon
end

local defaults = {
  filetypes = { "markdown" },
  icons = default_icons,
  -- Draws done/total at the end of parent task and heading lines.
  progress = false,
  -- After a toggle or cycle, checks an ancestor whose counted descendants are all
  -- checked and unchecks a checked one whose are not.
  auto_check_parent = false,
  -- Folds headings that have tasks. Off leaves every fold option untouched.
  fold = false,
  -- Draws inline links on task lines as their label.
  links = true,
  -- Draws the box one space from the task text instead of padded to the prefix's width.
  -- With this and `links` both off, no window option is changed and the treesitter
  -- highlighter is left alone.
  compact = true,
}

local started = false

-- Optional. Each call starts from the defaults rather than the previous call's options.
-- `filetypes` replaces the default list; `icons` may set any subset of the four glyphs.
function M.setup(opts)
  if vim.fn.has("nvim-0.10") == 0 then
    error("tickbox.nvim requires Neovim 0.10 or later", 0)
  end
  buffers.setup(vim.tbl_deep_extend("force", defaults, opts or {}))
  fold.start()
  conceal.start()
  render.start()
  started = true
end

-- Internal, for plugin/tickbox.lua. A plugin manager may source that file after the
-- user's init called setup, which must not be overwritten with the defaults.
function M._ensure_started()
  if not started then
    M.setup()
  end
end

M.enable = buffers.enable
M.disable = buffers.disable
M.is_enabled = buffers.is_enabled
M.toggle = toggle.toggle
M.toggle_range = toggle.toggle_range
M.cycle = toggle.cycle
M.cycle_range = toggle.cycle_range
M.set = toggle.set
M.set_range = toggle.set_range

return M
