-- Keeps the cursor off text the plugin hides, so it moves as if only what is drawn were
-- there: a link's label, and the Compact box as one character. Neovim lets the cursor rest
-- on concealed bytes and draws it at the next shown cell, so `l` off a label or the box
-- would seem to stall once per hidden byte.
local buffers = require("tickbox.buffers")
local conceal = require("tickbox.conceal")
local tree = require("tickbox.tree")

local M = {}

local group = vim.api.nvim_create_augroup("tickbox_cursor", { clear = true })

-- By window, where the cursor was after the last move, { buf, row, col }. Gives the
-- direction of a move, which decides the side of the link the cursor lands on.
local last = {}

-- The byte where the character holding 0-indexed byte `col` starts.
local function char_start(line, col)
  return col + vim.str_utf_start(line, col + 1)
end

-- Where the cursor goes from 0-indexed `col`, or nil to leave it. `direction` is "right",
-- "left", or nil for arriving from another line. Loops because skipping one hidden range
-- can land in the next.
--
-- Links: a move right or left carries on past the hidden text the way it was going, except
-- right off a link that ends the line, which stops on the label; an arrival settles on the
-- label's nearer end.
--
-- `prefix`, when the Compact box is drawn, is { start, stop, step }: the box's byte, the
-- space after the prefix, and whether the move was one byte right off the box. The cursor
-- rests on the prefix only at the box. A step lands on the space, since that is the next
-- cell drawn; any longer move right was aimed past the prefix, so it lands on the text,
-- or on the space when the task has none. Everything else lands on the box.
local function resolve(line, links, prefix, col, direction)
  local moved
  for _ = 1, #links + 2 do
    local target
    if prefix and col > prefix.start and col < prefix.stop then
      if direction ~= "right" then
        target = prefix.start
      elseif prefix.step or prefix.stop + 1 >= #line then
        target = prefix.stop
      else
        target = prefix.stop + 1
      end
    end
    for _, link in ipairs(links) do
      if target then
        break
      end
      if col >= link.start and col < link.label_start then
        if direction == "left" and link.start > 0 then
          target = char_start(line, link.start - 1)
        else
          target = link.label_start
        end
      elseif col >= link.label_end and col < link.stop then
        if direction == "right" and link.stop < #line then
          target = link.stop
        else
          target = char_start(line, link.label_end - 1)
        end
      end
    end
    if not target or target == col then
      return moved
    end
    col, moved = target, target
  end
  return moved
end

local function on_moved()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local previous = last[win]
  last[win] = { buf = buf, row = row, col = col }

  if not buffers.is_enabled(buf) then
    return
  end
  local task = tree.get(buf).tasks[row]
  if not task then
    return
  end
  local links = conceal.hides_cursor_links(win, buf) and task.links or {}
  local compact = conceal.draws_cursor_compact(win, buf)
  if #links == 0 and not compact then
    return
  end
  local direction
  if previous and previous.buf == buf and previous.row == row then
    direction = col > previous.col and "right" or "left"
  end
  local prefix = compact
    and {
      start = task.prefix_start,
      stop = task.prefix_end,
      step = direction == "right" and previous.col == task.prefix_start and col == task.prefix_start + 1,
    }
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
  local target = resolve(line, links, prefix, col, direction)
  if target then
    vim.api.nvim_win_set_cursor(win, { row, target })
    last[win].col = target
  end
end

-- Safe to call repeatedly.
function M.start()
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = on_moved,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      last[tonumber(args.match)] = nil
    end,
  })
end

return M
