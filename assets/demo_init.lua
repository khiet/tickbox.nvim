-- Config for the README recording only. assets/demo.tape starts nvim with it from
-- the repo root, so the plugin loads from the checkout rather than an install.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.termguicolors = true
vim.g.mapleader = " "

vim.cmd("runtime plugin/tickbox.lua")
require("tickbox").setup({ progress = true, auto_check_parent = true, fold = true })

local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
vim.api.nvim_set_hl(0, "TickboxCheckedText", vim.tbl_extend("force", comment, { strikethrough = true }))

vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
vim.keymap.set({ "n", "x" }, "<leader>c", "<Plug>(tickbox-cycle)")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("i", "<CR>", "<Plug>(tickbox-newline)", { buffer = args.buf })
  end,
})
