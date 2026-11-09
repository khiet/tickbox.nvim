local buffers = require("tickbox.buffers")
local plan = require("tickbox.plan")
local state = require("tickbox.state")
local tree = require("tickbox.tree")

local M = {}

-- Writes each planned edit's interior character. Every edit stays within its line, so
-- the tree the edits were planned on still locates every task as they are written.
-- Returns whether any line changed.
local function apply(tasks, edits)
  local changed = false
  for lnum, name in pairs(edits) do
    local task = tasks[lnum]
    local row = lnum - 1
    vim.api.nvim_buf_set_text(0, row, task.interior_start, row, task.interior_end, { state.states[name].interior })
    changed = true
  end
  return changed
end

-- Applies `transition` to the tasks in the range, with the results `toggle_range`
-- describes. The buffer is read once, before any edit, and one apply step writes every
-- edit of the call, so all of them share one undo step.
local function rewrite_range(transition, first, last)
  if not buffers.may_edit() then
    return false
  end
  local tasks = tree.get(0).tasks
  local edits = plan.edits(tasks, first, math.min(last, vim.api.nvim_buf_line_count(0)), transition, buffers.options())
  return apply(tasks, edits)
end

-- Marks checked tasks unchecked and every other task checked, on lines `first` through
-- `last` (1-indexed, inclusive; lines outside the buffer are ignored). Returns true if
-- any line was edited. Returns false when none were: only non-task or fenced lines, a
-- filetype that is not configured, or a nomodifiable buffer. Disabling rendering does
-- not stop it. All edits from one call, including those `auto_check_parent` adds to
-- ancestors, are one undo step.
function M.toggle_range(first, last)
  return rewrite_range(plan.toggle, first, last)
end

-- Advances each task: unchecked, in progress, checked, cancelled, then unchecked again.
-- Same range and result as `toggle_range`.
function M.cycle_range(first, last)
  return rewrite_range(plan.cycle, first, last)
end

-- Sets each task to `name`, leaving any already in it unedited. Same range and result
-- as `toggle_range`. Raises on an unknown state, even when no line would change.
function M.set_range(name, first, last)
  return rewrite_range(plan.set(name), first, last)
end

-- The line the cursor is seen on. In a closed fold that is the fold's first line, whatever
-- line the cursor last had, so an edit never lands on a line the user cannot see.
local function cursor_line()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local closed = vim.fn.foldclosed(lnum)
  return closed ~= -1 and closed or lnum
end

-- Acts on the cursor line, with the same results as the range form, so a mapping can
-- fall through to another action on false.
function M.toggle()
  local lnum = cursor_line()
  return M.toggle_range(lnum, lnum)
end

function M.cycle()
  local lnum = cursor_line()
  return M.cycle_range(lnum, lnum)
end

function M.set(name)
  local lnum = cursor_line()
  return M.set_range(name, lnum, lnum)
end

-- One function per state, because `operatorfunc` can only name a function and passes it
-- the motion type. Internal to the `<Plug>` mappings, so not re-exported by `tickbox`.
for _, name in ipairs(state.order) do
  M["set_" .. name] = function()
    return M.set(name)
  end
end

return M
