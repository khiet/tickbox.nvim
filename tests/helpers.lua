local M = {}

M.UNCHECKED = "󰄱"
M.CHECKED = "󰱒"

-- Opens a fresh buffer in the only window and returns it.
function M.open(lines, filetype)
  vim.cmd("enew!")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype or "markdown"
  return buf
end

-- The overlay is drawn with ephemeral extmarks, which never appear in
-- nvim_buf_get_extmarks, so rendering is observed the way a user sees it: on the
-- screen. Returns screen row `row` (1-indexed) without trailing blanks.
function M.screen_line(row)
  vim.cmd("redraw!")
  local cells = {}
  for col = 1, vim.o.columns do
    cells[col] = vim.fn.screenstring(row, col)
  end
  return (table.concat(cells):gsub("%s+$", ""))
end

return M
