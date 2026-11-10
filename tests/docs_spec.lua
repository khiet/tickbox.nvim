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
  "in_progress = ",
  "cancelled = ",
  "[/]",
  "[-]",
  "◐",
  "☒",
  ":Tickbox toggle",
  ":Tickbox cycle",
  ":Tickbox set",
  ":Tickbox enable",
  ":Tickbox disable",
  "<Plug>(tickbox-toggle)",
  "<Plug>(tickbox-cycle)",
  "<Plug>(tickbox-set-unchecked)",
  "<Plug>(tickbox-set-in-progress)",
  "<Plug>(tickbox-set-checked)",
  "<Plug>(tickbox-set-cancelled)",
  "<Plug>(tickbox-newline)",
  "<Plug>(tickbox-open-below)",
  "<Plug>(tickbox-open-above)",
  'require("cmp").visible()',
  "TickboxUnchecked",
  "TickboxChecked",
  "TickboxInProgress",
  "TickboxCancelled",
  "TickboxCheckedText",
  "TickboxProgress",
  "progress = false",
  "auto_check_parent = false",
  "fold = false",
  "links = true",
  "compact = true",
  "TickboxLink",
  "gx",
  "foldexpr",
  "fillchars",
  "same or a higher level",
  "greater indentation",
  "DiagnosticOk",
  "DiagnosticWarn",
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
    "`cycle()`",
    "`cycle_range(first, last)`",
    "`set(state)`",
    "`set_range(state, first, last)`",
    "`enable(buf?)`",
    "`disable(buf?)`",
    "`is_enabled(buf?)`",
  },
  ["doc/tickbox.txt"] = {
    "*tickbox.setup()*",
    "*tickbox.toggle()*",
    "*tickbox.toggle_range()*",
    "*tickbox.cycle()*",
    "*tickbox.cycle_range()*",
    "*tickbox.set()*",
    "*tickbox.set_range()*",
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

  -- Both promises are true only while `links` and `compact` are off, so they must say so.
  for _, path in ipairs({ "README.md", "doc/tickbox.txt" }) do
    it(path .. " qualifies its treesitter and conceallevel promise", function()
      local doc = read(path):gsub("%s+", " ")
      for promise in doc:gmatch("[Nn]o treesitter[^.]*%.") do
        assert.is_truthy(promise:find("links", 1, true), promise)
        assert.is_truthy(promise:find("compact", 1, true), promise)
      end
      assert.is_truthy(doc:find("[Nn]o treesitter"))
    end)
  end

  -- Costs of `compact` that are accepted rather than fixed, so the docs must own up to them.
  for _, path in ipairs({ "README.md", "doc/tickbox.txt" }) do
    it(path .. " lists the accepted costs of compact", function()
      local doc = read(path):gsub("%s+", " ")
      for _, cost in ipairs({ "wraps 4 cells early", "shifts 4 cells right", "cross the hidden prefix" }) do
        assert.is_truthy(doc:find(cost, 1, true), cost)
      end
    end)
  end

  it("README shows a lazy.nvim install", function()
    assert.is_truthy(read("README.md"):find('ft = "markdown"', 1, true))
  end)

  -- The README is read top to bottom by someone deciding whether to install, so its
  -- order is part of the contract: picture, pitch and quickstart first, rules last.
  describe("README for first-time visitors", function()
    local readme

    -- Byte offset of a heading line, so tests can say "between X and Y".
    local function heading(text)
      local at = readme:find("\n" .. text .. "\n", 1, true)
      assert.is_truthy(at, "heading " .. text)
      return at
    end

    local function between(term, first, last)
      local at = readme:find(term, heading(first), true)
      assert.is_truthy(at, term .. " after " .. first)
      assert.is_true(at < heading(last), term .. " before " .. last)
    end

    before_each(function()
      readme = read("README.md")
    end)

    it("embeds the demo recording before the first section", function()
      local at = readme:find("](assets/demo.gif)", 1, true)
      assert.is_truthy(at)
      assert.is_true(at < readme:find("\n## ", 1, true))
    end)

    it("ships the tape that renders the recording", function()
      local tape = read("assets/demo.tape")
      assert.is_truthy(tape:find("Output assets/demo.gif", 1, true))
      assert.is_truthy(tape:find("Nerd Font", 1, true))
    end)

    it("names the full-rendering plugins in the intro and has no Alternatives section", function()
      local first_section = readme:find("\n## ", 1, true)
      assert.is_true(readme:find("render-markdown.nvim", 1, true) < first_section)
      assert.is_true(readme:find("markview.nvim", 1, true) < first_section)
      assert.is_nil(readme:find("\n## Alternatives", 1, true))
    end)

    it("binds toggle and cycle in the quickstart and follows it with Try it steps", function()
      between("<Plug>(tickbox-toggle)", "## Quickstart", "## Configuration")
      between("<Plug>(tickbox-cycle)", "## Quickstart", "## Configuration")
      between("1. Open any markdown file", "## Quickstart", "## Configuration")
    end)

    it("puts the Unicode icons in Requirements and the filetypes caveat in Configuration", function()
      between('unchecked = "☐"', "## Requirements", "## Quickstart")
      between("both `ft` fields", "## Configuration", "## Usage")
    end)

    it("lists folding in Features and shows every opt-in option on", function()
      between("fold", "## Features", "## Requirements")
      between("opts = { progress = true, auto_check_parent = true, fold = true }", "## Features", "## Requirements")
    end)

    it("points each shortened rules section at the help file", function()
      between("`:h tickbox-progress`", "### Progress and parents", "### Folding")
      between("`:h tickbox-fold`", "### Folding", "### Compact box")
      between("`:h tickbox-compact`", "### Compact box", "### Links")
      between("`:h tickbox-links`", "### Links", "### Commands")
      between("`:h tickbox-tasks`", "## Task syntax", "## Recipes")
    end)

    it("ends with Recipes before Contributing", function()
      between('require("cmp").visible()', "## Recipes", "## Contributing")
      between("<leader><leader>", "## Recipes", "## Contributing")
      assert.is_true(heading("## Highlights") < heading("## Recipes"))
    end)
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
      "<Plug>(tickbox-cycle)",
      "<Plug>(tickbox-set-unchecked)",
      "<Plug>(tickbox-set-in-progress)",
      "<Plug>(tickbox-set-checked)",
      "<Plug>(tickbox-set-cancelled)",
      "<Plug>(tickbox-newline)",
      "<Plug>(tickbox-open-below)",
      "<Plug>(tickbox-open-above)",
      "TickboxChecked",
      "TickboxUnchecked",
      "TickboxInProgress",
      "TickboxCancelled",
      "TickboxCheckedText",
      "tickbox-states",
      "tickbox-progress",
      "tickbox-fold",
      "tickbox-compact",
      "tickbox-links",
      "tickbox-tasks",
      "TickboxProgress",
      "TickboxLink",
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
