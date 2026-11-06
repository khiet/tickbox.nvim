local h = require("tests.helpers")
local tickbox = require("tickbox")

describe("setup", function()
  after_each(function()
    tickbox.setup()
  end)

  it("draws custom icons in the task text's raw column", function()
    tickbox.setup({ icons = { unchecked = "o", checked = "✓" } })
    h.open({ "- [ ] foo", "- [x] bar" })
    assert.are.equal("o     foo", h.screen_line(1))
    assert.are.equal("✓     bar", h.screen_line(2))
  end)

  it("keeps the text column for a double-width icon", function()
    tickbox.setup({ icons = { checked = "✅" } })
    h.open({ "- [x] bar" })
    assert.are.equal(2, vim.fn.strdisplaywidth("✅"))
    vim.cmd("redraw!")
    assert.are.equal("b", vim.fn.screenstring(1, 7))
  end)

  it("fills in the icons left out of a partial table", function()
    tickbox.setup({ icons = { checked = "☑" } })
    h.open({ "- [ ] foo", "- [/] baz", "- [x] bar", "- [-] qux" })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
    assert.are.equal(h.IN_PROGRESS .. "     baz", h.screen_line(2))
    assert.are.equal("☑     bar", h.screen_line(3))
    assert.are.equal(h.CANCELLED .. "     qux", h.screen_line(4))
  end)

  it("draws custom in-progress and cancelled icons", function()
    tickbox.setup({ icons = { in_progress = "◐", cancelled = "☒" } })
    h.open({ "- [/] baz", "- [-] qux" })
    assert.are.equal("◐     baz", h.screen_line(1))
    assert.are.equal("☒     qux", h.screen_line(2))
  end)

  it("attaches to listed filetypes only", function()
    tickbox.setup({ filetypes = { "notes" } })
    h.open({ "- [ ] foo" }, "notes")
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
    h.open({ "- [ ] foo" }, "markdown")
    assert.are.equal("- [ ] foo", h.screen_line(1))
  end)

  it("applies a filetype change to open buffers", function()
    h.open({ "- [ ] foo" }, "notes")
    assert.are.equal("- [ ] foo", h.screen_line(1))
    tickbox.setup({ filetypes = { "notes" } })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
  end)

  it("starts each call from the defaults", function()
    tickbox.setup({ icons = { unchecked = "o" } })
    tickbox.setup({ icons = { checked = "x" } })
    h.open({ "- [ ] foo" })
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
  end)

  it("keeps options set before the plugin file is sourced", function()
    tickbox.setup({ icons = { unchecked = "o" } })
    vim.g.loaded_tickbox = nil
    vim.cmd("runtime plugin/tickbox.lua")
    h.open({ "- [ ] foo" })
    assert.are.equal("o     foo", h.screen_line(1))
  end)

  it("reveals the cursor line when setup attaches during insert mode", function()
    h.open({ "- [ ] foo" }, "notes")
    local line
    h.type("i<PROBE><Esc>", function()
      tickbox.setup({ filetypes = { "notes" } })
      line = h.screen_line(1)
    end)
    assert.are.equal("- [ ] foo", line)
  end)

  it("still loads defaults after a failed setup", function()
    tickbox.setup({ filetypes = { "notes" } })
    -- A fresh module instance has never started, like a session's first setup call.
    package.loaded["tickbox"] = nil
    pcall(require("tickbox").setup, "not a table")
    vim.g.loaded_tickbox = nil
    vim.cmd("runtime plugin/tickbox.lua")
    package.loaded["tickbox"] = tickbox

    h.open({ "- [ ] foo" }, "markdown")
    assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
  end)

  it("names the minimum version on an unsupported Neovim", function()
    local has = vim.fn.has
    vim.fn.has = function(feature)
      return feature == "nvim-0.10" and 0 or has(feature)
    end
    local ok, err = pcall(tickbox.setup)
    vim.fn.has = has
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("0.10", 1, true))
  end)
end)
