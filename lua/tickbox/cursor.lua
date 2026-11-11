-- Keeps the cursor off a link's hidden text, so it moves as if only the label were there.
-- Neovim lets the cursor rest on concealed bytes and draws it at the next shown cell, so
-- `l` off a label would seem to stall once per hidden byte.
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

-- Where the cursor goes from 0-indexed `col`, or nil to leave it. Moving right skips past
-- the link; moving left, or arriving from another line, settles on the label's nearer end.
-- Loops because skipping one link can land on the hidden text of the next.
local function resolve(line, links, col, rightward)
  local moved
  for _ = 1, #links + 1 do
    local target
    for _, link in ipairs(links) do
      if col >= link.start and col < link.label_start then
        if not rightward and link.start > 0 then
          target = char_start(line, link.start - 1)
        else
          target = link.label_start
        end
      elseif col >= link.label_end and col < link.stop then
        if rightward and link.stop < #line then
          target = link.stop
        else
          target = char_start(line, link.label_end - 1)
        end
      end
      if target then
        break
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

  if not buffers.is_enabled(buf) or not conceal.hides_cursor_links(win, buf) then
    return
  end
  local task = tree.get(buf).tasks[row]
  if not task or #task.links == 0 then
    return
  end
  local rightward = previous ~= nil and previous.buf == buf and previous.row == row and col > previous.col
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
  local target = resolve(line, task.links, col, rightward)
  if target then
    vim.api.nvim_win_set_cursor(win, { row, target })
    last[win].col = target
  end
end

-- Safe to call repeatedly. Expects `buffers.setup` to have run first.
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
