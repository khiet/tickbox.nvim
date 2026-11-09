local h = require("tests.helpers")

describe("rendering", function()
  it("draws glyphs over the marker and keeps the text column", function()
    h.open({ "- [ ] foo", "- [x] bar" })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
    assert.are.equal(h.CHECKED .. "     bar", h.screen_line(2))
  end)

  it("preserves indentation of nested items", function()
    local buf = h.open({ "- [ ] parent", "    - [x] child", "\t* [ ] tabbed" })
    vim.bo[buf].tabstop = 8
    assert.are.equal(h.UNCHECKED .. "     parent", h.screen_line(1))
    assert.are.equal("    " .. h.CHECKED .. "     child", h.screen_line(2))
    assert.are.equal("        " .. h.UNCHECKED .. "     tabbed", h.screen_line(3))
  end)

  it("draws every marker style and a capital X", function()
    h.open({ "* [ ] a", "+ [x] b", "1. [ ] c", "2) [X] d", "- [X] e" })
    assert.are.equal(h.UNCHECKED .. "     a", h.screen_line(1))
    assert.are.equal(h.CHECKED .. "     b", h.screen_line(2))
    assert.are.equal(h.UNCHECKED .. "      c", h.screen_line(3))
    assert.are.equal(h.CHECKED .. "      d", h.screen_line(4))
    assert.are.equal(h.CHECKED .. "     e", h.screen_line(5))
  end)

  it("draws in-progress and cancelled glyphs in the box's column", function()
    h.open({ "- [/] a", "- [-] b", "1. [/] c", "    * [-] d", "```", "- [/] sample", "```" })
    assert.are.equal(h.IN_PROGRESS .. "     a", h.screen_line(1))
    assert.are.equal(h.CANCELLED .. "     b", h.screen_line(2))
    assert.are.equal(h.IN_PROGRESS .. "      c", h.screen_line(3))
    assert.are.equal("    " .. h.CANCELLED .. "     d", h.screen_line(4))
    assert.are.equal("- [/] sample", h.screen_line(6))
  end)

  it("leaves task-looking lines inside a fence raw", function()
    h.open({ "```", "- [ ] sample", "```", "- [ ] real" })
    assert.are.equal("- [ ] sample", h.screen_line(2))
    assert.are.equal(h.UNCHECKED .. "     real", h.screen_line(4))
  end)

  describe("with a fence above the viewport", function()
    local function open_scrolled(lines)
      for _ = 1, 50 do
        table.insert(lines, #lines, "filler")
      end
      h.open(lines)
      vim.fn.winrestview({ topline = #lines, lnum = #lines })
    end

    it("leaves lines inside it raw", function()
      open_scrolled({ "```", "- [ ] sample" })
      assert.are.equal("- [ ] sample", h.screen_line(1))
    end)

    it("renders below it once it has closed", function()
      open_scrolled({ "```", "```", "- [ ] real" })
      assert.are.equal(h.UNCHECKED .. "     real", h.screen_line(1))
    end)
  end)

  it("handles a fence opened on a list marker", function()
    h.open({ "- ```", "  - [ ] sample", "  ```", "- [ ] real" })
    assert.are.equal("  - [ ] sample", h.screen_line(2))
    assert.are.equal(h.UNCHECKED .. "     real", h.screen_line(4))
  end)

  it("picks up a fence edit above a task", function()
    local buf = h.open({ "text", "- [ ] foo" })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(2))
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "```" })
    assert.are.equal("- [ ] foo", h.screen_line(2))
  end)

  it("draws nothing over other markdown", function()
    local lines = {
      "# heading",
      "*emphasis* and **strong**",
      "[link](https://example.com)",
      "| a | b |",
      "|---|---|",
      "- plain item",
    }
    h.open(lines)
    for row, line in ipairs(lines) do
      assert.are.equal(line, h.screen_line(row))
    end
  end)

  it("leaves other filetypes raw", function()
    h.open({ "- [ ] foo" }, "text")
    assert.are.equal("- [ ] foo", h.screen_line(1))
  end)

  it("stops rendering when the filetype changes away", function()
    local buf = h.open({ "- [ ] foo" })
    vim.bo[buf].filetype = "text"
    assert.are.equal("- [ ] foo", h.screen_line(1))
  end)

  it("attaches to buffers opened before the plugin started", function()
    vim.o.eventignore = "FileType"
    h.open({ "- [ ] foo" })
    vim.o.eventignore = ""
    assert.are.equal("- [ ] foo", h.screen_line(1))

    require("tickbox").setup()
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
  end)

  it("follows text changes and undo", function()
    local buf = h.open({ "plain" })
    assert.are.equal("plain", h.screen_line(1))

    -- A fresh undo block, so `undo` below reverts only this edit.
    vim.bo[buf].undolevels = vim.bo[buf].undolevels
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [ ] foo" })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))

    vim.cmd("undo")
    assert.are.equal("plain", h.screen_line(1))
  end)

  it("survives :e reloading the file", function()
    local path = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ "- [ ] foo" }, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))

    vim.fn.writefile({ "- [x] bar" }, path)
    vim.cmd("edit!")
    assert.are.equal(h.CHECKED .. "     bar", h.screen_line(1))
    vim.cmd("bwipeout!")
    vim.fn.delete(path)
  end)

  it("defines overridable highlight groups", function()
    assert.are.same(
      { default = true, link = "Comment" },
      vim.api.nvim_get_hl(0, { name = "TickboxUnchecked" })
    )
    assert.are.same(
      { default = true, link = "DiagnosticOk" },
      vim.api.nvim_get_hl(0, { name = "TickboxChecked" })
    )
    assert.are.same(
      { default = true, link = "DiagnosticWarn" },
      vim.api.nvim_get_hl(0, { name = "TickboxInProgress" })
    )
    assert.are.same(
      { default = true, link = "Comment" },
      vim.api.nvim_get_hl(0, { name = "TickboxCancelled" })
    )
    -- No attributes, so done text looks unchanged until the user styles it.
    assert.are.same({ default = true }, vim.api.nvim_get_hl(0, { name = "TickboxCheckedText" }))
    assert.are.same(
      { default = true, link = "Comment" },
      vim.api.nvim_get_hl(0, { name = "TickboxProgress" })
    )
  end)

  it("keeps a colorscheme override of the highlight groups", function()
    vim.api.nvim_set_hl(0, "TickboxChecked", { link = "Title" })
    require("tickbox").setup()
    assert.are.equal("Title", vim.api.nvim_get_hl(0, { name = "TickboxChecked" }).link)
    vim.api.nvim_set_hl(0, "TickboxChecked", { link = "DiagnosticOk" })
  end)

  it("colours each glyph with its own group", function()
    h.open({ "- [ ] a", "- [/] b", "- [x] c", "- [-] d" })
    local groups = { "TickboxUnchecked", "TickboxInProgress", "TickboxChecked", "TickboxCancelled" }
    local links = {}
    for _, name in ipairs(groups) do
      links[name] = vim.api.nvim_get_hl(0, { name = name }).link
      vim.api.nvim_set_hl(0, name, { bold = true })
    end
    local function glyph_attrs()
      vim.cmd("redraw!")
      local attrs = {}
      for row = 1, #groups do
        attrs[row] = vim.fn.screenattr(row, 1)
      end
      return attrs
    end

    -- Restyling one group must change only that group's glyph.
    local changed = {}
    for row, name in ipairs(groups) do
      local before = glyph_attrs()
      vim.api.nvim_set_hl(0, name, { underline = true })
      local after = glyph_attrs()
      vim.api.nvim_set_hl(0, name, { bold = true })
      changed[row] = {}
      for other = 1, #groups do
        changed[row][other] = before[other] ~= after[other]
      end
    end

    for _, name in ipairs(groups) do
      vim.api.nvim_set_hl(0, name, { link = links[name] })
    end
    for row = 1, #groups do
      for other = 1, #groups do
        assert.are.equal(row == other, changed[row][other], groups[row] .. " on row " .. other)
      end
    end
  end)

  describe("padding over a prefix treesitter reads as a link", function()
    local groups = { "@markup.link", "@markup.list", "@markup.list.unchecked", "CursorLine" }
    local saved = {}

    -- The marker groups go blank so that a `[ ]` line's padding has no foreground and
    -- differs from a `[/]` line's only by what the link capture adds.
    local function style_groups()
      vim.api.nvim_set_hl(0, "@markup.link", { underline = true })
      vim.api.nvim_set_hl(0, "@markup.list", {})
      vim.api.nvim_set_hl(0, "@markup.list.unchecked", {})
      vim.api.nvim_set_hl(0, "CursorLine", { bg = "#333333" })
    end

    before_each(function()
      for _, name in ipairs(groups) do
        saved[name] = vim.api.nvim_get_hl(0, { name = name })
      end
      style_groups()
    end)

    after_each(function()
      vim.wo.cursorline = false
      for name, hl in pairs(saved) do
        vim.api.nvim_set_hl(0, name, hl)
      end
    end)

    -- `[/]` and `[-]` are not GFM task markers, so markdown_inline captures their brackets
    -- as @markup.link. Screen columns 3 and 5 hold those brackets, under the padding.
    local function assert_matches_plain_box(line)
      local buf = h.open({ line, "- [ ] a", "plain" })
      vim.treesitter.start(buf, "markdown")
      vim.wo.cursorline = true

      local function attrs_with_cursor_on(lnum, row)
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
        vim.cmd("redraw!")
        return { vim.fn.screenattr(row, 3), vim.fn.screenattr(row, 5) }
      end

      local off_cursorline = attrs_with_cursor_on(3, 1)
      assert.are.same(attrs_with_cursor_on(3, 2), off_cursorline)

      local on_cursorline = attrs_with_cursor_on(1, 1)
      assert.are.same(attrs_with_cursor_on(2, 2), on_cursorline)
      assert.are_not.same(off_cursorline, on_cursorline)
    end

    for _, line in ipairs({ "- [/] a", "- [-] a" }) do
      it("hides the link underline on " .. line .. " and keeps cursorline", function()
        assert_matches_plain_box(line)
      end)
    end

    it("still hides it after the colorscheme changes", function()
      -- Loading a colorscheme runs `hi clear`, which also resets the styled groups.
      vim.cmd("colorscheme default")
      style_groups()
      assert_matches_plain_box("- [/] a")
    end)
  end)

  describe("done text", function()
    local lines = { "- [ ] a", "- [/] b", "- [x] c", "- [X] d", "- [-] e", "plain" }

    -- Screen attributes of each row's first and last text columns and of the space
    -- between the box and the text.
    local function text_attrs()
      vim.cmd("redraw!")
      local attrs = {}
      for row = 1, #lines do
        attrs[row] = {
          first = vim.fn.screenattr(row, 7),
          last = vim.fn.screenattr(row, 9),
          space = vim.fn.screenattr(row, 6),
        }
      end
      return attrs
    end

    after_each(function()
      vim.api.nvim_set_hl(0, "TickboxCheckedText", { default = true })
    end)

    it("is unstyled by default", function()
      h.open({ "- [ ] abc", "- [x] abc", "plain abc" })
      vim.cmd("redraw!")
      for row = 1, 3 do
        assert.are.equal(vim.fn.screenattr(3, 7), vim.fn.screenattr(row, 7), "row " .. row)
      end
    end)

    it("uses TickboxCheckedText on checked lines only", function()
      local text = {}
      for i, line in ipairs(lines) do
        text[i] = line .. "zz"
      end
      h.open(text)
      vim.api.nvim_set_hl(0, "TickboxCheckedText", { strikethrough = true })
      local attrs = text_attrs()
      local plain = attrs[#lines].first
      for row = 1, #lines do
        local checked = row == 3 or row == 4
        assert.are.equal(checked, attrs[row].first ~= plain, "row " .. row)
        assert.are.equal(checked, attrs[row].last ~= plain, "row " .. row)
        assert.are.equal(plain, attrs[row].space, "row " .. row)
      end
    end)
  end)

  it("does not cover task text when scrolled horizontally", function()
    h.open({ "- [ ] foo abcdefghij" })
    vim.wo.wrap = false
    -- The cursor must sit on the text, or nvim scrolls back to keep it visible.
    vim.fn.winrestview({ col = 15, leftcol = 7 })
    local line = h.screen_line(1)
    vim.fn.winrestview({ col = 0, leftcol = 0 })
    vim.wo.wrap = true
    assert.are.equal("oo abcdefghij", line)
  end)
end)
