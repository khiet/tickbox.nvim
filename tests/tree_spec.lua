local tree = require("tickbox.tree")

local function count(lines, lnum)
  local c = tree.build(lines).counts[lnum]
  return c and (c.done .. "/" .. c.total)
end

describe("tree", function()
  it("counts checked over every state but cancelled", function()
    local lines = { "- [ ] parent", "  - [x] a", "  - [ ] b", "  - [/] c", "  - [-] d" }
    assert.are.equal("1/3", count(lines, 1))
  end)

  it("counts grandchildren toward the top parent", function()
    local lines = { "- [ ] top", "  - [ ] mid", "    - [x] leaf" }
    assert.are.equal("1/2", count(lines, 1))
    assert.are.equal("1/1", count(lines, 2))
  end)

  it("keeps a run going over blank and deeper non-task lines", function()
    local lines = { "- [ ] parent", "  - [x] a", "", "    continued text", "  - [ ] b" }
    assert.are.equal("1/2", count(lines, 1))
  end)

  it("ends a run at a line indented the same or less", function()
    local lines = { "- [ ] parent", "  - [x] a", "text", "  - [ ] b" }
    assert.are.equal("1/1", count(lines, 1))
    local siblings = { "- [ ] one", "- [x] two" }
    assert.is_nil(count(siblings, 1))
  end)

  it("treats a tab as indentation to the next multiple of four", function()
    local lines = { "  - [ ] parent", "\t- [x] child" }
    assert.are.equal("1/1", count(lines, 1))
  end)

  it("counts a heading's tasks until a heading of the same or a higher level", function()
    local lines = {
      "## A",
      "- [x] a1",
      "### A.1",
      "- [ ] a2",
      "## B",
      "- [ ] b1",
      "# C",
      "- [ ] c1",
    }
    assert.are.equal("1/2", count(lines, 1))
    assert.are.equal("0/1", count(lines, 3))
    assert.are.equal("0/1", count(lines, 5))
  end)

  it("ends task runs at a heading", function()
    local lines = { "- [ ] parent", "# H", "  - [x] a" }
    assert.is_nil(count(lines, 1))
  end)

  it("counts nothing for a heading without tasks or a parent of only cancelled tasks", function()
    assert.is_nil(count({ "# H", "text" }, 1))
    assert.is_nil(count({ "- [ ] parent", "  - [-] a" }, 1))
  end)

  it("ignores task-looking lines and headings inside fences", function()
    local lines = { "# H", "- [ ] parent", "  ```", "  - [x] sample", "# fenced", "  ```", "  - [x] real" }
    assert.are.equal("1/1", count(lines, 2))
    assert.are.equal("1/2", count(lines, 1))
  end)

  it("ignores '#' runs that are not headings", function()
    local lines = { "#tag", "####### seven", "- [ ] parent", "  - [x] a" }
    assert.are.equal("1/1", count(lines, 3))
    assert.is_nil(count(lines, 1))
  end)

  it("links tasks to their parent and children", function()
    local t = tree.build({ "- [ ] p", "  - [ ] a", "    - [ ] b", "  - [ ] c" })
    assert.are.same({ 2, 4 }, t.tasks[1].children)
    assert.are.equal(2, t.tasks[3].parent)
    assert.is_nil(t.tasks[1].parent)
  end)
end)
