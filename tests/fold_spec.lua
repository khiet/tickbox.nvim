local h = require("tests.helpers")
local tickbox = require("tickbox")

local OPTIONS = { "foldmethod", "foldexpr", "foldtext", "foldlevel" }

local function fold_options()
  local values = {}
  for _, name in ipairs(OPTIONS) do
    values[name] = vim.wo[name]
  end
  return values
end

local function levels(first, last)
  local found = {}
  for lnum = first, last do
    found[#found + 1] = vim.fn.foldlevel(lnum)
  end
  return found
end

local function close_at(lnum)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.cmd("normal! zc")
end

local function append_task(lnum)
  vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { "- [ ] new" })
end

describe("fold", function()
  after_each(function()
    tickbox.setup()
    vim.cmd("only!")
  end)

  describe("off", function()
    it("is the default and changes no fold option", function()
      tickbox.setup()
      vim.cmd("enew!")
      local before = fold_options()
      h.open({ "# H", "- [ ] a" })
      assert.are.same(before, fold_options())
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("leaves fold options the user set alone", function()
      tickbox.setup()
      h.open({ "# H", "- [ ] a" })
      vim.opt_local.foldmethod = "indent"
      tickbox.setup()
      assert.are.equal("indent", vim.wo.foldmethod)
    end)
  end)

  describe("on", function()
    before_each(function()
      tickbox.setup({ fold = true })
    end)

    it("folds attached buffers and starts them open", function()
      h.open({ "# H", "- [ ] a", "text" })
      assert.are.same({ 1, 1, 1 }, levels(1, 3))
      assert.are.equal("expr", vim.wo.foldmethod)
      assert.are.equal(99, vim.wo.foldlevel)
      assert.are.equal(-1, vim.fn.foldclosed(1))
    end)

    it("folds a buffer opened before the plugin was set up", function()
      tickbox.setup()
      h.open({ "# H", "- [ ] a" })
      tickbox.setup({ fold = true })
      assert.are.same({ 1, 1 }, levels(1, 2))
      assert.are.equal(-1, vim.fn.foldclosed(1))
    end)

    it("folds every window showing the buffer, in any tabpage", function()
      tickbox.setup()
      h.open({ "# H", "- [ ] a" })
      vim.cmd("tab split")
      vim.cmd("split")
      tickbox.setup({ fold = true })
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        assert.are.equal("expr", vim.wo[win].foldmethod)
      end
      vim.cmd("tabprevious")
      assert.are.equal("expr", vim.wo.foldmethod)
      vim.cmd("tabonly!")
    end)

    it("leaves other filetypes alone", function()
      h.open({ "# H", "- [ ] a" }, "text")
      assert.are.equal("manual", vim.wo.foldmethod)
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("does not follow the window to an unattached buffer", function()
      h.open({ "# H", "- [ ] a" })
      h.open({ "# H", "- [ ] a" }, "text")
      assert.are.equal("manual", vim.wo.foldmethod)
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("folds an attached buffer shown again in a new window", function()
      local buf = h.open({ "# H", "- [ ] a" })
      vim.bo[buf].bufhidden = "hide"
      vim.cmd("enew!")
      vim.api.nvim_win_set_buf(0, buf)
      assert.are.equal("expr", vim.wo.foldmethod)
      assert.are.equal(1, vim.fn.foldlevel(1))
      vim.bo[buf].bufhidden = "wipe"
    end)

    it("removes folds when the filetype stops being attached", function()
      h.open({ "# H", "- [ ] a" })
      close_at(1)
      vim.bo.filetype = "text"
      assert.are.equal("manual", vim.wo.foldmethod)
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("removes folds when setup turns the option off", function()
      h.open({ "# H", "- [ ] a" })
      close_at(1)
      tickbox.setup()
      assert.are.equal("manual", vim.wo.foldmethod)
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("keeps a closed fold across setup", function()
      h.open({ "# H", "- [ ] a" })
      close_at(1)
      tickbox.setup({ fold = true })
      assert.are.equal(1, vim.fn.foldclosed(2))
    end)

    it("keeps the fold level the user chose across a :e style FileType", function()
      h.open({ "# H", "- [ ] a" })
      vim.cmd("normal! zM")
      vim.bo.filetype = "markdown"
      assert.are.equal(0, vim.wo.foldlevel)
    end)

    it("works with za, zM and zR", function()
      h.open({ "# H", "- [ ] a", "# I", "- [ ] b" })
      vim.cmd("normal! zM")
      assert.are.equal(1, vim.fn.foldclosed(2))
      assert.are.equal(3, vim.fn.foldclosed(4))
      vim.cmd("normal! zR")
      assert.are.equal(-1, vim.fn.foldclosed(2))
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! za")
      assert.are.equal(1, vim.fn.foldclosed(2))
    end)

    it("keeps folds through disable", function()
      h.open({ "# H", "- [ ] a" })
      tickbox.disable()
      assert.are.equal(1, vim.fn.foldlevel(1))
      assert.are.equal("expr", vim.wo.foldmethod)
    end)
  end)

  describe("refresh", function()
    before_each(function()
      tickbox.setup({ fold = true })
    end)

    it("makes a distant heading foldable when its first task arrives", function()
      h.open({ "# H", "text", "text" })
      assert.are.same({ 0, 0, 0 }, levels(1, 3))
      append_task(3)
      assert.are.same({ 1, 1, 1, 1 }, levels(1, 4))
    end)

    it("removes a heading's fold when its last task goes", function()
      h.open({ "# H", "text", "- [ ] a" })
      assert.are.same({ 1, 1, 1 }, levels(1, 3))
      vim.api.nvim_buf_set_lines(0, 2, 3, false, {})
      assert.are.same({ 0, 0 }, levels(1, 2))
    end)

    it("refreshes after typing the first task in insert mode", function()
      h.open({ "# H", "text", "" })
      assert.are.equal(0, vim.fn.foldlevel(1))
      h.type("3Gi- [ ] typed<Esc>")
      assert.are.same({ 1, 1, 1 }, levels(1, 3))
      assert.are.equal(1, vim.fn.foldlevel(1))
    end)

    it("refreshes after undo", function()
      h.open({ "# H", "text" })
      h.pause()
      append_task(2)
      assert.are.equal(1, vim.fn.foldlevel(1))
      vim.cmd("undo")
      assert.are.equal(0, vim.fn.foldlevel(1))
    end)

    it("refreshes every window showing the buffer", function()
      h.open({ "# H", "text" })
      vim.cmd("split")
      local windows = vim.api.nvim_tabpage_list_wins(0)
      append_task(2)
      for _, win in ipairs(windows) do
        vim.api.nvim_win_call(win, function()
          assert.are.equal(1, vim.fn.foldlevel(1))
        end)
      end
    end)

    it("leaves a fold the user closed still closed", function()
      h.open({ "# A", "- [ ] a", "# B", "text", "# C", "- [ ] c" })
      close_at(1)
      close_at(5)
      append_task(4)
      assert.are.equal(1, vim.fn.foldclosed(2))
      assert.are.equal(6, vim.fn.foldclosed(7))
    end)

    it("opens a heading that became foldable below a closed fold", function()
      h.open({ "# A", "- [ ] a", "# B", "text" })
      close_at(1)
      append_task(4)
      assert.are.equal(1, vim.fn.foldlevel(3))
      assert.are.equal(-1, vim.fn.foldclosed(3))
    end)

    it("opens a heading that became foldable by typing below a closed fold", function()
      h.open({ "# A", "- [ ] a", "# B", "" })
      close_at(1)
      h.type("Gi- [ ] typed<Esc>")
      assert.are.equal(1, vim.fn.foldlevel(3))
      assert.are.equal(-1, vim.fn.foldclosed(4))
      assert.are.equal(1, vim.fn.foldclosed(2))
    end)

    it("opens a fold that undo brings back below a closed fold", function()
      h.open({ "# A", "- [ ] a", "# B", "- [ ] b" })
      h.pause()
      vim.api.nvim_buf_set_lines(0, 3, 4, false, {})
      assert.are.equal(0, vim.fn.foldlevel(3))
      close_at(1)
      vim.cmd("undo")
      assert.are.equal(1, vim.fn.foldlevel(3))
      assert.are.equal(-1, vim.fn.foldclosed(4))
      assert.are.equal(1, vim.fn.foldclosed(2))
    end)

    it("does not open a closed parent when a child becomes foldable", function()
      h.open({ "# A", "- [ ] a", "## B", "text" })
      close_at(1)
      append_task(4)
      assert.are.equal(1, vim.fn.foldclosed(5))
    end)

    it("leaves a closed fold closed when another heading loses its fold", function()
      h.open({ "# A", "- [ ] a", "# B", "- [ ] b" })
      close_at(1)
      vim.api.nvim_buf_set_lines(0, 3, 4, false, {})
      assert.are.equal(1, vim.fn.foldclosed(2))
      assert.are.equal(0, vim.fn.foldlevel(3))
    end)

    it("does not touch a window the user moved to another foldmethod", function()
      h.open({ "# H", "text" })
      vim.opt_local.foldmethod = "manual"
      append_task(2)
      assert.are.equal("manual", vim.wo.foldmethod)
    end)
  end)

  describe("closed heading", function()
    local fillchars

    before_each(function()
      tickbox.setup({ fold = true, progress = true })
      -- Blank fill, so a screen line is only the text and count.
      fillchars = vim.o.fillchars
      vim.o.fillchars = "fold: "
    end)

    after_each(function()
      vim.o.fillchars = fillchars
    end)

    it("leaves the fold fill to 'fillchars'", function()
      vim.o.fillchars = "fold:."
      h.open({ "# H", "- [x] a" })
      close_at(1)
      assert.is_truthy(vim.startswith(h.screen_line(1), "# H 1/1.."))
    end)

    it("shows its text and count, not the fold summary", function()
      h.open({ "### CRM", "", "- [x] a", "- [/] b", "- [ ] c" })
      close_at(1)
      assert.are.equal("### CRM 1/3", h.screen_line(1))
    end)

    it("shows its count once, whether open or closed", function()
      h.open({ "# H", "- [x] a" })
      assert.are.equal("# H 1/1", h.screen_line(1))
      close_at(1)
      assert.are.equal("# H 1/1", h.screen_line(1))
      vim.cmd("normal! zo")
      assert.are.equal("# H 1/1", h.screen_line(1))
    end)

    it("shows no count when only cancelled tasks are under it", function()
      h.open({ "# H", "- [-] a", "next" })
      close_at(1)
      assert.are.equal("# H", h.screen_line(1))
    end)

    it("shows no count without progress", function()
      tickbox.setup({ fold = true })
      h.open({ "# H", "- [x] a" })
      close_at(1)
      assert.are.equal("# H", h.screen_line(1))
    end)

    it("drops the count on disable and keeps the fold closed", function()
      h.open({ "# H", "- [x] a" })
      close_at(1)
      assert.are.equal("# H 1/1", h.screen_line(1))
      tickbox.disable()
      assert.are.equal("# H", h.screen_line(1))
      assert.are.equal(1, vim.fn.foldclosed(2))
    end)

    it("keeps the count beside the text when scrolled horizontally", function()
      h.open({ "# Heading", "- [x] a" })
      vim.opt_local.wrap = false
      close_at(1)
      vim.cmd("normal! 2zl")
      assert.are.equal("Heading 1/1", h.screen_line(1))
    end)

    it("keeps its text highlighting", function()
      h.open({ "# H", "- [x] a" })
      vim.cmd([[syntax match TickboxTestHeading /^# H/]])
      vim.api.nvim_set_hl(0, "TickboxTestHeading", { fg = "#ff0000", bold = true })
      -- An empty Folded leaves only the text's own attributes to compare.
      local folded = vim.api.nvim_get_hl(0, { name = "Folded" })
      vim.api.nvim_set_hl(0, "Folded", {})

      vim.cmd("redraw!")
      local open_attr = vim.fn.screenattr(1, 1)
      close_at(1)
      vim.cmd("redraw!")
      local closed_attr = vim.fn.screenattr(1, 1)

      vim.api.nvim_set_hl(0, "Folded", folded)
      assert.are.equal(open_attr, closed_attr)
    end)

    it("does nothing on toggle, cycle or set", function()
      local buf = h.open({ "# H", "- [ ] a" })
      close_at(1)
      assert.is_false(tickbox.toggle())
      assert.is_false(tickbox.cycle())
      assert.is_false(tickbox.set("checked"))
      assert.are.same({ "# H", "- [ ] a" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("does nothing when the cursor line is a task inside the closed fold", function()
      local buf = h.open({ "# H", "- [ ] a" })
      close_at(2)
      assert.is_false(tickbox.toggle())
      assert.are.same({ "# H", "- [ ] a" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("does nothing on :Tickbox toggle", function()
      local buf = h.open({ "# H", "- [ ] a" })
      close_at(2)
      vim.cmd("Tickbox toggle")
      assert.are.same({ "# H", "- [ ] a" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("acts on the tasks in a closed fold under a visual selection", function()
      local buf = h.open({ "# H", "- [ ] a", "- [ ] b", "# I", "- [ ] c" })
      close_at(1)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      h.type("V<Plug>(tickbox-toggle)")
      assert.are.same(
        { "# H", "- [x] a", "- [x] b", "# I", "- [ ] c" },
        vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      )
    end)

    it("acts on a closed fold at the far end of a visual selection", function()
      local buf = h.open({ "- [ ] top", "# H", "- [ ] a", "- [ ] b" })
      close_at(2)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      h.type("Vj<Plug>(tickbox-toggle)")
      assert.are.same(
        { "- [x] top", "# H", "- [x] a", "- [x] b" },
        vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      )
    end)
  end)
end)
