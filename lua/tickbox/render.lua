-- Draws task boxes with a decoration provider. Marks are ephemeral, so they exist
-- only for the redraw that placed them: there is nothing to clear or keep in sync,
-- and text changes, undo, :e, folds and scrolling are covered by redraws alone.
local parse = require("tickbox.parse")

local M = {}

local ns = vim.api.nvim_create_namespace("tickbox")
local group = vim.api.nvim_create_augroup("tickbox", { clear = true })

local config
-- Buffers whose filetype is in config.filetypes. Keyed by buffer number.
local attached = {}
-- Per buffer: { tick = changedtick, rows = parse.fenced result for that tick }.
local fences = {}

local function refresh(buf)
  attached[buf] = vim.tbl_contains(config.filetypes, vim.bo[buf].filetype) or nil
end

local function define_highlights()
  -- default = true so a colorscheme or user definition wins.
  vim.api.nvim_set_hl(0, "TickboxUnchecked", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "TickboxChecked", { link = "DiagnosticOk", default = true })
end

-- A fence can open anywhere above the viewport, so this reads the whole buffer. The
-- cache limits that to once per buffer change rather than once per redraw.
local function fenced_rows(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = fences[buf]
  if not cached or cached.tick ~= tick then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    cached = { tick = tick, rows = parse.fenced(lines) }
    fences[buf] = cached
  end
  return cached.rows
end

local function draw(buf, row)
  if fenced_rows(buf)[row + 1] then
    return
  end
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local task = line and parse.classify(line)
  if not task then
    return
  end

  local checked = task.state == "checked"
  local icon = checked and config.icons.checked or config.icons.unchecked
  -- Pad to the prefix's width so the task text stays in its raw column.
  local padding = (task.prefix_end - task.prefix_start) - vim.fn.strdisplaywidth(icon)
  vim.api.nvim_buf_set_extmark(buf, ns, row, task.prefix_start, {
    ephemeral = true,
    virt_text = {
      { icon, checked and "TickboxChecked" or "TickboxUnchecked" },
      { string.rep(" ", math.max(padding, 0)) },
    },
    virt_text_pos = "overlay",
    -- Otherwise a horizontally scrolled line keeps the glyph at the window edge,
    -- on top of task text.
    virt_text_hide = true,
    -- Lets cursorline and similar backgrounds show through the padding.
    hl_mode = "combine",
  })
end

-- Safe to call repeatedly; the latest config replaces the previous one.
function M.start(cfg)
  config = cfg
  define_highlights()

  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      refresh(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      attached[args.buf] = nil
      fences[args.buf] = nil
    end,
  })

  -- Buffers opened before the plugin loaded missed their FileType event.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh(buf)
  end

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, buf)
      return attached[buf] == true
    end,
    on_line = function(_, _, buf, row)
      draw(buf, row)
    end,
  })
end

return M
