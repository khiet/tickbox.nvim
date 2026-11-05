local parse = require("tickbox.parse")

local M = {}

-- Flips the task on the cursor line. Returns true if the line was edited and false if
-- it is not a task, so a mapping can fall through to another action.
function M.toggle()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  -- Fence state only depends on the lines above, so the rest need not be read.
  local lines = vim.api.nvim_buf_get_lines(0, 0, row + 1, false)
  if parse.fenced(lines)[row + 1] then
    return false
  end
  local task = parse.classify(lines[row + 1])
  if not task then
    return false
  end
  local interior = task.state == "checked" and " " or "x"
  vim.api.nvim_buf_set_text(0, row, task.interior_start, row, task.interior_end, { interior })
  return true
end

-- Target of 'operatorfunc'. Going through an operator is what lets `.` repeat the toggle.
function M.operator()
  M.toggle()
end

return M
