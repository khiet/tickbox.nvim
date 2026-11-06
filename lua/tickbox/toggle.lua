local parse = require("tickbox.parse")
local render = require("tickbox.render")
local tree = require("tickbox.tree")

local M = {}

-- Toggle is a done/not-done switch, so in-progress and cancelled tasks count as not done.
local toggled = { unchecked = "x", in_progress = "x", checked = " ", cancelled = "x" }
local cycled = { unchecked = "/", in_progress = "x", checked = "-", cancelled = " " }

-- Brings the ancestors of the tasks on `edited` lines in line with their descendants: an
-- ancestor whose counted descendants are all checked becomes checked, and a checked one
-- with a descendant that is not becomes unchecked. Cancelled ancestors are left alone,
-- and so are edited tasks, so a range never undoes its own edit. Must run in the same
-- call as the edits, so all of them stay one undo step.
local function propagate(edited)
  local tasks = tree.get(0).tasks
  local is_edited = {}
  for _, lnum in ipairs(edited) do
    is_edited[lnum] = true
  end
  local pending = {}
  for _, lnum in ipairs(edited) do
    local parent = tasks[lnum].parent
    while parent and not pending[parent] do
      pending[parent] = true
      parent = tasks[parent].parent
    end
  end
  for lnum in pairs(is_edited) do
    pending[lnum] = nil
  end
  -- Descendants sit below their ancestors, so going bottom-up settles every ancestor's
  -- subtree before the ancestor itself is judged.
  local order = vim.tbl_keys(pending)
  table.sort(order, function(a, b)
    return a > b
  end)

  -- States rewritten so far, by line number; the tree still holds the old ones.
  local rewritten = {}
  local function state(lnum)
    return rewritten[lnum] or tasks[lnum].state
  end
  local function subtree_counts(lnum)
    local done, total = 0, 0
    for _, child in ipairs(tasks[lnum].children) do
      local s = state(child)
      if s ~= "cancelled" then
        total = total + 1
        done = done + (s == "checked" and 1 or 0)
      end
      local d, t = subtree_counts(child)
      done, total = done + d, total + t
    end
    return done, total
  end

  for _, lnum in ipairs(order) do
    local current = state(lnum)
    local done, total = subtree_counts(lnum)
    local target
    if current == "cancelled" or total == 0 then
      target = nil
    elseif done == total then
      target = "checked"
    elseif current == "checked" then
      target = "unchecked"
    end
    if target and target ~= current then
      local task = tasks[lnum]
      local interior = target == "checked" and "x" or " "
      vim.api.nvim_buf_set_text(0, lnum - 1, task.interior_start, lnum - 1, task.interior_end, { interior })
      rewritten[lnum] = target
    end
  end
end

-- Sets each task in the range to `next_interior[task.state]`, with the results
-- `toggle_range` describes.
local function rewrite_range(next_interior, first, last)
  if not vim.bo.modifiable or not render.is_attached() then
    return false
  end
  -- Fence state only depends on the lines above, so the rest need not be read.
  local lines = vim.api.nvim_buf_get_lines(0, 0, last, false)
  local fenced = parse.fenced(lines)
  local edited = {}
  for lnum = math.max(first, 1), #lines do
    local task = not fenced[lnum] and parse.classify(lines[lnum])
    if task then
      local row = lnum - 1
      local interior = next_interior[task.state]
      vim.api.nvim_buf_set_text(0, row, task.interior_start, row, task.interior_end, { interior })
      table.insert(edited, lnum)
    end
  end
  if #edited > 0 and render.options().auto_check_parent then
    propagate(edited)
  end
  return #edited > 0
end

-- Marks checked tasks unchecked and every other task checked, on lines `first` through
-- `last` (1-indexed, inclusive; lines outside the buffer are ignored). Returns true if
-- any line was edited. Returns false when none were: only non-task or fenced lines, a
-- filetype that is not configured, or a nomodifiable buffer. Disabling rendering does
-- not stop it. All edits from one call, including those `auto_check_parent` adds to
-- ancestors, are one undo step.
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
