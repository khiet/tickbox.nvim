local plan = require("tickbox.plan")
local tree = require("tickbox.tree")

-- The edits planned over a fresh tree of `lines`, as { [lnum] = new state }.
local function edits(lines, first, last, transition, auto_check_parent)
  return plan.edits(tree.build(lines).tasks, first, last, transition, { auto_check_parent = auto_check_parent == true })
end

describe("plan", function()
  -- line, state toggle gives it
  local toggles = {
    { "- [ ] foo", "checked" },
    { "- [/] foo", "checked" },
    { "- [x] foo", "unchecked" },
    { "- [-] foo", "checked" },
  }
  for _, case in ipairs(toggles) do
    it("toggles '" .. case[1] .. "' to " .. case[2], function()
      assert.are.same({ [1] = case[2] }, edits({ case[1] }, 1, 1, plan.toggle))
    end)
  end

  -- line, state cycle gives it
  local cycles = {
    { "- [ ] foo", "in_progress" },
    { "- [/] foo", "checked" },
    { "- [x] foo", "cancelled" },
    { "- [-] foo", "unchecked" },
  }
  for _, case in ipairs(cycles) do
    it("cycles '" .. case[1] .. "' to " .. case[2], function()
      assert.are.same({ [1] = case[2] }, edits({ case[1] }, 1, 1, plan.cycle))
    end)
  end

  -- state, a line in another state
  local sets = {
    { "unchecked", "- [x] foo" },
    { "in_progress", "- [ ] foo" },
    { "checked", "- [-] foo" },
    { "cancelled", "- [/] foo" },
  }
  for _, case in ipairs(sets) do
    it("sets '" .. case[2] .. "' to " .. case[1], function()
      assert.are.same({ [1] = case[1] }, edits({ case[2] }, 1, 1, plan.set(case[1])))
    end)
  end

  -- state, a line already in it
  local settled = {
    { "unchecked", "- [ ] foo" },
    { "in_progress", "- [/] foo" },
    { "checked", "- [x] foo" },
    { "cancelled", "- [-] foo" },
  }
  for _, case in ipairs(settled) do
    it("plans nothing for '" .. case[2] .. "' set to " .. case[1], function()
      assert.are.same({}, edits({ case[2] }, 1, 1, plan.set(case[1])))
    end)
  end

  it("raises on an unknown state before planning", function()
    local ok, err = pcall(plan.set, "bogus")
    assert.is_false(ok)
    assert.are.equal("Tickbox: unknown state: bogus", err)
    ok, err = pcall(plan.set, nil)
    assert.is_false(ok)
    assert.are.equal("Tickbox: unknown state: nil", err)
  end)

  it("edits only the tasks in the range that are not already in the state", function()
    local lines = { "- [-] one", "- plain", "- [ ] two", "- [-] three", "- [ ] four" }
    assert.are.same({ [3] = "cancelled" }, edits(lines, 1, 4, plan.set("cancelled")))
  end)

  it("skips non-task and fenced lines in the range", function()
    local lines = { "# heading", "- [ ] one", "```", "- [ ] sample", "```", "- [ ] two" }
    assert.are.same({ [2] = "checked", [6] = "checked" }, edits(lines, 1, 6, plan.toggle))
  end)

  it("ignores lines outside the tree", function()
    assert.are.same({ [1] = "checked" }, edits({ "- [ ] one" }, -3, 10, plan.toggle))
  end)
end)

