-- The read-only task listing behind `require("tickbox").tasks()`.
local parse = require("tickbox.parse")
local tree = require("tickbox.tree")

local M = {}

-- Returns the buffer's unfenced tasks in line order. Reads any loaded buffer whatever its
-- filetype. The result is a fresh table the caller may modify.
function M.list(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    error("Tickbox: invalid buffer: " .. tostring(buf), 0)
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local by_lnum = tree.get(buf).tasks

  local list, index = {}, {}
  for lnum = 1, #lines do
    local task = by_lnum[lnum]
    if task then
      local text, fields = parse.fields(lines[lnum]:sub(task.prefix_end + 1))
      table.insert(list, {
        lnum = lnum,
        state = task.state,
        text = text,
        fields = fields,
        indent = task.indent,
        -- A parent always precedes its children, so its index is already known.
        parent = task.parent and index[task.parent],
      })
      index[lnum] = #list
    end
  end
  return list
end

return M
