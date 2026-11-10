-- Config for the README recording only. assets/demo.tape starts nvim with it from
-- the repo root, so the plugin loads from the checkout rather than an install.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showcmd = false
vim.o.termguicolors = true
vim.o.shiftwidth = 2
vim.o.expandtab = true
-- The markdown ftplugin would otherwise force a 4-space indent, so >> would not
-- line a child up under its parent's text.
vim.g.markdown_recommended_style = 0
vim.g.mapleader = " "

-- The Dracula palette, set by hand so the recording needs no colorscheme plugin.
local c = {
  bg = "#282a36",
  line = "#44475a",
  fg = "#f8f8f2",
  comment = "#6272a4",
  cyan = "#8be9fd",
  green = "#50fa7b",
  orange = "#ffb86c",
  pink = "#ff79c6",
  purple = "#bd93f9",
  red = "#ff5555",
}
local function hl(name, val)
  vim.api.nvim_set_hl(0, name, val)
end
hl("Normal", { fg = c.fg, bg = c.bg })
hl("Comment", { fg = c.comment })
hl("NonText", { fg = c.line })
hl("EndOfBuffer", { fg = c.line })
hl("Visual", { bg = c.line })
hl("Folded", { fg = c.comment, bg = c.bg })
hl("ModeMsg", { fg = c.green, bold = true })
hl("MsgArea", { fg = c.fg, bg = c.bg })
hl("Title", { fg = c.purple, bold = true })
hl("@markup.heading", { fg = c.purple, bold = true })
hl("Special", { fg = c.cyan })
hl("Delimiter", { fg = c.pink })
hl("Underlined", { fg = c.cyan, underline = true })
hl("DiagnosticOk", { fg = c.green })
hl("DiagnosticWarn", { fg = c.orange })
-- Red rather than the default Comment link, so a cancelled box stands out.
hl("TickboxCancelled", { fg = c.red })

vim.cmd("runtime plugin/tickbox.lua")
require("tickbox").setup({ progress = true, auto_check_parent = true, fold = true })

hl("TickboxCheckedText", { fg = c.comment, strikethrough = true })

vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
vim.keymap.set({ "n", "x" }, "<leader>c", "<Plug>(tickbox-cycle)")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("i", "<CR>", "<Plug>(tickbox-newline)", { buffer = args.buf })
    vim.keymap.set("n", "o", "<Plug>(tickbox-open-below)", { buffer = args.buf })
  end,
})
