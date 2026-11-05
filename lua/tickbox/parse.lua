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

-- Any indentation counts, unlike CommonMark's limit of three spaces, because fences
-- nested in list items are indented further and task lists are mostly list items.
local function fence_run(line)
  local run = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
  return run, run and line:match("^%s*[`~]+(.*)$")
end

-- Returns a set of the 1-indexed lines inside a fenced code block, delimiters
-- included. `lines` must start at the top of the buffer, since a fence stays open
-- until closed. An unclosed fence runs to the last line.
function M.fenced(lines)
  local inside = {}
  local open
  for i, line in ipairs(lines) do
    local run, rest = fence_run(line)
    if open then
      inside[i] = true
      local closes = run
        and run:sub(1, 1) == open:sub(1, 1)
        and #run >= #open
        and rest:match("^%s*$")
      if closes then
        open = nil
      end
    elseif run and not (run:sub(1, 1) == "`" and rest:find("`", 1, true)) then
      inside[i] = true
      open = run
    end
  end
  return inside
end

return M
