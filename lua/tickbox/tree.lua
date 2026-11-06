-- The task and heading hierarchy of a buffer. `build` is pure; `get` caches it per
-- buffer change, so every redraw of a tick shares one parse.
local parse = require("tickbox.parse")

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

-- Returns, for 1-indexed `lines` from the top of the buffer:
-- `fenced`: the parse.fenced set.
-- `tasks`: by line number, each parse.classify result plus `parent` (the line number of
--   the nearest enclosing task, or nil) and `children` (line numbers of direct child tasks).
-- `counts`: by line number, `{ done, total }` for each task and heading with at least one
--   counted task under it. Counts cover all descendants; cancelled tasks are left out.
--
-- A task's descendants are the task lines after it with a greater indentation, up to the
-- first non-blank line indented the same or less. A heading's tasks run to the next
-- heading of the same or a higher level, and a heading also ends every task run. Fenced
-- lines are skipped, so they neither count nor end a run.
function M.build(lines)
  local fenced = parse.fenced(lines)
  local tasks, counts = {}, {}
  -- Enclosing tasks and headings, outermost first.
  local open_tasks, open_headings = {}, {}

  local function tally(lnum, checked)
    local count = counts[lnum] or { done = 0, total = 0 }
    counts[lnum] = count
    count.total = count.total + 1
    if checked then
      count.done = count.done + 1
    end
  end

  for lnum, line in ipairs(lines) do
    if not fenced[lnum] and line:find("%S") then
      local level = heading_level(line)
      local width = level and -1 or indent_width(line)
      while #open_tasks > 0 and open_tasks[#open_tasks].indent >= width do
        table.remove(open_tasks)
      end

      if level then
        while #open_headings > 0 and open_headings[#open_headings].level >= level do
          table.remove(open_headings)
        end
        table.insert(open_headings, { lnum = lnum, level = level })
      else
        local task = parse.classify(line)
        if task then
          local parent = open_tasks[#open_tasks]
          task.indent = width
          task.lnum = lnum
          task.parent = parent and parent.lnum
          task.children = {}
          if parent then
            table.insert(parent.children, lnum)
          end
          tasks[lnum] = task

          if task.state ~= "cancelled" then
            local checked = task.state == "checked"
            for _, open in ipairs(open_tasks) do
              tally(open.lnum, checked)
            end
            for _, open in ipairs(open_headings) do
              tally(open.lnum, checked)
            end
          end
          table.insert(open_tasks, task)
        end
      end
    end
  end

  return { fenced = fenced, tasks = tasks, counts = counts }
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
