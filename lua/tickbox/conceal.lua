-- Owns what hiding text needs. `links` and `compact` both hide part of a task line, which
-- takes 'conceallevel' above 0, where the stock markdown queries would also conceal every
-- other line. So a buffer with either on gets a treesitter highlighter whose queries
-- conceal nothing, and only render's marks then hide anything. The highlighter's `queries`
-- option is a private Neovim API, kept to this module.
local buffers = require("tickbox.buffers")

local M = {}

local group = vim.api.nvim_create_augroup("tickbox_conceal", { clear = true })

-- Also how a window is recognised as ours, so a window the user set to conceal is left
-- alone. Means the same as "nc": conceal the cursor line in normal and command mode, so
-- lines keep their width as the cursor moves. :split copies options, not window variables.
local CONCEALCURSOR = "cn"

-- By buffer, the highlighter this module started.
local stripped = {}
-- Buffers with a sync scheduled by `check`.
local pending = {}
-- Buffers that keep the highlighter they have until the next autocmd: ours failed to start,
-- or a window the user set to conceal shares the buffer. `check` must not retry these on
-- every redraw.
local held = {}
-- Whether this session has set the options, since they alone cannot prove a window is ours:
-- a user may have set the same values, and with this never on they must not be touched.
local applied = false

local function active(buf)
  return vim.treesitter.highlighter.active[buf]
end

local function is_ours(win)
  return applied and vim.wo[win].conceallevel == 2 and vim.wo[win].concealcursor == CONCEALCURSOR
end

-- buftype leaves out LSP hover floats, which rely on stock conceal. The highlighter leaves
-- out regex markdown syntax, which would conceal other lines at this 'conceallevel'.
local function qualifies(buf)
  local options = buffers.options()
  return (options.links or options.compact)
    and buffers.is_attached(buf)
    and vim.bo[buf].buftype == ""
    and active(buf) ~= nil
end

-- The 'concealcursor' flag Neovim tests for the cursor line in the current mode, or nil
-- in a mode where that line is never concealed. Select mode tests "n", as Neovim does.
local function cursor_flag(mode)
  local first = mode:sub(1, 1)
  if first == "v" or first == "V" or first == "\22" then
    return "v"
  elseif first == "R" then
    return "i"
  elseif first == "s" or first == "S" or first == "\19" then
    return "n"
  elseif first == "n" or first == "i" or first == "c" then
    return first
  end
end

local function is_visual(mode)
  return mode:find("^[vV\22sS\19]") ~= nil
end

local NOTHING = {
  links = false,
  hides = function()
    return false
  end,
}

-- What render may hide in this window, valid for one redraw of it. `links` is whether to
-- place link marks: a window at level 0 would only get the label styling on a link it
-- cannot hide. `hides(row)` is whether Neovim conceals that row, which mirrors its own
-- rule so a line it shows raw is never drawn with a mark it would ignore. Level 1 does not
-- count: there Neovim draws a replacement cell for each hidden run.
function M.view(win, buf)
  if not qualifies(buf) then
    return NOTHING
  end
  local options = buffers.options()
  local level = vim.wo[win].conceallevel
  local view = { links = options.links and level > 0, hides = NOTHING.hides }
  if not options.compact or level < 2 then
    return view
  end

  local mode = vim.api.nvim_get_mode().mode
  local concealcursor = vim.wo[win].concealcursor
  local function has(flag)
    return flag ~= nil and concealcursor:find(flag, 1, true) ~= nil
  end
  -- Only the current window's cursor line can show raw; another window conceals its own.
  local cursor_row
  if win == vim.api.nvim_get_current_win() and not has(cursor_flag(mode)) then
    cursor_row = vim.api.nvim_win_get_cursor(win)[1] - 1
  end
  -- Neovim shows the selection raw in every window on the selected buffer.
  local first, last
  if is_visual(mode) and buf == vim.api.nvim_get_current_buf() and not has("v") then
    first, last = vim.fn.line("v") - 1, vim.fn.line(".") - 1
    if first > last then
      first, last = last, first
    end
  end
  view.hides = function(row)
    return row ~= cursor_row and not (first and row >= first and row <= last)
  end
  return view
end

local function strip_conceal(source)
  -- The value may hold an escaped quote, as in conceal "\"".
  return (source:gsub('%(#set!%s+[@%w_.%-]*%s*"?conceal[_%w]*"?%s+"[^\n]-"%s*%)', ""))
