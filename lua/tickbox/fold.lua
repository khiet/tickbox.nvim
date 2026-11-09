-- Folds headings that have tasks, through window options on attached buffers. The levels
-- come from the tree; this module only owns the options and keeping Neovim's folds fresh.
local buffers = require("tickbox.buffers")
local tree = require("tickbox.tree")

local M = {}

local group = vim.api.nvim_create_augroup("tickbox_fold", { clear = true })

-- Also how a window is recognised as ours, so a window the user set up differently, or
-- never asked to fold, is left alone.
local EXPR = "v:lua.require'tickbox.fold'.expr()"

-- Buffers whose levels changed during insert mode. Keyed by buffer number.
local awaiting_insert_end = {}

function M.expr()
  return tree.get(0).folds[vim.v.lnum] or "0"
end

local function is_ours(win)
  return vim.wo[win].foldexpr == EXPR
end

-- Skips a window that is already ours: reapplying on every BufWinEnter or :e would undo a
-- zM by resetting 'foldlevel'.
local function apply(win)
  if is_ours(win) then
    return
  end
  vim.api.nvim_win_call(win, function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = EXPR
    -- Empty draws the line itself, with its highlighting, in place of a fold summary.
    vim.opt_local.foldtext = ""
    vim.opt_local.foldlevel = 99
  end)
end

local function remove(win)
  vim.api.nvim_win_call(win, function()
    vim.cmd("setlocal foldmethod< foldexpr< foldtext< foldlevel<")
    -- Moving from expr to manual keeps the existing folds as manual ones. zE would also
    -- delete the markers of a global foldmethod=marker, so it runs for manual only.
    if vim.wo.foldmethod == "manual" then
      vim.cmd("silent! normal! zE")
    end
  end)
end

local function sync(buf)
  local wanted = buffers.options().fold and buffers.is_attached(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if wanted then
      apply(win)
    elseif is_ours(win) then
      remove(win)
    end
  end
end

-- Neovim re-evaluates 'foldexpr' only near an edit, but a task can change whether a
-- heading far above it folds. Re-setting 'foldmethod' invalidates the whole window and,
-- unlike zx, keeps closed folds closed.
--
-- A new fold copies the closed state of the fold above it, which would hide the task that
-- just made it foldable, so each line in `starts` is opened. One inside a closed parent is
-- skipped: :foldopen there would open the parent.
local function refresh(buf, starts)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if is_ours(win) and vim.wo[win].foldmethod == "expr" then
      vim.api.nvim_win_call(win, function()
        vim.opt_local.foldmethod = "expr"
        for _, lnum in ipairs(starts) do
          if vim.fn.foldclosed(lnum) == lnum then
            vim.cmd(lnum .. "foldopen")
          end
        end
      end)
    end
  end
end

local function starts_fold(level)
  return level ~= nil and level:sub(1, 1) == ">"
end

-- Whether `lnum` in the new text started a fold in `old`. The edit replaced 0-indexed rows
-- `first` up to `last` with rows up to `new_last`, which traces lines outside it exactly.
-- A replacement does not say which of its lines moved, so a line inside it is traced from
-- both ends, which is right unless lines were added both above and below it. A pure
-- insertion traces nothing, so its lines are new.
local function started_fold(old, lnum, first, last, new_last)
  local from_end = lnum - new_last + last
  if lnum <= first then
    return starts_fold(old[lnum])
  elseif lnum > new_last then
    return starts_fold(old[from_end])
  end
  return (lnum <= last and starts_fold(old[lnum])) or (from_end > first and starts_fold(old[from_end]))
end

-- The lines starting a fold in `new` that did not in `old`.
local function new_starts(old, new, first, last, new_last)
  local starts = {}
  for lnum, level in ipairs(new) do
    if starts_fold(level) and not started_fold(old, lnum, first, last, new_last) then
      table.insert(starts, lnum)
    end
  end
  return starts
end

-- Brings the buffer's windows up to date after an edit changed its levels from `old` to
-- `new`, with the edit's on_lines rows. Neovim skips fold updates in insert mode and does
-- not catch up afterwards for foldmethod=expr, so typing waits for the mode to end.
function M.update(buf, old, new, first, last, new_last)
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  if mode == "i" or mode == "R" then
    awaiting_insert_end[buf] = true
  else
    refresh(buf, new_starts(old, new, first, last, new_last))
  end
end

-- The window column for a count on the closed fold starting at `lnum`, or nil when the
-- count should not draw there: an end-of-line count does not show on a closed fold, so
-- the caller places this one itself. The column is the end of the line, for the caller's
-- leading space to cover the fold's fill character. Nil once scrolling has taken it
-- off-screen, because a window column cannot be negative. Checking the fold is a window
-- switch, so only a line that starts a fold of ours pays for it.
function M.closed_count_col(win, buf, lnum)
  if not (starts_fold(tree.get(buf).folds[lnum]) and is_ours(win)) then
    return nil
  end
  return vim.api.nvim_win_call(win, function()
    if vim.fn.foldclosed(lnum) ~= lnum then
      return nil
    end
    local col = vim.fn.strdisplaywidth(vim.fn.getline(lnum)) - vim.fn.winsaveview().leftcol
    return col >= 0 and col or nil
  end)
end

-- Safe to call repeatedly. Expects `buffers.setup` to have run first, so the options
-- exist and its FileType autocmd fires before the one defined here.
function M.start()
  vim.api.nvim_clear_autocmds({ group = group })
  if buffers.options().fold then
    -- FileType covers a first open and a filetype change. BufWinEnter covers a buffer
    -- shown in a window where it never had these options.
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
      group = group,
      callback = function(args)
        sync(args.buf)
      end,
    })
    -- Not InsertLeave, which <C-c> skips. The pattern leaves out moves within insert mode,
    -- such as into completion, where a refresh would still do nothing.
    vim.api.nvim_create_autocmd("ModeChanged", {
      group = group,
      pattern = "[iR]*:[^iR]*",
      callback = function(args)
        if awaiting_insert_end[args.buf] then
          awaiting_insert_end[args.buf] = nil
          refresh(args.buf, {})
          -- Lines moved while typing, so new starts cannot be traced to the old levels.
          -- But typing happens at the cursor, so the fold it just made is the one here.
          if is_ours(vim.api.nvim_get_current_win()) then
            vim.cmd("silent! normal! zv")
          end
        end
      end,
    })
  end
  -- Buffers opened before the plugin loaded missed their FileType event, and a previous
  -- setup may have folded windows this one should not.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    sync(buf)
  end
end

return M
