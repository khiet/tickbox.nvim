local parse = require("tickbox.parse")

local M = {}

-- Flips every task on lines `first` through `last` (1-indexed, inclusive). Returns true
-- if any line was edited. Returns false when none were: only non-task or fenced lines,
-- or a nomodifiable buffer. All edits from one call are one undo step.
function M.toggle_range(first, last)
  if not vim.bo.modifiable then
    return false
  end
  -- Fence state only depends on the lines above, so the rest need not be read.
  local lines = vim.api.nvim_buf_get_lines(0, 0, last, false)
  local fenced = parse.fenced(lines)
  local changed = false
  for lnum = first, last do
    local task = not fenced[lnum] and parse.classify(lines[lnum])
    if task then
      local interior = task.state == "checked" and " " or "x"
      local row = lnum - 1
      vim.api.nvim_buf_set_text(0, row, task.interior_start, row, task.interior_end, { interior })
      changed = true
    end
  end
  return changed
end

-- Flips the task on the cursor line, with the same results as `toggle_range`, so a
-- mapping can fall through to another action on false.
function M.toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return M.toggle_range(lnum, lnum)
end

return M
