-- Pure markdown task parsing. No Neovim API, so it stays testable without a buffer.
local M = {}

-- Returns nil when the line is not a GFM task item, otherwise a table with
-- `state` ("unchecked" | "checked") and 0-indexed, end-exclusive byte ranges:
-- `prefix_*` covers the marker through the closing bracket, `interior_*` the
-- single character between the brackets. Does not know about fences; pair it with
-- `fenced`.
function M.classify(line)
  local marker = line:match("^%s*()")
  local after_marker = line:match("^[-*+]()", marker) or line:match("^%d+[.)]()", marker)
  if not after_marker then
    return nil
  end
  local bracket, interior = line:match("^ +()%[([ xX])%] ", after_marker)
  if not bracket then
    return nil
  end
  return {
    state = interior == " " and "unchecked" or "checked",
    prefix_start = marker - 1,
    prefix_end = bracket + 2,
    interior_start = bracket,
    interior_end = bracket + 1,
  }
end

-- Reads a run of three or more fence characters, which may follow a list marker. Any
-- indentation counts, unlike CommonMark's limit of three spaces, because fences nested in
-- list items sit deeper. `indent` is the run's column, so a closer can be compared with it.
local function fence_run(line)
  local bare = line:match("^%s*")
  local prefix = line:match("^%s*[-*+] +") or line:match("^%s*%d+[.)] +") or bare
  local start = #prefix + 1
  local run, rest = line:match("^(```+)(.*)$", start)
  if not run then
    run, rest = line:match("^(~~~+)(.*)$", start)
  end
  return run
    and {
      char = run:sub(1, 1),
      length = #run,
      indent = #prefix,
      rest = rest,
      on_marker = prefix ~= bare,
    }
end

local function closes(run, open)
  return run.char == open.char
    and run.length >= open.length
    and run.indent <= open.indent + 3
    and not run.on_marker
    and run.rest:match("^%s*$") ~= nil
end

-- Returns a set of the 1-indexed lines inside a fenced code block, delimiters
-- included. `lines` must start at the top of the buffer, since a fence stays open
-- until closed. An unclosed fence runs to the last line.
function M.fenced(lines)
  local inside = {}
  local open
  for i, line in ipairs(lines) do
    local run = fence_run(line)
    if open then
      inside[i] = true
      if run and closes(run, open) then
        open = nil
      end
    elseif run and not (run.char == "`" and run.rest:find("`", 1, true)) then
      inside[i] = true
      open = run
    end
  end
  return inside
end

return M
