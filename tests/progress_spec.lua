local h = require("tests.helpers")
local tickbox = require("tickbox")

local U, X, C = h.UNCHECKED, h.CHECKED, h.CANCELLED

local function soft(row)
  return h.screen_line(row, { soft = true })
end

describe("progress", function()
  before_each(function()
    tickbox.setup({ progress = true })
  end)

  after_each(function()
    tickbox.setup()
  end)

  it("draws nothing new with default options", function()
    tickbox.setup()
    h.open({ "# H", "- [ ] parent", "  - [x] a" })
    assert.are.equal("# H", h.screen_line(1))
    assert.are.equal(U .. "     parent", h.screen_line(2))
  end)

  it("shows done over total, leaving cancelled tasks out", function()
    h.open({ "- [ ] parent", "  - [x] a", "  - [ ] b", "  - [/] c", "  - [-] d" })
    assert.are.equal(U .. "     parent 1/3", h.screen_line(1))
    assert.are.equal("  " .. X .. "     a", h.screen_line(2))
    assert.are.equal("  " .. C .. "     d", h.screen_line(5))
  end)

  it("shows counts on headings", function()
    h.open({ "## A", "- [x] a", "### A.1", "- [/] b", "# B", "text" })
    assert.are.equal("## A 1/2", h.screen_line(1))
    assert.are.equal("### A.1 0/1", h.screen_line(3))
    assert.are.equal("# B", h.screen_line(5))
  end)

  it("shows nothing inside fences", function()
    h.open({ "```", "# H", "- [ ] p", "  - [x] a", "```" })
    assert.are.equal("# H", h.screen_line(2))
    assert.are.equal("- [ ] p", h.screen_line(3))
  end)

  it("updates the parent while typing a child", function()
    h.open({ "- [ ] parent", "  - [ ] a" })
    assert.are.equal(U .. "     parent 0/1", h.screen_line(1))
    local line
    -- Replaces the child's box interior in place, so only that line changes.
    h.type("2G6|sx<PROBE><Esc>", function()
      line = soft(1)
    end)
    assert.are.equal(U .. "     parent 1/1", line)
  end)

  it("updates a buffer opened before progress was turned on", function()
    tickbox.setup()
    h.open({ "- [ ] parent", "  - [ ] a" })
    tickbox.setup({ progress = true })
    assert.are.equal(U .. "     parent 0/1", h.screen_line(1))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    tickbox.toggle()
    assert.are.equal(U .. "     parent 1/1", soft(1))
  end)

  it("updates after undo", function()
    h.open({ "- [ ] parent", "  - [ ] a" })
    h.pause()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    tickbox.toggle()
    assert.are.equal(U .. "     parent 1/1", soft(1))
    vim.cmd("undo")
    assert.are.equal(U .. "     parent 0/1", soft(1))
  end)

  it("keeps the count on the line being typed", function()
    h.open({ "- [ ] parent", "  - [x] a" })
    local line
    h.type("A<PROBE><Esc>", function()
      line = soft(1)
    end)
    assert.are.equal("- [ ] parent 1/1", line)
  end)

  it("follows disable and enable", function()
    h.open({ "# H", "- [x] a" })
    assert.are.equal("# H 1/1", h.screen_line(1))
    tickbox.disable()
    assert.are.equal("# H", soft(1))
    tickbox.enable()
    assert.are.equal("# H 1/1", soft(1))
  end)
end)
