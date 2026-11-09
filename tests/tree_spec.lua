local tree = require("tickbox.tree")

local function count(lines, lnum)
  local c = tree.build(lines).counts[lnum]
  return c and (c.done .. "/" .. c.total)
end

describe("tree", function()
  it("is the only module that reads buffer lines and classifies tasks", function()
    for _, name in ipairs({ "render", "toggle", "continue", "plan" }) do
      local source = table.concat(vim.fn.readfile(("lua/tickbox/%s.lua"):format(name)), "\n")
      assert.is_nil(source:find("tickbox.parse", 1, true), name .. " requires parse")
      assert.is_nil(source:find("nvim_buf_get_lines", 1, true), name .. " reads buffer lines")
    end
  end)

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

  it("ends task runs at a heading only by its indentation", function()
    assert.is_nil(count({ "- [ ] parent", "# H", "  - [x] a" }, 1))
    assert.are.equal("1/1", count({ "- [ ] parent", "  ## H", "  - [x] a" }, 1))
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

  it("leaves fenced lines out of tasks", function()
    local t = tree.build({ "- [ ] one", "```", "- [ ] sample", "```", "- [ ] two" })
    assert.is_nil(t.tasks[3])
    assert.are.equal("unchecked", t.tasks[1].state)
    assert.are.equal("unchecked", t.tasks[5].state)
  end)

  it("keeps an unclosed fence open to the last line", function()
    local t = tree.build({ "```", "- [ ] sample", "- [ ] more" })
    assert.is_nil(t.tasks[2])
    assert.is_nil(t.tasks[3])
  end)

  it("lists a task below a closed fence", function()
    local t = tree.build({ "```", "```", "- [ ] real" })
    assert.are.equal("unchecked", t.tasks[3].state)
  end)

  it("treats a fence opened on a list marker as a fence", function()
    local t = tree.build({ "- ```", "- [ ] sample", "```", "- [ ] real" })
    assert.is_nil(t.tasks[2])
    assert.are.equal("unchecked", t.tasks[4].state)
  end)

  -- The planner counts over the tasks table with the edits it has planned so far, so
  -- its rule must be the one `build` applies to the buffer as it stands.
  local counted = {
    { "- [ ] parent", "  - [x] a", "  - [ ] b", "  - [/] c", "  - [-] d" },
    { "- [ ] top", "  - [ ] mid", "    - [x] leaf" },
    { "- [ ] parent", "  - [x] a", "", "    continued text", "  - [ ] b" },
    { "- [ ] parent", "  - [x] a", "text", "  - [ ] b" },
    { "- [ ] one", "- [x] two" },
    { "  - [ ] parent", "\t- [x] child" },
    { "- [ ] parent", "  ## H", "  - [x] a" },
    { "- [ ] parent", "  - [-] a" },
    { "# H", "- [ ] parent", "  ```", "  - [x] sample", "# fenced", "  ```", "  - [x] real" },
  }
  for i, lines in ipairs(counted) do
    it("counts a task's children the way build does, case " .. i, function()
      local t = tree.build(lines)
      for lnum, task in pairs(t.tasks) do
        local done, total = tree.count(t.tasks, task.children)
        local built = t.counts[lnum] or { done = 0, total = 0 }
        assert.are.same({ built.done, built.total }, { done, total }, "line " .. lnum)
      end
    end)
  end

  it("counts an overlaid state in place of the task's own", function()
    local t = tree.build({ "- [ ] p", "  - [ ] a", "  - [x] b", "    - [-] c" })
    assert.are.same({ 2, 2 }, { tree.count(t.tasks, t.tasks[1].children, { [2] = "checked" }) })
    assert.are.same({ 1, 3 }, { tree.count(t.tasks, t.tasks[1].children, { [4] = "unchecked" }) })
    assert.are.same({ 0, 1 }, { tree.count(t.tasks, t.tasks[1].children, { [2] = "cancelled", [3] = "unchecked" }) })
  end)

  it("links tasks to their parent and children", function()
    local t = tree.build({ "- [ ] p", "  - [ ] a", "    - [ ] b", "  - [ ] c" })
    assert.are.same({ 2, 4 }, t.tasks[1].children)
    assert.are.equal(2, t.tasks[3].parent)
    assert.is_nil(t.tasks[1].parent)
  end)
end)
