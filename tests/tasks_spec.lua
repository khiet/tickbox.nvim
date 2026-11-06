local h = require("tests.helpers")
local tickbox = require("tickbox")

describe("tasks()", function()
  it("returns each task with its text and fields", function()
    h.open({
      "# Heading",
      "- [ ] FUS-1136 Carry the package on secondary insurances [priority:: high] [repo:: FBA + FA]",
    })
    assert.are.same({
      {
        lnum = 2,
        state = "unchecked",
        text = "FUS-1136 Carry the package on secondary insurances",
        fields = { priority = "high", repo = "FBA + FA" },
        indent = 0,
      },
    }, tickbox.tasks())
  end)

  it("reports all four states", function()
    h.open({ "- [ ] a", "- [/] b", "- [x] c", "- [X] d", "- [-] e" })
    local states = vim.tbl_map(function(task)
      return task.state
    end, tickbox.tasks())
    assert.are.same({ "unchecked", "in_progress", "checked", "checked", "cancelled" }, states)
  end)

  it("reports parents by list index and the marker column", function()
    h.open({ "- [ ] top", "  - [ ] mid", "    - [ ] leaf", "  - [ ] sib", "- [ ] other" })
    local got = vim.tbl_map(function(task)
      return { task.parent, task.indent }
    end, tickbox.tasks())
    assert.are.same({ { nil, 0 }, { 1, 2 }, { 2, 4 }, { 1, 2 }, { nil, 0 } }, got)
  end)

  it("reports the marker's display column under the buffer's 'tabstop'", function()
    local buf = h.open({ "\t- [ ] tabbed", "  \t- [ ] mixed" })
    vim.bo[buf].tabstop = 8
    local got = vim.tbl_map(function(task)
      return task.indent
    end, tickbox.tasks())
    assert.are.same({ 8, 8 }, got)
  end)

  it("skips fenced task lines", function()
    h.open({ "```", "- [ ] sample", "```", "- [ ] real" })
    local tasks = tickbox.tasks()
    assert.are.equal(1, #tasks)
    assert.are.equal(4, tasks[1].lnum)
  end)

  it("reads a loaded buffer of an unconfigured filetype by handle", function()
    local buf = h.open({ "- [x] done [k:: v]" }, "text")
    vim.bo[buf].bufhidden = "hide"
    h.open({ "nothing" })
    local tasks = tickbox.tasks(buf)
    assert.are.equal(1, #tasks)
    assert.are.same({ k = "v" }, tasks[1].fields)
  end)

  it("rejects an invalid buffer", function()
    local ok, err = pcall(tickbox.tasks, 9999)
    assert.is_false(ok)
    assert.are.equal("Tickbox: invalid buffer: 9999", err)
  end)

  it("leaves the buffer and its undo history alone", function()
    local buf = h.open({ "- [ ] a [k:: v]" })
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local seq = vim.fn.undotree().seq_cur
    tickbox.tasks()
    assert.are.equal(tick, vim.api.nvim_buf_get_changedtick(buf))
    assert.are.equal(seq, vim.fn.undotree().seq_cur)
    assert.are.same({ "- [ ] a [k:: v]" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)
end)

describe("README task table recipe", function()
  local function recipe()
    local readme = table.concat(vim.fn.readfile("README.md"), "\n")
    local code = readme:match("### Task table.-```lua\n(.-)```")
    assert.is_truthy(code)
    return code
  end

  after_each(function()
    pcall(vim.api.nvim_del_user_command, "TaskTable")
  end)

  it("lists tasks in aligned columns and jumps to one with <CR>", function()
    assert(load(recipe()))()
    local source = h.open({
      "# Work",
      "- [ ] FUS-1 Carry the package [priority:: high] [repo:: FBA + FA]",
      "  - [x] Write specs [repo:: FA]",
    })
    local source_win = vim.api.nvim_get_current_win()
    vim.cmd("TaskTable")
    assert.are_not.equal(source_win, vim.api.nvim_get_current_win())
    assert.are.same({
      h.UNCHECKED .. "  high  FBA + FA  FUS-1 Carry the package",
      h.CHECKED .. "        FA        Write specs",
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    h.type("<CR>")
    assert.are.equal(source_win, vim.api.nvim_get_current_win())
    assert.are.equal(source, vim.api.nvim_get_current_buf())
    assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])
  end)
end)
