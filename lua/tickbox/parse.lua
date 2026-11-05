-- Pure markdown task parsing. No Neovim API, so it stays testable without a buffer.
local M = {}

-- Returns nil when the line is not a task item, otherwise a table with
-- `state` ("unchecked" | "checked") and 0-indexed, end-exclusive byte ranges:
-- `prefix_*` covers the marker through the closing bracket, `interior_*` the
-- single character between the brackets.
function M.classify(line)
  local bracket, interior = line:match("^%- +()%[([ x])%] ")
  if not bracket then
    return nil
  end
  return {
    state = interior == " " and "unchecked" or "checked",
    prefix_start = 0,
    prefix_end = bracket + 2,
    interior_start = bracket,
    interior_end = bracket + 1,
  }
end

return M
