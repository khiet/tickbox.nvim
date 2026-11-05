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

local subcommands = {
  toggle = function()
    require("tickbox").toggle()
  end,
}

vim.api.nvim_create_user_command("Tickbox", function(args)
  local run = subcommands[args.args]
  if not run then
    error("Tickbox: unknown subcommand: " .. args.args, 0)
  end
  run()
end, {
  nargs = 1,
  desc = "Toggle tasks",
  complete = function()
    return vim.tbl_keys(subcommands)
  end,
})
