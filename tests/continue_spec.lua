local h = require("tests.helpers")

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Types `keys` with <Newline>, <Below> and <Above> standing for the three mappings.
local function press(keys)
  keys = keys
    :gsub("<Newline>", "<Plug>(tickbox-newline)")
    :gsub("<Below>", "<Plug>(tickbox-open-below)")
    :gsub("<Above>", "<Plug>(tickbox-open-above)")
  h.type(keys)
end

describe("continue", function()
  it("starts an unchecked task after a task", function()
    h.open({ "- [ ] a" })
    press("A<Newline>b<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b" }, lines())
  end)

  -- before, keys, after
  local continues = {
    { { "- [x] a" }, "A<Newline>b<Esc>", { "- [x] a", "- [ ] b" } },
    { { "  * [ ] a" }, "A<Newline>b<Esc>", { "  * [ ] a", "  * [ ] b" } },
    { { "\t+ [ ] a" }, "A<Newline>b<Esc>", { "\t+ [ ] a", "\t+ [ ] b" } },
    { { "- [ ] ab" }, "$i<Newline><Esc>", { "- [ ] a", "- [ ] b" } },
    { { "- [/] a" }, "A<Newline>b<Esc>", { "- [/] a", "- [ ] b" } },
    { { "- [-] a" }, "A<Newline>b<Esc>", { "- [-] a", "- [ ] b" } },
    { { "- [/] a" }, "<Below>b<Esc>", { "- [/] a", "- [ ] b" } },
    { { "- [-] a" }, "<Above>b<Esc>", { "- [ ] b", "- [-] a" } },
  }
  for _, case in ipairs(continues) do
    it("turns '" .. case[1][1] .. "' with " .. case[2] .. " into the next task", function()
      h.open(case[1])
      press(case[2])
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
      press("GA<Newline>b<Esc>")
      local expected = vim.list_extend(vim.deepcopy(case[2]), { "b" })
      assert.are.same(expected, lines())
    end)
  end

  it("does not double a marker 'formatoptions' continues lists with", function()
    -- vim-markdown's settings, plus "o" so `o` inserts a leader too.
    h.open({ "- [ ] a" })
    vim.bo.formatoptions = vim.bo.formatoptions .. "ro"
    vim.bo.comments = "b:>,b:*,b:+,b:-"
    press("A<Newline>b<Esc>")
    press("<Below>c<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b", "- [ ] c" }, lines())
  end)

  it("keeps working while rendering is disabled", function()
    h.open({ "- [ ] a" })
    vim.cmd("Tickbox disable")
    press("A<Newline>b<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b" }, lines())
  end)

  it("opens a task below with open-below and above with open-above", function()
    h.open({ "- [ ] a", "  * [x] c" })
    press("gg<Below>b<Esc>")
    press("G<Above>z<Esc>")
    assert.are.same({ "- [ ] a", "- [ ] b", "  * [ ] z", "  * [x] c" }, lines())
  end)

  it("undoes an opened task in one step with the typed text", function()
    h.open({ "- [ ] a" })
    h.pause()
    press("<Below>b<Esc>u")
    assert.are.same({ "- [ ] a" }, lines())
  end)

  it("undoes a task opened above in one step with the typed text", function()
    h.open({ "- [ ] a" })
    h.pause()
    press("<Above>b<Esc>u")
    assert.are.same({ "- [ ] a" }, lines())
  end)

  it("is a plain o and O off a task line", function()
    h.open({ "a" })
    press("<Below>b<Esc>")
    press("<Above>z<Esc>")
    assert.are.same({ "a", "z", "b" }, lines())
  end)

  it("is a plain <CR> with the cursor before the task text", function()
    h.open({ "- [ ] a" })
    press("0i<Newline><Esc>")
    assert.are.same({ "", "- [ ] a" }, lines())
  end)

  it("ends the list on an empty task by clearing it", function()
    h.open({ "- [ ] a", "  - [x]   " })
    press("GA<Newline>b<Esc>")
    assert.are.same({ "- [ ] a", "b" }, lines())
  end)

  it("undoes the new task in one step with the typed text", function()
    h.open({ "- [ ] a" })
    h.pause()
    press("A<Newline>b<Esc>u")
    assert.are.same({ "- [ ] a" }, lines())
  end)
end)
