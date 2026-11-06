-- The read-only task listing behind `require("tickbox").tasks()`.
local parse = require("tickbox.parse")
local render = require("tickbox.render")
local tree = require("tickbox.tree")

local M = {}

-- Returns the buffer's unfenced tasks in line order. Reads any loaded buffer whatever its
-- filetype. The result is a fresh table the caller may modify.
function M.list(buf)
  buf = render.resolve_valid(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local by_lnum = tree.build(lines).tasks
  local tabstop = vim.bo[buf].tabstop

  local list, position_by_lnum = {}, {}
  for lnum, line in ipairs(lines) do
    local task = by_lnum[lnum]
    if task then
      local text, fields = parse.fields(line:sub(task.prefix_end + 1))
      table.insert(list, {
        lnum = lnum,
        state = task.state,
        text = text,
        fields = fields,
        indent = tree.indent_width(line, tabstop),
        -- A parent always precedes its children, so its position is already known.
        parent = task.parent and position_by_lnum[task.parent],
      })
      position_by_lnum[lnum] = #list
    end
  end
  return list
end

return M
