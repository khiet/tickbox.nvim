local h = require("tests.helpers")
local tickbox = require("tickbox")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function toggle_at(lnum)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  return tickbox.toggle()
end

-- The rule itself is covered in plan_spec; these cover what only a buffer shows.
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

  it("propagates once after a range toggle, in one undo step", function()
    local before = { "- [ ] parent", "  - [ ] a", "  - [ ] b" }
    h.open(before)
    h.pause()
    assert.is_true(tickbox.toggle_range(2, 3))
    assert.are.same({ "- [x] parent", "  - [x] a", "  - [x] b" }, lines())
    vim.cmd("undo")
    assert.are.same(before, lines())
  end)

  it("parses the buffer once, before the first edit", function()
    local tree = require("tickbox.tree")
    local build = tree.build
    local seen = {}
    tree.build = function(lines)
      table.insert(seen, lines)
      return build(lines)
    end
    h.open({ "- [ ] parent", "  - [ ] a", "  - [ ] b" })
    tickbox.toggle_range(2, 3)
    tree.build = build
    assert.are.same({ "- [x] parent", "  - [x] a", "  - [x] b" }, lines())
    assert.are.same({ { "- [ ] parent", "  - [ ] a", "  - [ ] b" } }, seen)
  end)
end)
