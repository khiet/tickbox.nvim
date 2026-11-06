local h = require("tests.helpers")
local tickbox = require("tickbox")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function toggle_at(lnum)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  return tickbox.toggle()
end

describe("auto_check_parent", function()
  before_each(function()
    tickbox.setup({ auto_check_parent = true })
  end)

  after_each(function()
    tickbox.setup()
  end)

  it("is off by default", function()
    tickbox.setup()
    h.open({ "- [ ] parent", "  - [ ] a" })
    toggle_at(2)
    assert.are.same({ "- [ ] parent", "  - [x] a" }, lines())
  end)

  it("checks the parent and the grandparent it completes, in one undo step", function()
    local before = { "- [ ] top", "  - [x] done", "  - [ ] mid", "    - [x] b", "    - [ ] c", "    - [-] gone" }
    h.open(before)
    h.pause()
    toggle_at(5)
    assert.are.same({
      "- [x] top",
      "  - [x] done",
      "  - [x] mid",
      "    - [x] b",
      "    - [x] c",
      "    - [-] gone",
    }, lines())
    vim.cmd("undo")
    assert.are.same(before, lines())
  end)

  it("checks the parent but not a grandparent with other open tasks", function()
    h.open({ "- [ ] top", "  - [ ] other", "  - [ ] mid", "    - [ ] c" })
    toggle_at(4)
    assert.are.same({ "- [ ] top", "  - [ ] other", "  - [x] mid", "    - [x] c" }, lines())
  end)

  it("checks an in-progress parent once its children are done", function()
    h.open({ "- [/] parent", "  - [/] a" })
    toggle_at(2)
    assert.are.same({ "- [x] parent", "  - [x] a" }, lines())
  end)

  it("unchecks checked ancestors when a child is unchecked", function()
    h.open({ "- [x] top", "  - [x] mid", "    - [x] c" })
    toggle_at(3)
    assert.are.same({ "- [ ] top", "  - [ ] mid", "    - [ ] c" }, lines())
  end)

  it("unchecks a checked parent when a cycle moves a child to in progress", function()
    h.open({ "- [x] parent", "  - [ ] a", "  - [x] b" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    tickbox.cycle()
    assert.are.same({ "- [ ] parent", "  - [/] a", "  - [x] b" }, lines())
  end)

  it("leaves a cancelled parent alone but still walks past it", function()
    h.open({ "- [ ] top", "  - [-] mid", "    - [ ] c" })
    toggle_at(3)
    -- With mid cancelled, c is top's only counted descendant.
    assert.are.same({ "- [x] top", "  - [-] mid", "    - [x] c" }, lines())
    h.open({ "- [x] top", "  - [x] other", "  - [-] mid", "    - [x] c" })
    toggle_at(4)
    assert.are.same({ "- [ ] top", "  - [x] other", "  - [-] mid", "    - [ ] c" }, lines())
  end)

  it("never changes a toggled parent's children", function()
    h.open({ "- [ ] parent", "  - [ ] a", "  - [x] b" })
    toggle_at(1)
    assert.are.same({ "- [x] parent", "  - [ ] a", "  - [x] b" }, lines())
    toggle_at(1)
    assert.are.same({ "- [ ] parent", "  - [ ] a", "  - [x] b" }, lines())
  end)

  it("never uses headings", function()
    h.open({ "# H", "- [ ] a" })
    toggle_at(2)
    assert.are.same({ "# H", "- [x] a" }, lines())
  end)

  it("propagates once after a range toggle, in one undo step", function()
    local before = { "- [ ] parent", "  - [ ] a", "  - [ ] b" }
    h.open(before)
    h.pause()
    assert.is_true(tickbox.toggle_range(2, 3))
    assert.are.same({ "- [x] parent", "  - [x] a", "  - [x] b" }, lines())
    vim.cmd("undo")
    assert.are.same(before, lines())
  end)

  it("ignores fenced lines", function()
    h.open({ "- [ ] parent", "  ```", "  - [ ] sample", "  ```", "  - [ ] a" })
    toggle_at(5)
    assert.are.equal("- [x] parent", lines()[1])
    assert.are.equal("  - [ ] sample", lines()[3])
  end)
end)
