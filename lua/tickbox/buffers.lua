-- Owns the options and which buffers the plugin acts on, so that the other modules ask
-- here whether a buffer may be edited or renders instead of deciding it themselves.
local M = {}

local group = vim.api.nvim_create_augroup("tickbox_buffers", { clear = true })

local options
-- Buffers whose filetype is in options.filetypes. Keyed by buffer number.
local attached = {}
-- Buffers turned off with `disable`. Separate from `attached` so the choice survives the
-- FileType event a :e reload fires, and lasts until `enable` or the buffer is wiped.
local disabled = {}

local function resolve(buf)
  return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
end

local function refresh(buf)
  attached[buf] = vim.tbl_contains(options.filetypes, vim.bo[buf].filetype) or nil
end

function M.options()
  return options
end

-- Whether the buffer's filetype is configured, regardless of `disable`.
function M.is_attached(buf)
  return attached[resolve(buf)] == true
end

-- Whether an editing action may run in the buffer: its filetype is configured and it is
-- modifiable. `disable` only stops drawing, so a disabled buffer may still be edited.
function M.may_edit(buf)
  buf = resolve(buf)
  return attached[buf] == true and vim.bo[buf].modifiable
end

-- Whether the buffer renders: its filetype is configured and it has not been disabled.
function M.is_enabled(buf)
  buf = resolve(buf)
  return attached[buf] == true and not disabled[buf]
end

local function set_disabled(buf, value)
  buf = resolve(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error("Tickbox: invalid buffer: " .. tostring(buf), 0)
  end
  disabled[buf] = value
  -- Nothing else tells the decoration provider the answer changed, so the buffer's
  -- windows are invalidated here.
  vim.api.nvim__redraw({ buf = buf, valid = false })
end

-- Clears `disable`. A buffer whose filetype is not configured still does not render.
function M.enable(buf)
  set_disabled(buf, nil)
end

function M.disable(buf)
  set_disabled(buf, true)
end

-- Safe to call repeatedly; the latest options replace the previous ones. Must run
-- before `render.start`: autocmds fire in definition order, and render's FileType
-- callback expects the buffer to be attached already.
function M.setup(opts)
  options = opts

  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      refresh(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      attached[args.buf] = nil
      disabled[args.buf] = nil
    end,
  })

  -- Buffers opened before the plugin loaded missed their FileType event.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh(buf)
  end
end

return M
