local h = require("tests.helpers")
local tickbox = require("tickbox")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("toggle", function()
  -- before, after
  local flips = {
    { "- [ ] foo", "- [x] foo" },
    { "- [x] foo", "- [ ] foo" },
    { "- [X] foo", "- [ ] foo" },
    { "  1. [ ] *foo* [ ] [x] 󰄱", "  1. [x] *foo* [ ] [x] 󰄱" },
    { "\t+   [x] foo  ", "\t+   [ ] foo  " },
  }
  for _, case in ipairs(flips) do
    it("turns '" .. case[1] .. "' into '" .. case[2] .. "'", function()
      h.open({ case[1] })
      assert.is_true(tickbox.toggle())
      assert.are.same({ case[2] }, lines())
    end)
  end

  it("works from anywhere on the line and keeps the cursor", function()
    h.open({ "- [ ] foo bar" })
    vim.api.nvim_win_set_cursor(0, { 1, 10 })
    assert.is_true(tickbox.toggle())
    assert.are.same({ "- [x] foo bar" }, lines())
    assert.are.same({ 1, 10 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("only touches the cursor line", function()
    h.open({ "- [ ] one", "- [ ] two" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    tickbox.toggle()
    assert.are.same({ "- [ ] one", "- [x] two" }, lines())
  end)

  local untouched = {
    { "a heading", { "# heading" } },
    { "a plain list item", { "- plain" } },
    { "an empty line", { "" } },
    { "a missing trailing space", { "- [ ]" } },
  }
  for _, case in ipairs(untouched) do
    it("returns false on " .. case[1], function()
      h.open(case[2])
      assert.is_false(tickbox.toggle())
      assert.are.same(case[2], lines())
    end)
  end

  it("returns false on a task in a nomodifiable buffer", function()
    local buf = h.open({ "- [ ] foo" })
    vim.bo[buf].modifiable = false
    assert.is_false(tickbox.toggle())
    vim.bo[buf].modifiable = true
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("returns false inside a fence", function()
    local fenced = { "```", "- [ ] sample", "```" }
    h.open(fenced)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert.is_false(tickbox.toggle())
    assert.are.same(fenced, lines())
  end)

  it("toggles below a closed fence", function()
    h.open({ "```", "```", "- [ ] real" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    assert.is_true(tickbox.toggle())
    assert.are.same({ "```", "```", "- [x] real" }, lines())
  end)
end)

describe("<Plug>(tickbox-toggle)", function()
  it("reverts one toggle per undo", function()
    -- Typed keys close the undo block while nvim waits for input. Fed keys never wait,
    -- so this does it by hand, as a pause between keystrokes would.
    local function pause()
      vim.bo.undolevels = vim.bo.undolevels
    end
    h.open({ "- [ ] foo" })
    pause()
    h.type("<Plug>(tickbox-toggle)")
    pause()
    h.type("<Plug>(tickbox-toggle)")
    assert.are.same({ "- [ ] foo" }, lines())
    h.type("u")
    assert.are.same({ "- [x] foo" }, lines())
    h.type("u")
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("repeats on the same line with dot", function()
    h.open({ "- [ ] foo" })
    h.type("<Plug>(tickbox-toggle)")
    assert.are.same({ "- [x] foo" }, lines())
    h.type(".")
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("repeats on the next item with dot", function()
    h.open({ "- [ ] one", "- [ ] two" })
    h.type("<Plug>(tickbox-toggle)")
    h.type("j.")
    assert.are.same({ "- [x] one", "- [x] two" }, lines())
  end)
end)

describe(":Tickbox", function()
  it("toggles the cursor line", function()
    h.open({ "- [ ] one", "- [ ] two" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("Tickbox toggle")
    assert.are.same({ "- [ ] one", "- [x] two" }, lines())
  end)

  it("rejects an unknown subcommand", function()
    local ok, err = pcall(vim.cmd, "Tickbox nope")
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("nope", 1, true))
  end)
end)