end

local function stripped_query(lang)
  local sources = {}
  for _, file in ipairs(vim.treesitter.query.get_files(lang, "highlights")) do
    table.insert(sources, table.concat(vim.fn.readfile(file), "\n"))
  end
  return strip_conceal(table.concat(sources, "\n"))
end

-- Returns whether the highlighter is in place. Failing leaves the stock one running, and
-- the caller leaves the window options alone, so links stay raw and the box padded.
local function start_stripped(buf)
  if stripped[buf] and active(buf) == stripped[buf] then
    return true
  end
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return false
  end
  local lang = parser:lang()
  local queries = { [lang] = stripped_query(lang), markdown_inline = stripped_query("markdown_inline") }
  for query_lang, query in pairs(queries) do
    if not pcall(vim.treesitter.query.parse, query_lang, query) then
      return false
    end
  end
  active(buf):destroy()
  local started, highlighter = pcall(vim.treesitter.highlighter.new, parser, { queries = queries })
  if not started then
    vim.treesitter.start(buf, lang)
    return false
  end
  stripped[buf] = highlighter
  return true
end

local function stop_stripped(buf)
  if stripped[buf] and active(buf) == stripped[buf] then
    local lang = stripped[buf].tree:lang()
    vim.treesitter.stop(buf)
    vim.treesitter.start(buf, lang)
  end
  stripped[buf] = nil
end

local function apply(win)
  applied = true
  vim.api.nvim_win_call(win, function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = CONCEALCURSOR
  end)
end

local function remove(win)
  vim.api.nvim_win_call(win, function()
    vim.cmd("setlocal conceallevel< concealcursor<")
  end)
end

local function sync(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local wins = vim.fn.win_findbuf(buf)
  if not qualifies(buf) then
    for _, win in ipairs(wins) do
      if is_ours(win) then
        remove(win)
      end
    end
    stop_stripped(buf)
    held[buf] = nil
    return
  end

  -- The highlighter is per buffer. A window the user set to conceal keeps it stock, so the
  -- buffer's other windows stay raw: at this level stock conceals every line.
  local ours, theirs = {}, false
  for _, win in ipairs(wins) do
    if vim.wo[win].conceallevel == 0 or is_ours(win) then
      table.insert(ours, win)
    else
      theirs = true
    end
  end
  if theirs then
    stop_stripped(buf)
  end
  local started = not theirs and #ours > 0 and start_stripped(buf)
  held[buf] = (#ours > 0 and not started) or nil
  for _, win in ipairs(ours) do
    if started then
      apply(win)
    elseif is_ours(win) then
      remove(win)
    end
  end
end

-- Called on every window redraw. Something started a highlighter this module did not: the
-- ftplugin on :e, or a user's vim.treesitter.start at any later time, which no autocmd
-- announces. At this level the stock one conceals every other line, so it is replaced as
-- soon as the redraw that found it is over. A window the user set back to level 0 under
-- our own highlighter does not match, so that choice lasts until the next autocmd.
--
-- Each case must be one `sync` resolves, since the redraw it asks for lands back here.
function M.check(win, buf)
  local current = active(buf)
  if current == stripped[buf] or pending[buf] or held[buf] then
    return
  end
  local stale = stripped[buf] ~= nil
    or (qualifies(buf) and (vim.wo[win].conceallevel == 0 or is_ours(win)))
  if stale then
    pending[buf] = true
    vim.schedule(function()
      pending[buf] = nil
      if vim.api.nvim_buf_is_valid(buf) then
        sync(buf)
        vim.api.nvim__redraw({ buf = buf, valid = false })
      end
    end)
  end
end

-- Safe to call repeatedly. Expects `buffers.setup` to have run first, so the options
-- exist and its FileType autocmd fires before the one defined here.
function M.start()
  vim.api.nvim_clear_autocmds({ group = group })
  -- FileType covers a first open and a :e. BufWinEnter covers a buffer shown in a window
  -- that does not have these options, and another buffer moved into one that does.
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      sync(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      stripped[args.buf] = nil
      held[args.buf] = nil
    end,
  })
  -- Buffers opened before the plugin loaded missed their FileType event, and a previous
  -- setup may have set options this one should not.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    sync(buf)
  end
end

return M
