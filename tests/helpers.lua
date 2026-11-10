local M = {}

M.UNCHECKED = "󰄱"
M.CHECKED = "󰱒"
M.IN_PROGRESS = "󰡖"
M.CANCELLED = "󰅗"

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
--
-- `redraw!` repaints everything and so hides a missing invalidation. Pass
-- `{ soft = true }` to assert that the plugin itself asked for the repaint.
function M.screen_line(row, opts)
  vim.cmd(opts and opts.soft and "redraw" or "redraw!")
  local cells = {}
  for col = 1, vim.o.columns do
    cells[col] = vim.fn.screenstring(row, col)
  end
  return (table.concat(cells):gsub("%s+$", ""))
end

-- Types `keys`, running `probe` wherever `keys` contains the literal "<PROBE>", in the
-- mode the preceding keys left. Lets a test look around while still in insert mode.
function M.type(keys, probe)
  _G.__tickbox_probe = probe
  local expanded = keys:gsub("<PROBE>", "<Cmd>lua _G.__tickbox_probe()<CR>")
  vim.api.nvim_feedkeys(vim.keycode(expanded), "mx", false)
end

-- Typed keys close the undo block while nvim waits for input. Fed keys never wait, so
-- this does it by hand, as a pause between keystrokes would.
function M.pause()
  vim.bo.undolevels = vim.bo.undolevels
end

-- The markdown_inline injection parses asynchronously, so a screen read straight after
-- opening a buffer shows other lines raw even under stock conceal. The wait also runs the
-- repair a redraw schedules when it finds the wrong highlighter.
function M.settle()
  for _ = 1, 3 do
    local parser = vim.treesitter.get_parser(0)
    if parser then
      parser:parse(true)
    end
    vim.cmd("redraw!")
    vim.wait(20, function()
      return false
    end)
  end
end

function M.open_treesitter(lines)
  local buf = M.open(lines)
  vim.treesitter.start(buf, "markdown")
  M.settle()
  return buf
end

return M
