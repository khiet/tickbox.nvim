local render = require("tickbox.render")

local M = {}

M.config = {
  filetypes = { "markdown" },
  icons = { unchecked = "󰄱", checked = "󰱒" },
}

function M.setup()
  render.start(M.config)
end

return M
