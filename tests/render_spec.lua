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
  end)

  it("keeps a colorscheme override of the highlight groups", function()
    vim.api.nvim_set_hl(0, "TickboxChecked", { link = "Title" })
    require("tickbox").setup()
    assert.are.equal("Title", vim.api.nvim_get_hl(0, { name = "TickboxChecked" }).link)
    vim.api.nvim_set_hl(0, "TickboxChecked", { link = "DiagnosticOk" })
  end)

  it("colours each glyph with its own group", function()
    h.open({ "- [ ] foo", "- [x] bar" })
    local function glyph_attrs()
      vim.cmd("redraw!")
      return vim.fn.screenattr(1, 1), vim.fn.screenattr(2, 1)
    end
    vim.api.nvim_set_hl(0, "TickboxUnchecked", { bold = true })
    vim.api.nvim_set_hl(0, "TickboxChecked", { italic = true })
    local unchecked, checked = glyph_attrs()

    -- Restyling one group must change only that group's glyph.
    vim.api.nvim_set_hl(0, "TickboxUnchecked", { underline = true })
    local restyled_unchecked, same_checked = glyph_attrs()

    vim.api.nvim_set_hl(0, "TickboxUnchecked", { link = "Comment" })
    vim.api.nvim_set_hl(0, "TickboxChecked", { link = "DiagnosticOk" })
    assert.are_not.equal(unchecked, restyled_unchecked)
    assert.are.equal(checked, same_checked)
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
