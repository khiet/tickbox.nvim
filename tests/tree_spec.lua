local tree = require("tickbox.tree")

local function count(lines, lnum)
  local c = tree.build(lines).counts[lnum]
  return c and (c.done .. "/" .. c.total)
end

-- Every line set a test builds a tree from. The parity test at the end runs over all of
-- them, so a case added here is counted both ways.
local fixtures = {
  every_state = { "- [ ] parent", "  - [x] a", "  - [ ] b", "  - [/] c", "  - [-] d" },
  grandchildren = { "- [ ] top", "  - [ ] mid", "    - [x] leaf" },
  blank_and_deeper = { "- [ ] parent", "  - [x] a", "", "    continued text", "  - [ ] b" },
  run_ended = { "- [ ] parent", "  - [x] a", "text", "  - [ ] b" },
  siblings = { "- [ ] one", "- [x] two" },
  tab_indent = { "  - [ ] parent", "\t- [x] child" },
  heading_levels = { "## A", "- [x] a1", "### A.1", "- [ ] a2", "## B", "- [ ] b1", "# C", "- [ ] c1" },
  heading_ends_run = { "- [ ] parent", "# H", "  - [x] a" },
  heading_in_run = { "- [ ] parent", "  ## H", "  - [x] a" },
  heading_splits_subtree = { "# A", "- [ ] parent", "  # B", "  - [x] child" },
  heading_without_tasks = { "# H", "text" },
  only_cancelled = { "- [ ] parent", "  - [-] a" },
  fenced_heading = { "# H", "- [ ] parent", "  ```", "  - [x] sample", "# fenced", "  ```", "  - [x] real" },
  hash_runs = { "#tag", "####### seven", "- [ ] parent", "  - [x] a" },
  fenced_task = { "- [ ] one", "```", "- [ ] sample", "```", "- [ ] two" },
  unclosed_fence = { "```", "- [ ] sample", "- [ ] more" },
  closed_fence = { "```", "```", "- [ ] real" },
  fence_on_marker = { "- ```", "- [ ] sample", "```", "- [ ] real" },
  linked = { "- [ ] p", "  - [ ] a", "    - [ ] b", "  - [ ] c" },
}

