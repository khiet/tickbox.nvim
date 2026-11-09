-- Plans task edits over a tree snapshot. Pure: no buffer, no Neovim API, so every
-- transition and the auto-check rule are testable on returned values alone.
local state = require("tickbox.state")
local tree = require("tickbox.tree")

local M = {}

-- A transition maps a task's state to the one that replaces it. A state with no entry
-- is left unedited.
M.toggle, M.cycle = {}, {}
for _, name in ipairs(state.order) do
  M.toggle[name] = state.toggled(name)
  M.cycle[name] = state.states[name].successor
end

-- The transition that puts every task in `name`. Raises on an unknown state, so a
-- caller validates before it reads a buffer or plans an edit.
function M.set(name)
  if not state.states[name] then
    error("Tickbox: unknown state: " .. tostring(name), 0)
  end
  local transition = {}
  for _, other in ipairs(state.order) do
    transition[other] = name
  end
  return transition
end

-- Adds to `edits` the ancestor edits that bring the ancestors of the edited tasks in
-- line with their descendants: an ancestor whose counted descendants are all checked
-- becomes checked, and a checked one with a descendant that is not becomes unchecked.
-- Cancelled ancestors are left alone, and so is every line in `range_tasks`, edited or
-- not, so a range never undoes its own result. Counts read the edits planned so far in
-- place of the snapshot, so the whole plan rests on one tree.
local function propagate(tasks, edits, range_tasks)
  local pending = {}
  for lnum in pairs(edits) do
    local parent = tasks[lnum].parent
    while parent and not pending[parent] do
      pending[parent] = true
      parent = tasks[parent].parent
    end
  end
  for lnum in pairs(range_tasks) do
    pending[lnum] = nil
  end
  -- Descendants sit below their ancestors, so going bottom-up settles every ancestor's
  -- subtree before the ancestor itself is judged.
  local order = {}
  for lnum in pairs(pending) do
    table.insert(order, lnum)
  end
  table.sort(order, function(a, b)
    return a > b
  end)

  for _, lnum in ipairs(order) do
    local current = edits[lnum] or tasks[lnum].state
    local done, total = tree.count(tasks, tree.descendants(tasks, lnum), edits)
    local target
    if not state.counts(current) or total == 0 then
      target = nil
    elseif done == total then
      target = state.done
    elseif state.is_done(current) then
      target = state.toggled(current)
    end
    if target and target ~= current then
      edits[lnum] = target
    end
  end
end

-- Returns the edits to make on `tasks` (a `tree.build` result's tasks) for applying
-- `transition` to the tasks on lines `first` through `last`, as { [lnum] = new state }.
-- Tasks already in the target state produce no edit. With `opts.auto_check_parent`,
-- the ancestor edits that follow are part of the same result.
function M.edits(tasks, first, last, transition, opts)
  local edits, range_tasks = {}, {}
  for lnum = math.max(first, 1), last do
    local task = tasks[lnum]
    if task then
      range_tasks[lnum] = true
      local target = transition[task.state]
      if target and target ~= task.state then
        edits[lnum] = target
      end
    end
  end
  if opts.auto_check_parent and next(edits) then
    propagate(tasks, edits, range_tasks)
  end
  return edits
end

return M
