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
    { "- [/] foo", "- [x] foo" },
    { "- [-] foo", "- [x] foo" },
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

  it("returns false in a filetype that is not configured", function()
    h.open({ "- [ ] foo" }, "text")
    assert.is_false(tickbox.toggle())
    assert.is_false(tickbox.toggle_range(1, 1))
    vim.cmd("Tickbox toggle")
    h.type("<Plug>(tickbox-toggle)")
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("follows the configured filetypes", function()
    tickbox.setup({ filetypes = { "notes" } })
    h.open({ "- [ ] foo" }, "notes")
    local toggled = tickbox.toggle()
    tickbox.setup()
    assert.is_true(toggled)
    assert.are.same({ "- [x] foo" }, lines())
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
    h.open({ "- [ ] foo" })
    h.pause()
    h.type("<Plug>(tickbox-toggle)")
    h.pause()
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

describe("toggling a range", function()
  local mixed = {
    "# heading",
    "- [ ] one",
    "- plain",
    "- [X] two",
    "- [ ] outside",
  }
  local mixed_toggled = {
    "# heading",
    "- [x] one",
    "- plain",
    "- [ ] two",
    "- [ ] outside",
  }

  local first_task_toggled = {
    "# heading",
    "- [x] one",
    "- plain",
    "- [X] two",
    "- [ ] outside",
  }

  it("flips only the task lines with the visual mapping", function()
    h.open(mixed)
    h.type("Vjjj<Plug>(tickbox-toggle)")
    assert.are.same(mixed_toggled, lines())
  end)

  it("handles a selection made upwards", function()
    h.open(mixed)
    h.type("3GVkk<Plug>(tickbox-toggle)")
    assert.are.same(first_task_toggled, lines())
  end)

  it("finishes before keys queued behind the mapping run", function()
    h.open(mixed)
    h.type("jVj<Plug>(tickbox-toggle)jdd")
    assert.are.same({ "# heading", "- [x] one", "- plain", "- [ ] outside" }, lines())
  end)

  it("leaves visual mode", function()
    h.open(mixed)
    h.type("Vj<Plug>(tickbox-toggle)")
    assert.are.equal("n", vim.api.nvim_get_mode().mode)
  end)

  it("takes every line touched by a charwise selection", function()
    h.open({ "- [ ] one", "- [ ] two" })
    h.type("wvj<Plug>(tickbox-toggle)")
    assert.are.same({ "- [x] one", "- [x] two" }, lines())
  end)

  it("reverts the whole range with one undo", function()
    h.open(mixed)
    h.pause()
    h.type("Vjjj<Plug>(tickbox-toggle)")
    h.type("u")
    assert.are.same(mixed, lines())
  end)

  it("flips the lines of a :Tickbox range", function()
    h.open(mixed)
    vim.cmd("1,4Tickbox toggle")
    assert.are.same(mixed_toggled, lines())
  end)

  it("flips the visual marks with :'<,'>Tickbox", function()
    h.open(mixed)
    h.type("jV<Esc>")
    vim.cmd("'<,'>Tickbox toggle")
    assert.are.same(first_task_toggled, lines())
  end)

  it("skips fenced lines inside the range", function()
    h.open({ "- [ ] one", "```", "- [ ] sample", "```", "- [ ] two" })
    assert.is_true(tickbox.toggle_range(1, 5))
    assert.are.same({ "- [x] one", "```", "- [ ] sample", "```", "- [x] two" }, lines())
  end)

  it("honours a fence that opens above the range", function()
    h.open({ "```", "- [ ] sample" })
    assert.is_false(tickbox.toggle_range(2, 2))
  end)

  it("ignores lines outside the buffer", function()
    h.open({ "- [ ] one", "- [ ] two" })
    assert.is_true(tickbox.toggle_range(0, 99))
    assert.are.same({ "- [x] one", "- [x] two" }, lines())
    assert.is_false(tickbox.toggle_range(20, 30))
  end)

  it("returns whether any line changed", function()
    h.open({ "# heading", "- plain", "- [ ] one" })
    assert.is_false(tickbox.toggle_range(1, 2))
    assert.is_true(tickbox.toggle_range(1, 3))
  end)

  it("returns false in a nomodifiable buffer", function()
    local buf = h.open({ "- [ ] one" })
    vim.bo[buf].modifiable = false
    assert.is_false(tickbox.toggle_range(1, 1))
    vim.bo[buf].modifiable = true
  end)
end)

describe(":Tickbox", function()
  it("toggles the cursor line", function()
    h.open({ "- [ ] one", "- [ ] two" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("Tickbox toggle")
    assert.are.same({ "- [ ] one", "- [x] two" }, lines())
  end)

  it("cycles the cursor line", function()
    h.open({ "- [ ] one", "- [ ] two" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("Tickbox cycle")
    assert.are.same({ "- [ ] one", "- [/] two" }, lines())
  end)

  it("rejects an unknown subcommand", function()
    local ok, err = pcall(vim.cmd, "Tickbox nope")
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("nope", 1, true))
  end)
end)

describe("cycle", function()
  -- before, after
  local steps = {
    { "- [ ] foo", "- [/] foo" },
    { "- [/] foo", "- [x] foo" },
    { "- [x] foo", "- [-] foo" },
    { "- [X] foo", "- [-] foo" },
    { "- [-] foo", "- [ ] foo" },
    { "  1. [/] *foo* [ ] [x]", "  1. [x] *foo* [ ] [x]" },
  }
  for _, case in ipairs(steps) do
    it("turns '" .. case[1] .. "' into '" .. case[2] .. "'", function()
      h.open({ case[1] })
      assert.is_true(tickbox.cycle())
      assert.are.same({ case[2] }, lines())
    end)
  end

  it("only touches the cursor line and keeps the cursor", function()
    h.open({ "- [ ] one", "- [ ] two bar" })
    vim.api.nvim_win_set_cursor(0, { 2, 10 })
    assert.is_true(tickbox.cycle())
    assert.are.same({ "- [ ] one", "- [/] two bar" }, lines())
    assert.are.same({ 2, 10 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("returns false on a non-task line", function()
    h.open({ "- plain" })
    assert.is_false(tickbox.cycle())
    assert.are.same({ "- plain" }, lines())
  end)

  it("returns false on a fenced line", function()
    local fenced = { "```", "- [ ] sample", "```" }
    h.open(fenced)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert.is_false(tickbox.cycle())
    assert.are.same(fenced, lines())
  end)

  it("returns false in a filetype that is not configured", function()
    h.open({ "- [ ] foo" }, "text")
    assert.is_false(tickbox.cycle())
    assert.is_false(tickbox.cycle_range(1, 1))
    vim.cmd("Tickbox cycle")
    h.type("<Plug>(tickbox-cycle)")
    assert.are.same({ "- [ ] foo" }, lines())
  end)

  it("returns false in a nomodifiable buffer", function()
    local buf = h.open({ "- [ ] foo" })
    vim.bo[buf].modifiable = false
    assert.is_false(tickbox.cycle())
    assert.is_false(tickbox.cycle_range(1, 1))
    vim.bo[buf].modifiable = true
    assert.are.same({ "- [ ] foo" }, lines())
  end)
end)

describe("<Plug>(tickbox-cycle)", function()
  it("reverts one step per undo", function()
    h.open({ "- [ ] foo" })
    h.pause()
    h.type("<Plug>(tickbox-cycle)")
    h.pause()
    h.type("<Plug>(tickbox-cycle)")
    assert.are.same({ "- [x] foo" }, lines())
    h.type("u")
    assert.are.same({ "- [/] foo" }, lines())
  end)

  it("repeats with dot", function()
    h.open({ "- [ ] one", "- [-] two" })
    h.type("<Plug>(tickbox-cycle)")
    h.type(".")
    h.type("j.")
    assert.are.same({ "- [x] one", "- [ ] two" }, lines())
  end)
end)

describe("cycling a range", function()
  local mixed = { "# heading", "- [ ] one", "- plain", "- [x] two", "- [-] three", "- [/] outside" }
  local cycled = { "# heading", "- [/] one", "- plain", "- [-] two", "- [ ] three", "- [/] outside" }

  it("advances every task with the visual mapping, as one undo step", function()
    h.open(mixed)
    h.pause()
    h.type("Vjjjj<Plug>(tickbox-cycle)")
    assert.are.same(cycled, lines())
    assert.are.equal("n", vim.api.nvim_get_mode().mode)
    h.type("u")
    assert.are.same(mixed, lines())
  end)

  it("advances the visual marks with :'<,'>Tickbox cycle, as one undo step", function()
    h.open(mixed)
    h.type("Vjjjj<Esc>")
    h.pause()
    vim.cmd("'<,'>Tickbox cycle")
    assert.are.same(cycled, lines())
    vim.cmd("undo")
    assert.are.same(mixed, lines())
  end)

  it("skips fenced lines and returns whether any line changed", function()
    h.open({ "# heading", "```", "- [ ] sample", "```", "- [ ] two" })
    assert.is_false(tickbox.cycle_range(1, 4))
    assert.is_true(tickbox.cycle_range(1, 5))
    assert.are.same({ "# heading", "```", "- [ ] sample", "```", "- [/] two" }, lines())
  end)
end)
