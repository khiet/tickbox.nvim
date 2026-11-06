if vim.g.loaded_tickbox then
  return
end
vim.g.loaded_tickbox = true

require("tickbox")._ensure_started()

-- `action` is "toggle" or "cycle"; the mappings call `<action>` and `<action>_range`.
local function map_action(action, normal_desc, visual_desc)
  local lhs = ("<Plug>(tickbox-%s)"):format(action)
  vim.keymap.set("n", lhs, function()
    -- Going through an operator is what lets `.` repeat the action.
    vim.o.operatorfunc = ("v:lua.require'tickbox.toggle'.%s"):format(action)
    return "g@l"
  end, { expr = true, silent = true, desc = normal_desc })

  vim.keymap.set("x", lhs, function()
    local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")
    -- Not feedkeys: that would run keys queued behind the mapping, like the rest of a
    -- macro, while still in visual mode.
    vim.cmd.normal({ vim.keycode("<Esc>"), bang = true })
    require("tickbox")[action .. "_range"](math.min(anchor, cursor), math.max(anchor, cursor))
  end, { silent = true, desc = visual_desc })
end

map_action("toggle", "Toggle the task under the cursor", "Toggle every task in the selection")
map_action("cycle", "Cycle the state of the task under the cursor", "Cycle every task in the selection")

vim.keymap.set("i", "<Plug>(tickbox-newline)", function()
  return require("tickbox.continue").newline()
end, { expr = true, desc = "Start a new line, continuing a task list" })

vim.keymap.set("n", "<Plug>(tickbox-open-below)", function()
  return require("tickbox.continue").open("o")
end, { expr = true, desc = "Open a line below, continuing a task list" })

vim.keymap.set("n", "<Plug>(tickbox-open-above)", function()
  return require("tickbox.continue").open("O")
end, { expr = true, desc = "Open a line above, continuing a task list" })

local subcommands = {
  toggle = function(args)
    -- Without a range, both default to the cursor line.
    require("tickbox").toggle_range(args.line1, args.line2)
  end,
  cycle = function(args)
    require("tickbox").cycle_range(args.line1, args.line2)
  end,
  enable = function()
    require("tickbox").enable()
  end,
  disable = function()
    require("tickbox").disable()
  end,
}

vim.api.nvim_create_user_command("Tickbox", function(args)
  local run = subcommands[args.args]
  if not run then
    error("Tickbox: unknown subcommand: " .. args.args, 0)
  end
  run(args)
end, {
  nargs = 1,
  range = true,
  desc = "Toggle or cycle tasks, or enable or disable rendering in this buffer",
  complete = function(lead, line)
    if line:match("Tickbox%s+%S+%s") then
      return {}
    end
    return vim.tbl_filter(function(name)
      return vim.startswith(name, lead)
    end, { "toggle", "cycle", "enable", "disable" })
  end,
})
