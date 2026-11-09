if vim.g.loaded_tickbox then
  return
end
vim.g.loaded_tickbox = true

require("tickbox")._ensure_started()

-- `operator` names the function in tickbox.toggle that normal mode runs; it is called
-- with the motion type, which it must ignore. `run_range` acts on the selected lines in
-- visual mode.
local function map_action(name, operator, run_range, normal_desc, visual_desc)
  local lhs = ("<Plug>(tickbox-%s)"):format(name)
  vim.keymap.set("n", lhs, function()
    -- Going through an operator is what lets `.` repeat the action.
    vim.o.operatorfunc = ("v:lua.require'tickbox.toggle'.%s"):format(operator)
    return "g@l"
  end, { expr = true, silent = true, desc = normal_desc })

  vim.keymap.set("x", lhs, function()
    local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")
    -- Not feedkeys: that would run keys queued behind the mapping, like the rest of a
    -- macro, while still in visual mode.
    vim.cmd.normal({ vim.keycode("<Esc>"), bang = true })
    local first, last = math.min(anchor, cursor), math.max(anchor, cursor)
    -- A selection touching a closed fold covers the whole fold on screen, and acts on it.
    local fold_start, fold_end = vim.fn.foldclosed(first), vim.fn.foldclosedend(last)
    run_range(fold_start ~= -1 and fold_start or first, fold_end ~= -1 and fold_end or last)
  end, { silent = true, desc = visual_desc })
end

map_action("toggle", "toggle", function(first, last)
  require("tickbox").toggle_range(first, last)
end, "Toggle the task under the cursor", "Toggle every task in the selection")
map_action("cycle", "cycle", function(first, last)
  require("tickbox").cycle_range(first, last)
end, "Cycle the state of the task under the cursor", "Cycle every task in the selection")

local states = require("tickbox.state").order

for _, state in ipairs(states) do
  local label = state:gsub("_", "-")
  map_action("set-" .. label, "set_" .. state, function(first, last)
    require("tickbox").set_range(state, first, last)
  end, ("Set the task under the cursor to %s"):format(label), ("Set every task in the selection to %s"):format(label))
end

vim.keymap.set("i", "<Plug>(tickbox-newline)", function()
  return require("tickbox.continue").newline()
end, { expr = true, desc = "Start a new line, continuing a task list" })

vim.keymap.set("n", "<Plug>(tickbox-open-below)", function()
  return require("tickbox.continue").open("o")
end, { expr = true, desc = "Open a line below, continuing a task list" })

vim.keymap.set("n", "<Plug>(tickbox-open-above)", function()
  return require("tickbox.continue").open("O")
end, { expr = true, desc = "Open a line above, continuing a task list" })

-- Without a range, both ends default to the cursor line, which in a closed fold means the
-- line seen there: the fold's first. A given range stays as Vim resolved it.
local function command_range(args)
  local closed = args.range == 0 and vim.fn.foldclosed(args.line1) or -1
  if closed ~= -1 then
    return closed, closed
  end
  return args.line1, args.line2
end

local subcommands = {
  toggle = function(args)
    require("tickbox").toggle_range(command_range(args))
  end,
  cycle = function(args)
    require("tickbox").cycle_range(command_range(args))
  end,
  enable = function()
    require("tickbox").enable()
  end,
  disable = function()
    require("tickbox").disable()
  end,
}

vim.api.nvim_create_user_command("Tickbox", function(args)
  -- `nargs = 1` keeps trailing whitespace in the argument.
  local argument = vim.trim(args.args)
  -- The state is the rest of the argument, so an extra word makes it an unknown state.
  local state = argument == "set" and "" or argument:match("^set%s+(.+)$")
  if state then
    local first, last = command_range(args)
    require("tickbox").set_range(state, first, last)
    return
  end
  local run = subcommands[argument]
  if not run then
    error("Tickbox: unknown subcommand: " .. argument, 0)
  end
  run(args)
end, {
  nargs = 1,
  range = true,
  desc = "Toggle, cycle or set tasks, or enable or disable rendering in this buffer",
  complete = function(lead, line)
    local after_set = line:match("Tickbox%s+set%s+(.*)$")
    local candidates = { "toggle", "cycle", "set", "enable", "disable" }
    if after_set then
      -- Anything past the first word is an extra argument, which takes no completion.
      candidates = after_set:find("%s") and {} or states
    elseif line:match("Tickbox%s+%S+%s") then
      return {}
    end
    return vim.tbl_filter(function(name)
      return vim.startswith(name, lead)
    end, candidates)
  end,
})
