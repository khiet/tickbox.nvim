-- The task and heading hierarchy of a buffer. `build` is pure; `get` caches it per
-- buffer change, so every redraw of a tick shares one parse.
local parse = require("tickbox.parse")
local state = require("tickbox.state")

local M = {}

-- Per buffer: { tick = changedtick, tree = build result for that tick }.
local cache = {}

-- CommonMark tab stops are every four columns, independent of 'tabstop'.
local function indent_width(line)
  local width = 0
  for char in line:match("^[ \t]*"):gmatch(".") do
    width = char == "\t" and width - width % 4 + 4 or width + 1
  end
  return width
end

local function heading_level(line)
  local hashes = line:match("^ ? ? ?(#+)%s") or line:match("^ ? ? ?(#+)$")
  return hashes and #hashes <= 6 and #hashes or nil
end

-- The done/total rule. Returns `done, total` over the tasks on `lnums` and all their
-- descendants: cancelled tasks are left out, checked tasks are done. `overlay`, by line
-- number, gives states to count in place of the tasks' own, so a caller planning edits
-- can count the tree as it will be without rebuilding it.
function M.count(tasks, lnums, overlay)
  local done, total = 0, 0
  for _, lnum in ipairs(lnums) do
    local task = tasks[lnum]
    local name = overlay and overlay[lnum] or task.state
    if state.counts(name) then
      total = total + 1
      done = done + (state.is_done(name) and 1 or 0)
    end
    local d, t = M.count(tasks, task.children, overlay)
    done, total = done + d, total + t
  end
  return done, total
end

-- Returns, for 1-indexed `lines` from the top of the buffer:
-- `tasks`: by line number, each parse.classify result plus `lnum`, `length` (the line's
--   byte length), `indent` (its width in columns), `parent` (the line number of the
--   nearest enclosing task, or nil) and `children` (line numbers of direct child tasks).
-- `counts`: by line number, `{ done, total }` for each task and heading with at least one
--   counted task under it, by the rule `count` applies.
--
-- A task's descendants are the task lines after it with a greater indentation, up to the
-- first non-blank line indented the same or less. A heading's tasks run to the next
-- heading of the same or a higher level. Fenced lines are skipped, so they neither count
-- nor end a run.
function M.build(lines)
  local fenced = parse.fenced(lines)
  local tasks = {}
  -- Enclosing tasks and headings, outermost first. A heading's `roots` are the tasks
  -- under it whose parent is not, so counting them and their descendants covers every
  -- task under the heading exactly once.
  local open_tasks, open_headings, headings = {}, {}, {}

  for lnum, line in ipairs(lines) do
    if not fenced[lnum] and line:find("%S") then
      local level = heading_level(line)
      local width = indent_width(line)
      while #open_tasks > 0 and open_tasks[#open_tasks].indent >= width do
        table.remove(open_tasks)
      end

      if level then
        while #open_headings > 0 and open_headings[#open_headings].level >= level do
          table.remove(open_headings)
        end
        local heading = { lnum = lnum, level = level, roots = {} }
        table.insert(open_headings, heading)
        table.insert(headings, heading)
      else
        local task = parse.classify(line)
        if task then
          local parent = open_tasks[#open_tasks]
          task.indent = width
          task.lnum = lnum
          task.length = #line
          task.parent = parent and parent.lnum
          task.children = {}
          if parent then
            table.insert(parent.children, lnum)
          end
          tasks[lnum] = task
          for _, heading in ipairs(open_headings) do
            if not parent or parent.lnum < heading.lnum then
              table.insert(heading.roots, lnum)
            end
          end
          table.insert(open_tasks, task)
        end
      end
    end
  end

  local counts = {}
  local function record(lnum, lnums)
    local done, total = M.count(tasks, lnums)
    if total > 0 then
      counts[lnum] = { done = done, total = total }
    end
  end
  for lnum, task in pairs(tasks) do
    record(lnum, task.children)
  end
  for _, heading in ipairs(headings) do
    record(heading.lnum, heading.roots)
  end

  return { tasks = tasks, counts = counts }
end

-- The build result for the buffer's current text. Callers must not modify it.
function M.get(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = cache[buf]
  if not cached or cached.tick ~= tick then
    cached = { tick = tick, tree = M.build(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) }
    cache[buf] = cached
  end
  return cached.tree
end

function M.forget(buf)
  cache[buf] = nil
end

return M