describe("tree", function()
  it("is the only module that reads buffer lines and classifies tasks", function()
    for _, name in ipairs({ "render", "toggle", "continue", "plan" }) do
      local source = table.concat(vim.fn.readfile(("lua/tickbox/%s.lua"):format(name)), "\n")
      assert.is_nil(source:find("tickbox.parse", 1, true), name .. " requires parse")
      assert.is_nil(source:find("nvim_buf_get_lines", 1, true), name .. " reads buffer lines")
    end
  end)

  it("counts checked over every state but cancelled", function()
    assert.are.equal("1/3", count(fixtures.every_state, 1))
  end)

  it("counts grandchildren toward the top parent", function()
    assert.are.equal("1/2", count(fixtures.grandchildren, 1))
    assert.are.equal("1/1", count(fixtures.grandchildren, 2))
  end)

  it("keeps a run going over blank and deeper non-task lines", function()
    assert.are.equal("1/2", count(fixtures.blank_and_deeper, 1))
  end)

  it("ends a run at a line indented the same or less", function()
    assert.are.equal("1/1", count(fixtures.run_ended, 1))
    assert.is_nil(count(fixtures.siblings, 1))
  end)

  it("treats a tab as indentation to the next multiple of four", function()
    assert.are.equal("1/1", count(fixtures.tab_indent, 1))
  end)

  it("counts a heading's tasks until a heading of the same or a higher level", function()
    assert.are.equal("1/2", count(fixtures.heading_levels, 1))
    assert.are.equal("0/1", count(fixtures.heading_levels, 3))
    assert.are.equal("0/1", count(fixtures.heading_levels, 5))
  end)

  it("ends task runs at a heading only by its indentation", function()
    assert.is_nil(count(fixtures.heading_ends_run, 1))
    assert.are.equal("1/1", count(fixtures.heading_in_run, 1))
    -- The heading counts a task whose parent sits above the heading.
    assert.are.equal("1/1", count(fixtures.heading_in_run, 2))
  end)

  it("stops a heading's count where the next heading starts, even inside a task's subtree", function()
    assert.are.equal("0/1", count(fixtures.heading_splits_subtree, 1))
    assert.are.equal("1/1", count(fixtures.heading_splits_subtree, 3))
    assert.are.equal("1/1", count(fixtures.heading_splits_subtree, 2))
  end)

  it("counts nothing for a heading without tasks or a parent of only cancelled tasks", function()
    assert.is_nil(count(fixtures.heading_without_tasks, 1))
    assert.is_nil(count(fixtures.only_cancelled, 1))
  end)

  it("ignores task-looking lines and headings inside fences", function()
    assert.are.equal("1/1", count(fixtures.fenced_heading, 2))
    assert.are.equal("1/2", count(fixtures.fenced_heading, 1))
  end)

  it("ignores '#' runs that are not headings", function()
    assert.are.equal("1/1", count(fixtures.hash_runs, 3))
    assert.is_nil(count(fixtures.hash_runs, 1))
  end)

  it("leaves fenced lines out of tasks", function()
    local t = tree.build(fixtures.fenced_task)
    assert.is_nil(t.tasks[3])
    assert.are.equal("unchecked", t.tasks[1].state)
    assert.are.equal("unchecked", t.tasks[5].state)
  end)

  it("keeps an unclosed fence open to the last line", function()
    local t = tree.build(fixtures.unclosed_fence)
    assert.is_nil(t.tasks[2])
    assert.is_nil(t.tasks[3])
  end)

  it("lists a task below a closed fence", function()
    local t = tree.build(fixtures.closed_fence)
    assert.are.equal("unchecked", t.tasks[3].state)
  end)

  it("treats a fence opened on a list marker as a fence", function()
    local t = tree.build(fixtures.fence_on_marker)
    assert.is_nil(t.tasks[2])
    assert.are.equal("unchecked", t.tasks[4].state)
  end)

  it("links tasks to their parent and children", function()
    local t = tree.build(fixtures.linked)
    assert.are.same({ 2, 4 }, t.tasks[1].children)
    assert.are.equal(2, t.tasks[3].parent)
    assert.is_nil(t.tasks[1].parent)
  end)

  it("lists a task's descendants in buffer order", function()
    local t = tree.build(fixtures.linked)
    assert.are.same({ 2, 3, 4 }, tree.descendants(t.tasks, 1))
    assert.are.same({ 3 }, tree.descendants(t.tasks, 2))
    assert.are.same({}, tree.descendants(t.tasks, 4))
  end)

  -- The planner counts over the tasks table with the edits it has planned so far, so
  -- its rule must be the one `build` applies to the buffer as it stands.
  for name, lines in pairs(fixtures) do
    it("counts a task's descendants the way build does: " .. name, function()
      local t = tree.build(lines)
      for lnum in pairs(t.tasks) do
        local done, total = tree.count(t.tasks, tree.descendants(t.tasks, lnum))
        local built = t.counts[lnum] or { done = 0, total = 0 }
        assert.are.same({ built.done, built.total }, { done, total }, "line " .. lnum)
      end
    end)
  end

  it("counts an overlaid state in place of the task's own", function()
    local t = tree.build({ "- [ ] p", "  - [ ] a", "  - [x] b", "    - [-] c" })
    local under_p = tree.descendants(t.tasks, 1)
    assert.are.same({ 2, 2 }, { tree.count(t.tasks, under_p, { [2] = "checked" }) })
    assert.are.same({ 1, 3 }, { tree.count(t.tasks, under_p, { [4] = "unchecked" }) })
    assert.are.same({ 0, 1 }, { tree.count(t.tasks, under_p, { [2] = "cancelled", [3] = "unchecked" }) })
  end)
end)
