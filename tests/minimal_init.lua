-- Runs under --noplugin, so plugin files are sourced by hand. This is the same
-- entry point a plugin manager would load.
vim.opt.runtimepath:prepend(vim.env.PLENARY_DIR)
vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
vim.opt.swapfile = false
vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/tickbox.lua")