describe("plan with auto_check_parent", function()
  local function auto(lines, first, last, transition)
    return edits(lines, first, last, transition, true)
  end

  it("plans no ancestor edits when the option is off", function()
    assert.are.same({ [2] = "checked" }, edits({ "- [ ] parent", "  - [ ] a" }, 2, 2, plan.toggle))
  end)

  it("checks the parent and the grandparent it completes", function()
    local lines = { "- [ ] top", "  - [x] done", "  - [ ] mid", "    - [x] b", "    - [ ] c", "    - [-] gone" }
    assert.are.same({ [1] = "checked", [3] = "checked", [5] = "checked" }, auto(lines, 5, 5, plan.toggle))
  end)

  it("checks the parent but not a grandparent with other open tasks", function()
    local lines = { "- [ ] top", "  - [ ] other", "  - [ ] mid", "    - [ ] c" }
    assert.are.same({ [3] = "checked", [4] = "checked" }, auto(lines, 4, 4, plan.toggle))
  end)

  it("checks an in-progress parent once its children are done", function()
    assert.are.same({ [1] = "checked", [2] = "checked" }, auto({ "- [/] parent", "  - [/] a" }, 2, 2, plan.toggle))
  end)

  it("unchecks checked ancestors when a child is unchecked", function()
    local lines = { "- [x] top", "  - [x] mid", "    - [x] c" }
    assert.are.same({ [1] = "unchecked", [2] = "unchecked", [3] = "unchecked" }, auto(lines, 3, 3, plan.toggle))
  end)

  it("unchecks a checked parent when a cycle moves a child to in progress", function()
    local lines = { "- [x] parent", "  - [ ] a", "  - [x] b" }
    assert.are.same({ [1] = "unchecked", [2] = "in_progress" }, auto(lines, 2, 2, plan.cycle))
  end)

  it("checks the parent when the last unfinished child is cancelled", function()
    local lines = { "- [ ] parent", "  - [x] a", "  - [ ] b" }
    assert.are.same({ [1] = "checked", [3] = "cancelled" }, auto(lines, 3, 3, plan.set("cancelled")))
  end)

  it("leaves a cancelled parent alone but still walks past it", function()
    local lines = { "- [ ] top", "  - [-] mid", "    - [ ] c" }
    -- With mid cancelled, c is top's only counted descendant.
    assert.are.same({ [1] = "checked", [3] = "checked" }, auto(lines, 3, 3, plan.toggle))
    lines = { "- [x] top", "  - [x] other", "  - [-] mid", "    - [x] c" }
    assert.are.same({ [1] = "unchecked", [4] = "unchecked" }, auto(lines, 4, 4, plan.toggle))
  end)

  it("never changes an edited parent's children", function()
    local lines = { "- [ ] parent", "  - [ ] a", "  - [x] b" }
    assert.are.same({ [1] = "checked" }, auto(lines, 1, 1, plan.toggle))
    assert.are.same({ [1] = "cancelled" }, auto(lines, 1, 1, plan.set("cancelled")))
  end)

  it("never uses headings", function()
    assert.are.same({ [2] = "checked" }, auto({ "# H", "- [ ] a" }, 2, 2, plan.toggle))
  end)

  it("plans the parent once for a range of children", function()
    local lines = { "- [ ] parent", "  - [ ] a", "  - [ ] b" }
    assert.are.same({ [1] = "checked", [2] = "checked", [3] = "checked" }, auto(lines, 2, 3, plan.toggle))
  end)

  it("keeps a parent the range itself edited", function()
    local lines = { "- [ ] parent", "  - [ ] a", "  - [ ] b" }
    assert.are.same({ [1] = "checked", [2] = "checked" }, auto(lines, 1, 2, plan.toggle))
  end)

  it("keeps a range task that was already in the state", function()
    local lines = { "- [x] parent", "  - [ ] a", "  - [ ] b" }
    assert.are.same({ [2] = "checked" }, auto(lines, 1, 2, plan.set("checked")))
  end)

  it("plans nothing for ancestors when nothing changed", function()
    assert.are.same({}, auto({ "- [x] parent", "  - [ ] a" }, 2, 2, plan.set("unchecked")))
  end)

  it("ignores fenced lines", function()
    local lines = { "- [ ] parent", "  ```", "  - [ ] sample", "  ```", "  - [ ] a" }
    assert.are.same({ [1] = "checked", [5] = "checked" }, auto(lines, 5, 5, plan.toggle))
  end)
end)
