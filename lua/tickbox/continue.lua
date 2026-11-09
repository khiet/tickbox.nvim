-- Continues a task list onto a new line. `newline` and `open` return keys for an expr
-- mapping: the plain key off a task line, or a <Cmd> that writes the new line through
-- the API on one. Writing the whole line replaces any leader 'formatoptions' inserted, so
-- a plugin that continues lists itself cannot double the marker.
local render = require("tickbox.render")
local tree = require("tickbox.tree")

local M = {}

-- The cursor line and its task, or nil when the line cannot be continued: not a task,
-- an ordered task, fenced, in a filetype that is not configured, or not modifiable.
-- Like toggling, this ignores `disable`.
local function cursor_task()
  if not vim.bo.modifiable or not render.is_attached() then
    return nil
  end
  local task = tree.get(0).tasks[vim.api.nvim_win_get_cursor(0)[1]]
  if not task or task.ordered then
    return nil
  end
  return vim.api.nvim_get_current_line(), task
end

-- The new line's prefix, such as "  - [ ] ": the indentation and marker that open the
-- task's prefix range, then an unchecked box. The marker is one character because
-- ordered tasks never get here.
local function prefix(line, task)
  return line:sub(1, task.prefix_start + 1) .. " [ ] "
end

-- Internal, reached through the <Cmd> `newline` returns. Expects what `newline` checked:
-- the cursor line is a task and the cursor sits past its closing bracket.
function M._newline()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line, task = cursor_task()
  -- An empty task ends the list rather than piling up more.
  if line:sub(task.prefix_end + 1):match("^%s*$") then
    vim.api.nvim_set_current_line("")
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    return
  end
  local head = prefix(line, task)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line:sub(1, col), head .. line:sub(col + 1) })
  vim.api.nvim_win_set_cursor(0, { row + 1, #head })
end

-- Internal, reached through the <Cmd> `open` returns. Runs in insert mode on the line `o`
-- or `O` just opened, so the edit joins that insert's undo step. Overwrites whatever
-- indent or leader the opened line was given.
function M._fill(head)
  vim.api.nvim_set_current_line(head)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], #head })
end

function M.newline()
  local line, task = cursor_task()
  -- Splitting before the task text would leave a second prefix in front of the first.
  if not line or vim.api.nvim_win_get_cursor(0)[2] <= task.prefix_end then
    return "<CR>"
  end
  return "<Cmd>lua require('tickbox.continue')._newline()<CR>"
end

-- `key` is "o" or "O". Off a task line it is returned as is, so a count still applies.
function M.open(key)
  local line, task = cursor_task()
  if not line then
    return key
  end
  return ("%s<Cmd>lua require('tickbox.continue')._fill(%q)<CR>"):format(key, prefix(line, task))
end

return M
