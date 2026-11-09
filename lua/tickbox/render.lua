-- Draws task boxes with a decoration provider. Marks are ephemeral, so they exist
-- only for the redraw that placed them: there is nothing to clear or keep in sync,
-- and text changes, undo, :e, folds and scrolling are covered by redraws alone.
local state = require("tickbox.state")
local tree = require("tickbox.tree")

local M = {}

local ns = vim.api.nvim_create_namespace("tickbox")
local group = vim.api.nvim_create_augroup("tickbox", { clear = true })

local config
-- Buffers whose filetype is in config.filetypes. Keyed by buffer number.
local attached = {}
-- Buffers turned off with `disable`. Separate from `attached` so the choice survives the
-- FileType event a :e reload fires, and lasts until `enable` or the buffer is wiped.
local disabled = {}
-- Buffers with an nvim_buf_attach listener, which repaints when progress counts change.
-- Each holds `counts`, the tree.counts table the listener last saw.
local watched = {}
-- The line left raw for typing in insert or replace mode, { win, buf, row }. Nil when
-- not typing or when the current buffer is not attached.
local revealed
-- Whether TickboxCheckedText has any styling, read once per window redraw. An extmark
-- with an empty group still changes the screen attributes, so it is skipped then.
local style_checked_text = false

-- An edit repaints only the lines it touched, but a count sits on a parent or heading
-- line that may be elsewhere. So any change to the counts repaints the buffer's windows.
local function watch(buf)
  if watched[buf] or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local watch_state = {}
  watched[buf] = watch_state
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if not (config.progress and attached[buf]) then
        watched[buf] = nil
        return true
      end
      local counts = tree.get(buf).counts
      if not vim.deep_equal(counts, watch_state.counts) then
        watch_state.counts = counts
        vim.api.nvim__redraw({ buf = buf, valid = false })
      end
    end,
    on_detach = function()
      watched[buf] = nil
    end,
  })
end

local function refresh(buf)
  attached[buf] = vim.tbl_contains(config.filetypes, vim.bo[buf].filetype) or nil
  if attached[buf] and config.progress then
    watch(buf)
  end
end

local function define_highlights()
  -- default = true so a colorscheme or user definition wins.
  for _, name in ipairs(state.order) do
    local entry = state.states[name]
    vim.api.nvim_set_hl(0, entry.highlight, { link = entry.link, default = true })
  end
  -- Empty so done text looks unchanged until the user defines it.
  vim.api.nvim_set_hl(0, "TickboxCheckedText", { default = true })
  vim.api.nvim_set_hl(0, "TickboxProgress", { link = "Comment", default = true })
end

local function draw_progress(buf, row)
  local count = tree.get(buf).counts[row + 1]
  if count then
    vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
      ephemeral = true,
      virt_text = { { ("%d/%d"):format(count.done, count.total), "TickboxProgress" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end
end

local function draw(buf, row)
  -- A fence can open anywhere above the viewport, so the task needs the whole buffer;
  -- the tree caches that per buffer change rather than per redraw.
  local task = tree.get(buf).tasks[row + 1]
  if not task then
    return
  end

  local icon = config.icons[task.state]
  -- Pad to the prefix's width so the task text stays in its raw column.
  local padding = (task.prefix_end - task.prefix_start) - vim.fn.strdisplaywidth(icon)
  vim.api.nvim_buf_set_extmark(buf, ns, row, task.prefix_start, {
    ephemeral = true,
    virt_text = {
      { icon, state.states[task.state].highlight },
      { string.rep(" ", math.max(padding, 0)) },
    },
    virt_text_pos = "overlay",
    -- Otherwise a horizontally scrolled line keeps the glyph at the window edge,
    -- on top of task text.
    virt_text_hide = true,
    -- Lets cursorline and similar backgrounds show through the padding.
    hl_mode = "combine",
  })

  -- Starts past the space that ends the prefix, so a strikethrough begins at the text.
  local text_start = task.prefix_end + 1
  if style_checked_text and state.is_done(task.state) and text_start < task.length then
    vim.api.nvim_buf_set_extmark(buf, ns, row, text_start, {
      ephemeral = true,
      end_col = task.length,
      hl_group = "TickboxCheckedText",
    })
  end
end

-- nvim__redraw is experimental, but nothing public repaints a single line and it is
-- what lets a mode change avoid repainting the whole window.
local function repaint(target)
  if target and vim.api.nvim_buf_is_valid(target.buf) then
    vim.api.nvim__redraw({ buf = target.buf, range = { target.row, target.row + 1 } })
  end
end

local function current_target()
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  local buf = vim.api.nvim_get_current_buf()
  if (mode == "i" or mode == "R") and attached[buf] then
    local win = vim.api.nvim_get_current_win()
    return { win = win, buf = buf, row = vim.api.nvim_win_get_cursor(win)[1] - 1 }
  end
end

-- Neither a mode change nor moving the cursor repaints a line by itself, so both the
-- line being left and the line being entered are invalidated here.
local function update_revealed()
  local previous = revealed
  revealed = current_target()
  if vim.deep_equal(previous, revealed) then
    return
  end
  repaint(previous)
  repaint(revealed)
end

local function resolve(buf)
  return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
end

-- Whether the buffer's filetype is configured, regardless of `disable`.
function M.is_attached(buf)
  return attached[resolve(buf)] == true
end

-- Whether the buffer renders: its filetype is configured and it has not been disabled.
function M.is_enabled(buf)
  buf = resolve(buf)
  return attached[buf] == true and not disabled[buf]
end

local function set_disabled(buf, value)
  buf = resolve(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error("Tickbox: invalid buffer: " .. tostring(buf), 0)
  end
  disabled[buf] = value
  vim.api.nvim__redraw({ buf = buf, valid = false })
end

-- Clears `disable`. A buffer whose filetype is not configured still does not render.
function M.enable(buf)
  set_disabled(buf, nil)
end

function M.disable(buf)
  set_disabled(buf, true)
end

-- The options from the latest `start`.
function M.options()
  return config
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
      disabled[args.buf] = nil
      tree.forget(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMovedI" }, {
    group = group,
    callback = update_revealed,
  })

  -- Buffers opened before the plugin loaded missed their FileType event.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh(buf)
  end

  -- setup may run mid-insert, where no mode change or cursor move follows.
  update_revealed()

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, buf)
      local hl = vim.api.nvim_get_hl(0, { name = "TickboxCheckedText" })
      hl.default = nil
      style_checked_text = next(hl) ~= nil
      return M.is_enabled(buf)
    end,
    on_line = function(_, win, buf, row)
      -- Eol text covers nothing, so counts stay on the line being typed.
      if config.progress then
        draw_progress(buf, row)
      end
      if not (revealed and revealed.win == win and revealed.row == row) then
        draw(buf, row)
      end
    end,
  })
end

return M
