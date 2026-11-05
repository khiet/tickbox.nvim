if vim.g.loaded_tickbox then
  return
end
vim.g.loaded_tickbox = true

require("tickbox")._ensure_started()

vim.keymap.set("n", "<Plug>(tickbox-toggle)", function()
  -- Going through an operator is what lets `.` repeat the toggle.
  vim.o.operatorfunc = "v:lua.require'tickbox.toggle'.toggle"
  return "g@l"
end, { expr = true, silent = true, desc = "Toggle the task under the cursor" })

vim.keymap.set("x", "<Plug>(tickbox-toggle)", function()
  local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  require("tickbox").toggle_range(math.min(anchor, cursor), math.max(anchor, cursor))
end, { silent = true, desc = "Toggle every task in the selection" })

local subcommands = {
  toggle = function(args)
    if args.range > 0 then
      require("tickbox").toggle_range(args.line1, args.line2)
    else
      require("tickbox").toggle()
    end
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
  desc = "Toggle tasks",
  complete = function()
    return vim.tbl_keys(subcommands)
  end,
})
