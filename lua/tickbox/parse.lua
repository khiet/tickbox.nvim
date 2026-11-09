-- Pure markdown task parsing. No Neovim API, so it stays testable without a buffer.
local state = require("tickbox.state")

local M = {}

-- Non-word interiors are escaped, since a bare `-` inside a set would form a range.
local interior_set = ""
for char in pairs(state.of_interior) do
  interior_set = interior_set .. (char:match("%w") and char or "%" .. char)
end
local task_pattern = "^ +()%[([" .. interior_set .. "])%] "

-- Returns nil when the line is not a GFM task item, otherwise a table with
-- `state` (a name from `state.order`), `ordered` (a numbered marker) and 0-indexed,
-- end-exclusive byte ranges:
-- `prefix_*` covers the marker through the closing bracket, `interior_*` the
-- single character between the brackets. Does not know about fences; `tree` pairs it
-- with `fenced`, and is the only caller of either.
function M.classify(line)
  local marker = line:match("^%s*()")
  local after_bullet = line:match("^[-*+]()", marker)
  local after_marker = after_bullet or line:match("^%d+[.)]()", marker)
  if not after_marker then
    return nil
  end
  local bracket, interior = line:match(task_pattern, after_marker)
  if not bracket then
    return nil
  end
  return {
    state = state.of_interior[interior],
    ordered = after_bullet == nil,
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
  -- Markers may nest on one line, as in "- - ```", and a tab may follow one.
  local prefix = bare
  while true do
    local marker = line:match("^[-*+][ \t]+", #prefix + 1)
      or line:match("^%d+[.)][ \t]+", #prefix + 1)
    if not marker then
      break
    end
    prefix = prefix .. marker
  end
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

-- The position past a run of backticks at `pos`, and past the code span it opens if a run
-- of the same length closes one. An unclosed run is literal text.
local function skip_backticks(line, pos)
  local run = #line:match("^`+", pos)
  local search = pos + run
  while true do
    local first, last = line:find("`+", search)
    if not first then
      return pos + run
    end
    if last - first + 1 == run then
      return last + 1
    end
    search = last + 1
  end
end

-- The position of the bracket closing the one at `open`, or nil.
local function label_close(line, open)
  local depth, i = 0, open
  while i <= #line do
    local char = line:sub(i, i)
    if char == "\\" then
      i = i + 2
    elseif char == "`" then
      i = skip_backticks(line, i)
    else
      if char == "[" then
        depth = depth + 1
      elseif char == "]" then
        depth = depth - 1
        if depth == 0 then
          return i
        end
      end
      i = i + 1
    end
  end
end

-- The position past the non-empty destination at `pos`, or nil.
local function destination_end(line, pos)
  local angled = line:sub(pos, pos) == "<"
  local depth, i = 0, angled and pos + 1 or pos
  while i <= #line do
    local char = line:sub(i, i)
    if char == "\\" then
      i = i + 2
    elseif angled and char == ">" then
      return i > pos + 1 and i + 1 or nil
    elseif angled and char == "<" then
      return nil
    elseif not angled and (char:match("%s") or (char == ")" and depth == 0)) then
      break
    else
      depth = depth + (char == "(" and 1 or char == ")" and -1 or 0)
      i = i + 1
    end
  end
  if angled or depth ~= 0 or i == pos then
    return nil
  end
  return i
end

local title_closer = { ['"'] = '"', ["'"] = "'", ["("] = ")" }

-- The position past the title opening at `pos`, or nil.
local function title_end(line, pos)
  local closer = title_closer[line:sub(pos, pos)]
  if not closer then
    return nil
  end
  local i = pos + 1
  while i <= #line do
    local char = line:sub(i, i)
    if char == "\\" then
      i = i + 2
    elseif char == closer then
      return i + 1
    else
      i = i + 1
    end
  end
end

-- The link whose bracket opens at 1-indexed `open`, or nil. A label holding a link or an
-- image is refused: links cannot nest, so an inner link is the real one, and an image
-- stays raw even inside a link.
local function link_at(line, open)
  local close = label_close(line, open)
  if not close or line:sub(close + 1, close + 1) ~= "(" then
    return nil
  end
  local label = line:sub(open + 1, close - 1)
  if not label:find("%S") or label:find("](", 1, true) then
    return nil
  end
  local dest_end = destination_end(line, line:match("^%s*()", close + 2))
  if not dest_end then
    return nil
  end
  local after = line:match("^%s*()", dest_end)
  if after > dest_end and line:sub(after, after) ~= ")" then
    local past_title = title_end(line, after)
    if not past_title then
      return nil
    end
    after = line:match("^%s*()", past_title)
  end
  if line:sub(after, after) ~= ")" then
    return nil
  end
  return { start = open - 1, label_start = open, label_end = close - 1, stop = after }
end

-- Returns the inline links `[label](destination)` on `line` at or after 0-indexed byte
-- `from`, as 0-indexed, end-exclusive ranges: `start` to `stop` covers the whole link and
-- `label_start` to `label_end` its label. Images, reference links, bare URLs, autolinks,
-- code spans and links with an empty label or destination are not links here.
function M.links(line, from)
  local found = {}
  if not line:find("](", from + 1, true) then
    return found
  end
  local i = from + 1
  while i <= #line do
    local char = line:sub(i, i)
    if char == "\\" then
      i = i + 2
    elseif char == "`" then
      i = skip_backticks(line, i)
    elseif char == "<" then
      -- An autolink binds tighter than brackets.
      i = line:match("^<%a[%w+.-]*:[^%s<>]*>()", i) or i + 1
    elseif char == "!" and line:sub(i + 1, i + 1) == "[" then
      local image = link_at(line, i + 1)
      i = image and image.stop + 1 or i + 1
    elseif char == "[" then
      local link = link_at(line, i)
      if link then
        table.insert(found, link)
      end
      i = link and link.stop + 1 or i + 1
    else
      i = i + 1
    end
  end
  return found
end

return M
