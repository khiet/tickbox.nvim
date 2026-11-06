local parse = require("tickbox.parse")
local render = require("tickbox.render")

local M = {}

-- Toggle is a done/not-done switch, so in-progress and cancelled tasks count as not done.
local toggled = { unchecked = "x", in_progress = "x", checked = " ", cancelled = "x" }
local cycled = { unchecked = "/", in_progress = "x", checked = "-", cancelled = " " }

-- Sets each task in the range to `next_interior[task.state]`, with the results
-- `toggle_range` describes.
local function rewrite_range(next_interior, first, last)
  if not vim.bo.modifiable or not render.is_attached() then
    return false
  end
  -- Fence state only depends on the lines above, so the rest need not be read.
  local lines = vim.api.nvim_buf_get_lines(0, 0, last, false)
  local fenced = parse.fenced(lines)
  local changed = false
  for lnum = math.max(first, 1), #lines do
    local task = not fenced[lnum] and parse.classify(lines[lnum])
    if task then
      local row = lnum - 1
      local interior = next_interior[task.state]
      vim.api.nvim_buf_set_text(0, row, task.interior_start, row, task.interior_end, { interior })
      changed = true
    end
  end
  return changed
end

-- Marks checked tasks unchecked and every other task checked, on lines `first` through
-- `last` (1-indexed, inclusive; lines outside the buffer are ignored). Returns true if
-- any line was edited. Returns false when none were: only non-task or fenced lines, a
-- filetype that is not configured, or a nomodifiable buffer. Disabling rendering does
-- not stop it. All edits from one call are one undo step.
function M.toggle_range(first, last)
  return rewrite_range(toggled, first, last)
end

-- Advances each task: unchecked, in progress, checked, cancelled, then unchecked again.
-- Same range and result as `toggle_range`.
function M.cycle_range(first, last)
  return rewrite_range(cycled, first, last)
end

-- Acts on the cursor line, with the same results as the range form, so a mapping can
-- fall through to another action on false.
function M.toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return M.toggle_range(lnum, lnum)
end

function M.cycle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return M.cycle_range(lnum, lnum)
end

return M
