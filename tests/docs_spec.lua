local function read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

-- Everything a user can set or call. Listed by hand because the docs are checked
-- against what the plugin promises, not against its internal tables. Terms are specific
-- so one cannot pass by matching inside another, as "checked" would inside "unchecked".
local surface = {
  "filetypes = {",
  "icons = {",
  "unchecked = ",
  " checked = ",
  ":Tickbox toggle",
  ":Tickbox enable",
  ":Tickbox disable",
  "<Plug>(tickbox-toggle)",
  "<Plug>(tickbox-newline)",
  "<Plug>(tickbox-open-below)",
  "<Plug>(tickbox-open-above)",
  'require("cmp").visible()',
  "TickboxUnchecked",
  "TickboxChecked",
  "DiagnosticOk",
  'require("tickbox").setup(',
  'require("tickbox").toggle()',
  'vim.fn.bufnr("#") ~= -1',
  "make test",
  "PLENARY_DIR",
}

local api = {
  ["README.md"] = {
    "`setup(opts?)`",
    "`toggle()`",
    "`toggle_range(first, last)`",
    "`enable(buf?)`",
    "`disable(buf?)`",
    "`is_enabled(buf?)`",
  },
  ["doc/tickbox.txt"] = {
    "*tickbox.setup()*",
    "*tickbox.toggle()*",
    "*tickbox.toggle_range()*",
    "*tickbox.enable()*",
    "*tickbox.disable()*",
    "*tickbox.is_enabled()*",
  },
}

describe("docs", function()
  for _, path in ipairs({ "README.md", "doc/tickbox.txt" }) do
    for _, term in ipairs(vim.list_extend(vim.deepcopy(surface), api[path])) do
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
      "<Plug>(tickbox-newline)",
      "<Plug>(tickbox-open-below)",
      "<Plug>(tickbox-open-above)",
      "TickboxChecked",
      "TickboxUnchecked",
    }) do
      it("opens the doc for " .. tag, function()
        vim.cmd("help " .. vim.fn.escape(tag, " "))
        assert.are.equal("tickbox.txt", vim.fn.expand("%:t"))
      end)
    end

    it("defines the plain tickbox tag", function()
      -- `:help tickbox` alone would also land on the file through tickbox.txt.
      assert.is_truthy(("\n" .. read("doc/tags")):find("\ntickbox\t", 1, true))
    end)
  end)
end)
