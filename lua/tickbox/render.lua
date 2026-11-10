-- Draws task boxes with a decoration provider. Marks are ephemeral, so they exist
-- only for the redraw that placed them: there is nothing to clear or keep in sync,
-- and text changes, undo, :e, folds and scrolling are covered by redraws alone.
local buffers = require("tickbox.buffers")
local fold = require("tickbox.fold")
local conceal = require("tickbox.conceal")
local state = require("tickbox.state")
local tree = require("tickbox.tree")

local M = {}

local ns = vim.api.nvim_create_namespace("tickbox")
local group = vim.api.nvim_create_augroup("tickbox", { clear = true })

-- Buffers with an nvim_buf_attach listener, which acts when counts or fold levels change.
-- Each holds `counts` and `folds`, the tree tables the listener last saw.
local watched = {}
-- The line left raw for typing in insert or replace mode, { win, buf, row }. Nil when
-- not typing or when the current buffer is not attached.
local revealed
-- Whether TickboxCheckedText has any styling, read once per window redraw. An extmark
-- with an empty group still changes the screen attributes, so it is skipped then.
local style_checked_text = false
-- What may be hidden in the window being redrawn, from `conceal.view`.
local view

local function needs_watch(buf)
  local options = buffers.options()
  return (options.progress or options.fold) and buffers.is_attached(buf)
end

-- An edit repaints only the lines it touched, but a count sits on a parent or heading
-- line that may be elsewhere. So any change to the counts repaints the buffer's windows,
-- and any change to the fold levels refreshes their folds, which go stale the same way.
local function watch(buf)
  if watched[buf] or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local watch_state = { folds = tree.get(buf).folds }
  watched[buf] = watch_state
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, _, first, last, new_last)
      if not needs_watch(buf) then
        watched[buf] = nil
        return true
      end
      local options = buffers.options()
      local current = tree.get(buf)
      -- Tracked with the option off too, so turning it on later has a true baseline.
      if not vim.deep_equal(current.folds, watch_state.folds) then
        if options.fold then
          fold.update(buf, watch_state.folds, current.folds, first, last, new_last)
        end
        watch_state.folds = current.folds
      end
      if options.progress and not vim.deep_equal(current.counts, watch_state.counts) then
        watch_state.counts = current.counts
        vim.api.nvim__redraw({ buf = buf, valid = false })
      end
    end,
    on_detach = function()
      watched[buf] = nil
    end,
  })
end

local function watch_if_needed(buf)
  if needs_watch(buf) then
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
  -- Underline reads as a link, where bold would look like **strong**.
  vim.api.nvim_set_hl(0, "TickboxLink", { link = "Underlined", default = true })
  -- Internal, so not `default`. Treesitter reads `[/]` and `[-]` as links, not task
  -- markers, and hl_mode "combine" would keep their underline under the padding.
  -- nocombine drops inherited attributes while a cursorline background still shows.
  vim.api.nvim_set_hl(0, "TickboxPadding", { nocombine = true })
end

local function draw_progress(win, buf, row)
  local current = tree.get(buf)
  local lnum = row + 1
  local count = current.counts[lnum]
  if not count then
    return
  end
  local text = ("%d/%d"):format(count.done, count.total)
  local mark = {
    ephemeral = true,
    virt_text = { { text, "TickboxProgress" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  }

  local col = fold.closed_count_col(win, buf, lnum)
  if col then
    mark.virt_text = { { " " }, { text, "TickboxProgress" } }
    mark.virt_text_pos = "overlay"
    mark.virt_text_win_col = col
  end
  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, mark)
end

local function draw_links(buf, row, task)
  if #task.links == 0 or not view.links then
    return
  end
  for _, link in ipairs(task.links) do
    for _, hidden in ipairs({
      { link.start, link.label_start },
      { link.label_end, link.stop },
    }) do
      vim.api.nvim_buf_set_extmark(buf, ns, row, hidden[1], {
        ephemeral = true,
        end_col = hidden[2],
        conceal = "",
      })
    end
    vim.api.nvim_buf_set_extmark(buf, ns, row, link.label_start, {
      ephemeral = true,
      end_col = link.label_end,
      hl_group = "TickboxLink",
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

  local icon = buffers.options().icons[task.state]
  local icon_end = task.prefix_start + vim.fn.strdisplaywidth(icon)
  local virt_text = { { icon, state.states[task.state].highlight } }
  if view.hides(row) then
    -- Compact: the rest of the prefix is removed, so the text starts one space after
    -- the icon. An icon as wide as the prefix leaves nothing to remove.
    if icon_end < task.prefix_end then
      vim.api.nvim_buf_set_extmark(buf, ns, row, icon_end, {
        ephemeral = true,
        end_col = task.prefix_end,
        conceal = "",
      })
    end
  else
    -- Pad to the prefix's width, so no raw bracket shows beside the icon and the task
    -- text stays in its raw column.
    local padding = string.rep(" ", math.max(task.prefix_end - icon_end, 0))
    table.insert(virt_text, { padding, "TickboxPadding" })
  end
  vim.api.nvim_buf_set_extmark(buf, ns, row, task.prefix_start, {
    ephemeral = true,
    virt_text = virt_text,
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

  draw_links(buf, row, task)
end

-- nvim__redraw is experimental, but nothing public repaints a single line and it is
-- what lets a mode change avoid repainting the whole window.
--
-- In a window with 'conceallevel' above 0, a repaint during the mode change leaves the
-- cursor at its concealed column on the raw line until the next move, so it waits until
-- the mode change is over.
local function repaint(target)
  if not target then
    return
  end
  local function redraw()
    if vim.api.nvim_buf_is_valid(target.buf) then
      vim.api.nvim__redraw({ buf = target.buf, range = { target.row, target.row + 1 } })
    end
  end
  if vim.api.nvim_win_is_valid(target.win) and vim.wo[target.win].conceallevel > 0 then
    vim.schedule(redraw)
  else
    redraw()
  end
end

local function current_target()
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  local buf = vim.api.nvim_get_current_buf()
  if (mode == "i" or mode == "R") and buffers.is_attached(buf) then
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

-- Safe to call repeatedly. Expects `buffers.setup` to have run first, so the options
-- exist and its FileType autocmd fires before the one defined here.
function M.start()
  define_highlights()

  vim.api.nvim_clear_autocmds({ group = group })
  -- A colorscheme's `hi clear` restores only default links, which would lose
  -- TickboxPadding and bring back the underline it hides.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = define_highlights,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      watch_if_needed(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      tree.forget(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMovedI" }, {
    group = group,
    callback = update_revealed,
  })

  -- Buffers opened before the plugin loaded missed their FileType event.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    watch_if_needed(buf)
  end

  -- setup may run mid-insert, where no mode change or cursor move follows.
  update_revealed()

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf)
      conceal.check(win, buf)
      view = conceal.view(win, buf)
      local hl = vim.api.nvim_get_hl(0, { name = "TickboxCheckedText" })
      hl.default = nil
      style_checked_text = next(hl) ~= nil
      return buffers.is_enabled(buf)
    end,
    on_line = function(_, win, buf, row)
      -- Eol text covers nothing, so counts stay on the line being typed.
      if buffers.options().progress then
        draw_progress(win, buf, row)
      end
      if not (revealed and revealed.win == win and revealed.row == row) then
        draw(buf, row)
      end
    end,
  })
end

return M
