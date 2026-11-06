local h = require("tests.helpers")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Types `keys` with <NL>, <O> and <Shift-O> standing for the three continue mappings.
local function type(keys)
  keys = keys
    :gsub("<NL>", "<Plug>(tickbox-newline)")
    :gsub("<Shift%-O>", "<Plug>(tickbox-open-above)")
    :gsub("<O>", "<Plug>(tickbox-open-below)")
  h.type(keys)
end

-- Closes the undo block that setting up the buffer opened, as a pause in typing would.
local function pause()
  vim.bo.undolevels = vim.bo.undolevels
end

describe("continue", function()
  it("starts an unchecked task after a task", function()
    h.open({ "- [ ] a" })
    type("A<NL>b<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b" }, lines())
  end)

  -- before, keys, after
  local continues = {
    { { "- [x] a" }, "A<NL>b<Esc>", { "- [x] a", "- [ ] b" } },
    { { "  * [ ] a" }, "A<NL>b<Esc>", { "  * [ ] a", "  * [ ] b" } },
    { { "\t+ [ ] a" }, "A<NL>b<Esc>", { "\t+ [ ] a", "\t+ [ ] b" } },
    { { "- [ ] ab" }, "$i<NL><Esc>", { "- [ ] a", "- [ ] b" } },
  }
  for _, case in ipairs(continues) do
    it("turns '" .. case[1][1] .. "' with " .. case[2] .. " into the next task", function()
      h.open(case[1])
      type(case[2])
      assert.are.same(case[3], lines())
    end)
  end

  local plain = {
    { "a plain list item", { "- a" }, "markdown" },
    { "an ordered task", { "1. [ ] a" }, "markdown" },
    { "a fenced task", { "```", "- [ ] a" }, "markdown" },
    { "a filetype that is not configured", { "- [ ] a" }, "text" },
  }
  for _, case in ipairs(plain) do
    it("is a plain <CR> on " .. case[1], function()
      h.open(case[2], case[3])
      type("GA<NL>b<Esc>")
      local expected = vim.list_extend(vim.deepcopy(case[2]), { "b" })
      assert.are.same(expected, lines())
    end)
  end

  it("does not double the marker vim-markdown continues lists with", function()
    h.open({ "- [ ] a" })
    vim.bo.formatoptions = vim.bo.formatoptions .. "r"
    vim.bo.comments = "b:>,b:*,b:+,b:-"
    type("A<NL>b<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b" }, lines())
  end)

  it("keeps working while rendering is disabled", function()
    h.open({ "- [ ] a" })
    vim.cmd("Tickbox disable")
    type("A<NL>b<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b" }, lines())
  end)

  it("opens a task below with open-below and above with open-above", function()
    h.open({ "- [ ] a", "  * [x] c" })
    type("gg<O>b<Esc>")
    type("G<Shift-O>z<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b", "  * [ ] z", "  * [x] c" }, lines())
  end)

  it("undoes an opened task in one step with the typed text", function()
    h.open({ "- [ ] a" })
    pause()
    type("<O>b<Esc>u")
    assert.are.same({ "- [ ] a" }, lines())
  end)

  it("is a plain o and O off a task line", function()
    h.open({ "a" })
    type("<O>b<Esc>")
    type("<Shift-O>z<Esc>")
    assert.are.same({ "a", "z", "b" }, lines())
  end)

  it("is a plain <CR> with the cursor before the task text", function()
    h.open({ "- [ ] a" })
    type("0i<NL><Esc>")
    assert.are.same({ "", "- [ ] a" }, lines())
  end)

  it("ends the list on an empty task by clearing it", function()
    h.open({ "- [ ] a", "  - [x]   " })
    type("GA<NL>b<Esc>")
    assert.are.same({ "- [ ] a", "b" }, lines())
  end)

  it("undoes the new task in one step with the typed text", function()
    h.open({ "- [ ] a" })
    pause()
    type("A<NL>b<Esc>u")
    assert.are.same({ "- [ ] a" }, lines())
  end)
end)
