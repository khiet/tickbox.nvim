local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

-- Everything a user can set or call. Listed by hand because the docs are checked
-- against what the plugin promises, not against its internal tables.
local surface = {
  "filetypes",
  "icons",
  "unchecked",
  "checked",
  ":Tickbox toggle",
  ":Tickbox enable",
  ":Tickbox disable",
  "<Plug>(tickbox-toggle)",
  "TickboxUnchecked",
  "TickboxChecked",
  "setup",
  "toggle()",
  "toggle_range",
  "enable",
  "disable",
  "is_enabled",
  "make test",
}

describe("docs", function()
  for _, path in ipairs({ "README.md", "doc/tickbox.txt" }) do
    for _, term in ipairs(surface) do
      it(path .. " covers " .. term, function()
        assert.is_truthy(read(path):find(term, 1, true))
      end)
    end

    it(path .. " shows the fallback recipe", function()
      local doc = read(path)
      assert.is_truthy(doc:find("<leader><leader>", 1, true))
      assert.is_truthy(doc:find("<C-^>", 1, true))
    end)
  end

  it("README shows a lazy.nvim install", function()
    assert.is_truthy(read("README.md"):find('ft = "markdown"', 1, true))
  end)

  describe(":help", function()
    before_each(function()
      vim.cmd("helptags doc")
    end)

    after_each(function()
      vim.cmd("silent! helpclose")
    end)

    for _, tag in ipairs({
      "tickbox",
      "tickbox.setup()",
      ":Tickbox",
      "<Plug>(tickbox-toggle)",
      "TickboxChecked",
    }) do
      it("opens the doc for " .. tag, function()
        vim.cmd("help " .. vim.fn.escape(tag, " "))
        assert.are.equal("tickbox.txt", vim.fn.expand("%:t"))
      end)
    end
  end)
end)
