local h = require("tests.helpers")
local tickbox = require("tickbox")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("set", function()
  -- state, before, after
  local changes = {
    { "unchecked", "- [x] foo", "- [ ] foo" },
    { "in_progress", "- [ ] foo", "- [/] foo" },
    { "checked", "- [-] foo", "- [x] foo" },
    { "cancelled", "- [/] foo", "- [-] foo" },
    { "cancelled", "  1. [X] *foo* [ ] [x]", "  1. [-] *foo* [ ] [x]" },
  }
  for _, case in ipairs(changes) do
    it("sets '" .. case[2] .. "' to " .. case[1], function()
      h.open({ case[2] })
      assert.is_true(tickbox.set(case[1]))
      assert.are.same({ case[3] }, lines())
    end)
  end

  it("only touches the cursor line and keeps the cursor", function()
    h.open({ "- [ ] one", "- [ ] two bar" })
    vim.api.nvim_win_set_cursor(0, { 2, 10 })
    assert.is_true(tickbox.set("cancelled"))
    assert.are.same({ "- [ ] one", "- [-] two bar" }, lines())
    assert.are.same({ 2, 10 }, vim.api.nvim_win_get_cursor(0))
  end)

  -- state, a line already in it
  local settled = {
    { "unchecked", "- [ ] foo" },
    { "in_progress", "- [/] foo" },
    { "checked", "- [x] foo" },
    { "checked", "- [X] foo" },
    { "cancelled", "- [-] foo" },
  }
  for _, case in ipairs(settled) do
    it("leaves '" .. case[2] .. "' alone when set to " .. case[1], function()
      local buf = h.open({ case[2] })
      local tick = vim.b[buf].changedtick
      local undo = vim.fn.undotree().seq_last
      assert.is_false(tickbox.set(case[1]))
      assert.are.same({ case[2] }, lines())
      assert.are.equal(tick, vim.b[buf].changedtick)
      assert.are.equal(undo, vim.fn.undotree().seq_last)
    end)
  end

  it("returns false on a non-task line", function()
    h.open({ "- plain" })
    assert.is_false(tickbox.set("cancelled"))
    assert.are.same({ "- plain" }, lines())
  end)

  it("returns false on a fenced line", function()
    local fenced = { "```", "- [ ] sample", "```" }
    h.open(fenced)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert.is_false(tickbox.set("cancelled"))
    assert.are.same(fenced, lines())
  end)

  it("returns false in a filetype that is not configured", function()
    h.open({ "- [ ] foo" }, "text")
    assert.is_false(tickbox.set("cancelled"))
    assert.is_false(tickbox.set_range("cancelled", 1, 1))
    vim.cmd("Tickbox set cancelled")
    h.type("<Plug>(tickbox-set-cancelled)")
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("returns false in a nomodifiable buffer", function()
    local buf = h.open({ "- [ ] foo" })
    vim.bo[buf].modifiable = false
    assert.is_false(tickbox.set("cancelled"))
    assert.is_false(tickbox.set_range("cancelled", 1, 1))
    vim.bo[buf].modifiable = true
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("keeps working while rendering is disabled", function()
    h.open({ "- [ ] foo" })
    tickbox.disable()
    assert.is_true(tickbox.set("in_progress"))
    assert.are.same({ "- [/] foo" }, lines())
  end)

  -- An invalid state is a caller bug, so it raises even where a valid one returns false.
  local invalid = {
    { "an unknown state", "bogus", "Tickbox: unknown state: bogus" },
    { "a missing state", nil, "Tickbox: unknown state: nil" },
  }
  for _, case in ipairs(invalid) do
    it("raises on " .. case[1] .. " with the buffer unchanged", function()
      h.open({ "- [ ] foo" })
      local ok, err = pcall(tickbox.set, case[2])
      assert.is_false(ok)
      assert.are.equal(case[3], err)
      ok, err = pcall(tickbox.set_range, case[2], 1, 1)
      assert.is_false(ok)
      assert.are.equal(case[3], err)
      assert.are.same({ "- [ ] foo" }, lines())
    end)
  end

  it("raises on an unknown state on a non-task line", function()
    h.open({ "- plain" })
    assert.is_false((pcall(tickbox.set, "bogus")))
  end)
end)

describe("set_range", function()
  it("sets every task on the lines as one undo step", function()
    local before = { "- [ ] one", "- plain", "- [x] two", "- [ ] three" }
    h.open(before)
    h.pause()
    assert.is_true(tickbox.set_range("in_progress", 1, 3))
    assert.are.same({ "- [/] one", "- plain", "- [/] two", "- [ ] three" }, lines())
    vim.cmd("silent undo")
    assert.are.same(before, lines())
  end)

  it("returns true when one task changes and leaves those already in the state", function()
    h.open({ "- [-] one", "- [ ] two", "- [-] three" })
    assert.is_true(tickbox.set_range("cancelled", 1, 3))
    assert.are.same({ "- [-] one", "- [-] two", "- [-] three" }, lines())
  end)

  it("returns false when every task is already in the state", function()
    local buf = h.open({ "- [-] one", "- [-] two" })
    local tick = vim.b[buf].changedtick
    assert.is_false(tickbox.set_range("cancelled", 1, 2))
    assert.are.equal(tick, vim.b[buf].changedtick)
  end)
end)

describe(":Tickbox set", function()
  it("sets the cursor line without a range", function()
    h.open({ "- [ ] one", "- [ ] two" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("Tickbox set cancelled")
    assert.are.same({ "- [ ] one", "- [-] two" }, lines())
  end)

  it("sets every task in a range as one undo step", function()
    local before = { "- [ ] one", "- [ ] two", "- [ ] three" }
    h.open(before)
    h.pause()
    vim.cmd("1,2Tickbox set in_progress")
    assert.are.same({ "- [/] one", "- [/] two", "- [ ] three" }, lines())
    vim.cmd("silent undo")
    assert.are.same(before, lines())
  end)

  for _, command in ipairs({ "Tickbox set bogus", "Tickbox set", "Tickbox set cancelled extra" }) do
    it("rejects ':" .. command .. "' with the buffer unchanged", function()
      h.open({ "- [ ] foo" })
      local ok, err = pcall(vim.cmd, command)
      assert.is_false(ok)
      assert.is_truthy(tostring(err):find("unknown state", 1, true))
      assert.are.same({ "- [ ] foo" }, lines())
    end)
  end

  it("does not let another subcommand take a state", function()
    h.open({ "- [ ] foo" })
    local ok, err = pcall(vim.cmd, "Tickbox toggle cancelled")
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("unknown subcommand", 1, true))
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("completes the states after set", function()
    local states = { "unchecked", "in_progress", "checked", "cancelled" }
    assert.are.same(states, vim.fn.getcompletion("Tickbox set ", "cmdline"))
    assert.are.same({ "checked", "cancelled" }, vim.fn.getcompletion("Tickbox set c", "cmdline"))
    assert.are.same({}, vim.fn.getcompletion("Tickbox set cancelled ", "cmdline"))
  end)
end)

describe("<Plug>(tickbox-set-*)", function()
  -- mapping suffix, the text it writes
  local mappings = {
    { "unchecked", " " },
    { "in-progress", "/" },
    { "checked", "x" },
    { "cancelled", "-" },
  }
  for _, case in ipairs(mappings) do
    local plug = "<Plug>(tickbox-set-" .. case[1] .. ")"
    local set = "- [" .. case[2] .. "] "
    -- A start distinct from every target, so each mapping has something to change.
    local start = case[2] == "/" and "- [x] " or "- [/] "

    it(plug .. " sets the cursor line, and . repeats it", function()
      h.open({ start .. "one", start .. "two" })
      h.type(plug)
      assert.are.same({ set .. "one", start .. "two" }, lines())
      h.type("j.")
      assert.are.same({ set .. "one", set .. "two" }, lines())
    end)

    it(plug .. " sets every selected task as one undo step", function()
      local before = { start .. "one", start .. "two", start .. "three" }
      h.open(before)
      h.pause()
      h.type("Vj" .. plug)
      assert.are.same({ set .. "one", set .. "two", start .. "three" }, lines())
      assert.are.equal("n", vim.api.nvim_get_mode().mode)
      vim.cmd("silent undo")
      assert.are.same(before, lines())
    end)
  end
end)

describe("set with auto_check_parent", function()
  before_each(function()
    tickbox.setup({ auto_check_parent = true })
  end)

  after_each(function()
    tickbox.setup()
  end)

  it("checks the parent when the last unfinished child is cancelled, in one undo step", function()
    local before = { "- [ ] parent", "  - [x] a", "  - [ ] b" }
    h.open(before)
    h.pause()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    tickbox.set("cancelled")
    assert.are.same({ "- [x] parent", "  - [x] a", "  - [-] b" }, lines())
    vim.cmd("silent undo")
    assert.are.same(before, lines())
  end)

  it("unchecks a checked parent when a child goes in progress, in one undo step", function()
    local before = { "- [x] parent", "  - [x] a" }
    h.open(before)
    h.pause()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    tickbox.set("in_progress")
    assert.are.same({ "- [ ] parent", "  - [/] a" }, lines())
    vim.cmd("silent undo")
    assert.are.same(before, lines())
  end)

  it("leaves a parent's descendants alone", function()
    h.open({ "- [ ] parent", "  - [ ] a" })
    tickbox.set("cancelled")
    assert.are.same({ "- [-] parent", "  - [ ] a" }, lines())
  end)

  it("does not update ancestors when nothing changed", function()
    local before = { "- [x] parent", "  - [ ] a" }
    local buf = h.open(before)
    local tick = vim.b[buf].changedtick
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert.is_false(tickbox.set("unchecked"))
    assert.are.same(before, lines())
    assert.are.equal(tick, vim.b[buf].changedtick)
  end)
end)
