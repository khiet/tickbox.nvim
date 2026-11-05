if vim.g.loaded_tickbox then
  return
end
vim.g.loaded_tickbox = true

require("tickbox").setup()
