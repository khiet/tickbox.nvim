local h = require("tests.helpers")
local tickbox = require("tickbox")

local rows = h.screen_lines

describe("compact", function()
  after_each(function()
    tickbox.setup()
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end)

  local URL = "https://example.com/ABC-123"
  local LINK_TASK = "- [ ] see [ABC-123](" .. URL .. ") now"

  describe("on", function()
    it("is the default: draws the icon, one space, then the text, and leaves the buffer alone", function()
      tickbox.setup()
      local buf = h.open_treesitter({ "- [x] task", "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.are.equal(h.CHECKED .. " task", h.screen_line(1))
      assert.are.same({ "- [x] task", "last" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("draws nested and ordered tasks one space from their text", function()
      h.open_treesitter({
        "- [x] FUS-1: parent task",
        "  - Priority: High",
        "  - [ ] child task",
        "1. [ ] one",
        "10) [x] ten",
        "last",
      })
      vim.api.nvim_win_set_cursor(0, { 6, 0 })
      assert.are.same({
        h.CHECKED .. " FUS-1: parent task",
        "  - Priority: High",
        "  " .. h.UNCHECKED .. " child task",
        h.UNCHECKED .. " one",
        h.CHECKED .. " ten",
      }, rows(1, 5))
    end)

    it("draws a two-cell icon one space from the text", function()
      tickbox.setup({ icons = { checked = "✅" } })
      h.open_treesitter({ "- [x] bar", "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.cmd("redraw!")
      assert.are.equal(2, vim.fn.strdisplaywidth("✅"))
      assert.are.equal(" ", vim.fn.screenstring(1, 3))
      assert.are.equal("b", vim.fn.screenstring(1, 4))
    end)

    it("hides nothing when the icon is as wide as the prefix", function()
      tickbox.setup({ icons = { unchecked = "[todo" } })
      h.open_treesitter({ "- [ ] foo", "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.are.equal("[todo foo", h.screen_line(1))
    end)

    it("draws every other line as it does with the option off", function()
      local lines = {
        "- [ ] task",
        "  indented under the task",
        "- plain bullet",
        "prose with *em*, `code` and [a](" .. URL .. ")",
        "```",
        "- [ ] fenced",
        "```",
        "last",
      }
      tickbox.setup({ compact = false })
      h.open_treesitter(lines)
      vim.api.nvim_win_set_cursor(0, { #lines, 0 })
      local off = rows(2, #lines)

      tickbox.setup()
      h.open_treesitter(lines)
      vim.api.nvim_win_set_cursor(0, { #lines, 0 })
      assert.are.same(off, rows(2, #lines))
      assert.are.equal("- [ ] fenced", h.screen_line(6))
    end)

    it("draws a link on a task as its label", function()
      h.open_treesitter({ LINK_TASK, "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.are.equal(h.UNCHECKED .. " see ABC-123 now", h.screen_line(1))
    end)

    describe("the cursor line", function()
      it("stays compact in normal mode", function()
        h.open_treesitter({ "- [ ] foo", "last" })
        vim.api.nvim_win_set_cursor(0, { 1, 7 })
        assert.are.equal(h.UNCHECKED .. " foo", h.screen_line(1))
      end)

      it("draws raw on a Revealed line and compact again after", function()
        h.open_treesitter({ "- [ ] foo", "last" })
        local seen
        h.type("A<PROBE><Esc>", function()
          seen = h.screen_line(1, { soft = true })
        end)
        assert.are.equal("- [ ] foo", seen)
        assert.are.equal(h.UNCHECKED .. " foo", h.screen_line(1, { soft = true }))
      end)
    end)

    describe("normal-mode motions", function()
      -- 0-indexed columns in TASK: the box, the space after the prefix, and the text.
      local TASK = "- [x] #114"
      local BOX, SPACE, TEXT = 0, 5, 6

      local function col()
        return vim.api.nvim_win_get_cursor(0)[2]
      end

      -- Fed keys never leave the typeahead empty, which CursorMoved waits for, so it is
      -- fired by hand: before, to record where the move starts, and after it.
      local function move(keys)
        vim.cmd("doautocmd CursorMoved")
        h.type(keys)
        vim.cmd("doautocmd CursorMoved")
      end

      local function open_at(lines, row, column)
        h.open_treesitter(lines)
        vim.api.nvim_win_set_cursor(0, { row, column })
      end

      it("steps left from the text onto the space, then the box", function()
        open_at({ TASK, "last" }, 1, TEXT)
        move("h")
        assert.are.equal(SPACE, col())
        move("h")
        assert.are.equal(BOX, col())
      end)

      it("steps right off the box onto the space, then the text", function()
        open_at({ TASK, "last" }, 1, BOX)
        move("l")
        assert.are.equal(SPACE, col())
        move("l")
        assert.are.equal(TEXT, col())
      end)

      it("lands on the box from the text with a jump left", function()
        for _, keys in ipairs({ "b", "ge", "F[" }) do
          open_at({ TASK, "last" }, 1, TEXT)
          move(keys)
          assert.are.equal(BOX, col(), keys)
        end
      end)

      it("lands on the text from the box with a jump right", function()
        for _, keys in ipairs({ "w", "W", "e" }) do
          open_at({ TASK, "last" }, 1, BOX)
          move(keys)
          assert.are.equal(TEXT, col(), keys)
        end
      end)

      it("settles on the box when arriving on a hidden byte from another line", function()
        for _, case in ipairs({ { "j", 1 }, { "k", 3 } }) do
          open_at({ "xxxxxxxx", TASK, "xxxxxxxx" }, case[2], 3)
          move(case[1])
          assert.are.same({ 2, BOX }, vim.api.nvim_win_get_cursor(0), case[1])
        end
      end)

      it("stops on the space of a task with no text", function()
        open_at({ "- [ ] ", "last" }, 1, BOX)
        move("w")
        assert.are.equal(SPACE, col())
      end)

      it("lands on the first word past extra spaces after the prefix", function()
        open_at({ "- [ ]   foo", "last" }, 1, BOX)
        move("w")
        assert.are.equal(8, col())
      end)

      it("treats the box of a nested task the same, and leaves its indentation alone", function()
        open_at({ "- [ ] parent", "  - [ ] foo" }, 2, 0)
        local seen = {}
        for step = 1, 4 do
          move("l")
          seen[step] = col()
        end
        -- The second indent space, the box, the space after the prefix, then "f".
        assert.are.same({ 1, 2, 7, 8 }, seen)
      end)

      it("keeps the box as the only stop under an icon as wide as the prefix", function()
        tickbox.setup({ icons = { unchecked = "[todo" } })
        open_at({ "- [ ] foo", "last" }, 1, BOX)
        move("l")
        assert.are.equal(SPACE, col())
      end)

      -- A jump that lands one byte right of the box looks like `l`, so it takes a second
      -- press to reach the text.
      it("stops on the space with a jump one byte right off an ordered task's box", function()
        open_at({ "1. [ ] foo", "last" }, 1, BOX)
        move("w")
        assert.are.equal(6, col())
        move("w")
        assert.are.equal(7, col())

        open_at({ "10. [ ] foo", "last" }, 1, BOX)
        move("e")
        assert.are.equal(7, col())
      end)

      it("composes with a link that starts the text", function()
        local line = "- [ ] [ABC-123](" .. URL .. ") now"
        open_at({ line, "last" }, 1, BOX)
        move("w")
        assert.are.equal(line:find("ABC", 1, true) - 1, col())
        move("h")
        assert.are.equal(SPACE, col())
        move("h")
        assert.are.equal(BOX, col())
      end)

      it("lets the cursor into the prefix in visual mode, where the box is padded", function()
        open_at({ TASK, "last" }, 1, BOX)
        vim.cmd("doautocmd CursorMoved")
        local seen
        h.type("vl<PROBE><Esc>", function()
          vim.cmd("doautocmd CursorMoved")
          seen = col()
        end)
        assert.are.equal(BOX + 1, seen)
      end)

      it("settles on the box when visual mode ends inside the prefix", function()
        open_at({ TASK, "last" }, 1, BOX)
        h.type("vll<Esc>")
        assert.are.equal(BOX, col())
      end)

      it("settles on the box when insert mode ends inside the prefix", function()
        open_at({ TASK, "last" }, 1, TEXT)
        h.type("i<Left><Left><Left><Esc>")
        assert.are.equal(BOX, col())
      end)

      it("lets the cursor into the prefix where the window pads the cursor line", function()
        open_at({ TASK, "last" }, 1, BOX)
        vim.opt_local.concealcursor = ""
        move("l")
        assert.are.equal(BOX + 1, col())
      end)

      it("lets the cursor into the prefix after :Tickbox disable", function()
        open_at({ TASK, "last" }, 1, BOX)
        vim.cmd("Tickbox disable")
        move("l")
        assert.are.equal(BOX + 1, col())
      end)
    end)

    describe("visual mode", function()
      -- Each selection is on the task text: an overlay is hidden where the text under it is
      -- selected, so a selected prefix shows raw with either box.
      local function open_on_text(lines)
        h.open_treesitter(lines)
        vim.api.nvim_win_set_cursor(0, { 1, 7 })
      end

      -- Soft reads: Neovim repaints these lines itself when the selection changes.
      it("pads the box on every line in the visual area, and only there", function()
        open_on_text({ "- [ ] one", "- [x] two", "- [ ] three", "last" })
        local seen = {}
        h.type("<C-v>j<PROBE><Esc>", function()
          for row = 1, 3 do
            seen[row] = h.screen_line(row, { soft = true })
          end
        end)
        assert.are.same({
          h.UNCHECKED .. "     one",
          h.CHECKED .. "     two",
          h.UNCHECKED .. " three",
        }, seen)
      end)

      it("draws compact again after leaving", function()
        open_on_text({ "- [ ] one", "- [x] two", "last" })
        h.type("<C-v>j<Esc>")
        assert.are.equal(h.UNCHECKED .. " one", h.screen_line(1, { soft = true }))
        assert.are.equal(h.CHECKED .. " two", h.screen_line(2, { soft = true }))
      end)

      it("pads the selection in another window on the buffer too", function()
        open_on_text({ "- [ ] one", "- [x] two", "last" })
        vim.cmd("split")
        h.settle()
        local height = vim.api.nvim_win_get_height(0)
        local seen
        h.type("v<PROBE><Esc>", function()
          -- The other window starts below this one's status line.
          seen = { h.screen_line(1), h.screen_line(height + 2), h.screen_line(height + 3) }
        end)
        assert.are.same({ h.UNCHECKED .. "     one", h.UNCHECKED .. "     one", h.CHECKED .. " two" }, seen)
      end)
    end)

    describe("which buffers qualify", function()
      it("pads the box and touches no option without a treesitter highlighter", function()
        local buf = h.open({ "- [ ] foo", "last" })
        vim.treesitter.stop(buf)
        h.settle()
        assert.are.equal(0, vim.wo.conceallevel)
        assert.are.equal("", vim.wo.concealcursor)
        assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
      end)

      -- Opens a buffer in a window the user set to conceal, as a modeline or ftplugin would.
      local function open_concealing(level)
        vim.cmd("enew!")
        local buf = h.open({ "- [ ] foo", "last" })
        vim.opt_local.conceallevel = level
        vim.opt_local.concealcursor = "n"
        vim.treesitter.start(buf, "markdown")
        local stock = vim.treesitter.highlighter.active[buf]
        h.settle()
        assert.are.equal(level, vim.wo.conceallevel)
        assert.are.equal("n", vim.wo.concealcursor)
        assert.are.equal(stock, vim.treesitter.highlighter.active[buf])
      end

      it("pads the box in a window at conceallevel 1", function()
        open_concealing(1)
        assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
      end)

      it("keeps the options and highlighter of a window at conceallevel 2 and draws compact", function()
        open_concealing(2)
        assert.are.equal(h.UNCHECKED .. " foo", h.screen_line(1))
      end)

      it("pads the cursor line where the window's concealcursor shows it raw", function()
        open_concealing(2)
        vim.opt_local.concealcursor = ""
        assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        assert.are.equal(h.UNCHECKED .. " foo", h.screen_line(1, { soft = true }))
      end)
    end)

    it("draws a count after the text of a compact parent", function()
      tickbox.setup({ progress = true })
      h.open_treesitter({ "- [ ] parent", "  - [x] a", "  - [ ] b", "last" })
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      assert.are.equal(h.UNCHECKED .. " parent 1/2", h.screen_line(1))
    end)

    it("follows a toggle on the cursor line", function()
      h.open_treesitter({ "- [ ] foo", "last" })
      tickbox.toggle()
      assert.are.equal(h.CHECKED .. " foo", h.screen_line(1, { soft = true }))
    end)

    it(":Tickbox disable draws nothing and enable restores the compact box", function()
      h.open_treesitter({ "- [ ] foo", "last" })
      vim.cmd("Tickbox disable")
      assert.are.equal("- [ ] foo", h.screen_line(1))
      vim.cmd("Tickbox enable")
      assert.are.equal(h.UNCHECKED .. " foo", h.screen_line(1))
    end)

    describe("appearance", function()
      after_each(function()
        vim.api.nvim_set_hl(0, "TickboxCheckedText", { default = true })
      end)

      it("starts TickboxCheckedText at the text, on checked lines only", function()
        h.open_treesitter({ "- [ ] abc", "- [x] abc", "plain", "last" })
        vim.api.nvim_win_set_cursor(0, { 4, 0 })
        vim.api.nvim_set_hl(0, "TickboxCheckedText", { strikethrough = true })
        vim.cmd("redraw!")
        local plain = vim.fn.screenattr(3, 1)
        -- Column 2 is the space after the icon, 3 and 5 the ends of "abc".
        assert.are.equal(plain, vim.fn.screenattr(1, 3))
        assert.are.equal(plain, vim.fn.screenattr(2, 2))
        assert.are_not.equal(plain, vim.fn.screenattr(2, 3))
        assert.are_not.equal(plain, vim.fn.screenattr(2, 5))
      end)

      -- markdown_inline captures the brackets of `[/]` and `[-]` as a link. Compact hides
      -- them, so their styling must not show on the cells left beside the icon.
      it("shows no link styling beside the icon of a [/] or [-] task", function()
        local saved = vim.api.nvim_get_hl(0, { name = "@markup.link" })
        vim.api.nvim_set_hl(0, "@markup.link", { underline = true })
        h.open_treesitter({ "- [/] a", "- [-] a", "plain", "last" })
        vim.api.nvim_win_set_cursor(0, { 4, 0 })
        vim.cmd("redraw!")
        local plain = vim.fn.screenattr(3, 1)
        local seen = {}
        for row = 1, 2 do
          seen[row] = { vim.fn.screenattr(row, 2), vim.fn.screenattr(row, 3) }
        end
        vim.api.nvim_set_hl(0, "@markup.link", saved)
        assert.are.same({ { plain, plain }, { plain, plain } }, seen)
      end)
    end)
  end)

  describe("with links off", function()
    it("draws the compact box and the link raw", function()
      tickbox.setup({ links = false })
      h.open_treesitter({ LINK_TASK, "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.are.equal(h.UNCHECKED .. " see [ABC-123](" .. URL .. ") now", h.screen_line(1))
    end)
  end)

  describe("off", function()
    it("draws the padded box while links still draw as their label", function()
      tickbox.setup({ compact = false })
      h.open_treesitter({ LINK_TASK, "last" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      assert.are.equal(h.UNCHECKED .. "     see ABC-123 now", h.screen_line(1))
    end)

    it("lets the cursor into the prefix", function()
      tickbox.setup({ compact = false })
      h.open_treesitter({ "- [x] #114", "last" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("doautocmd CursorMoved")
      h.type("l")
      vim.cmd("doautocmd CursorMoved")
      assert.are.equal(1, vim.api.nvim_win_get_cursor(0)[2])
    end)
  end)

  describe("with compact and links both off", function()
    it("restores the options and the stock highlighter", function()
      tickbox.setup()
      local buf = h.open_treesitter({ "- [ ] foo", "prose *em*", "last" })
      local ours = vim.treesitter.highlighter.active[buf]
      assert.are.equal(2, vim.wo.conceallevel)
      assert.are.equal("cn", vim.wo.concealcursor)

      tickbox.setup({ compact = false, links = false })
      h.settle()
      assert.are.equal(0, vim.wo.conceallevel)
      assert.are.equal("", vim.wo.concealcursor)
      assert.is_truthy(vim.treesitter.highlighter.active[buf])
      assert.are_not.equal(ours, vim.treesitter.highlighter.active[buf])
      assert.are.equal(h.UNCHECKED .. "     foo", h.screen_line(1))

      -- The stock queries are back: raising the level conceals the prose again.
      vim.opt_local.conceallevel = 2
      h.settle()
      assert.are.equal("prose em", h.screen_line(2))
    end)

    it("changes no window option or highlighter in a session that starts with them off", function()
      local call, stop = h.embedded()
      call("nvim_exec_lua", [[require("tickbox").setup({ compact = false, links = false })]], {})
      call("nvim_command", "setlocal conceallevel=2 concealcursor=cn")
      call("nvim_buf_set_lines", 0, 0, -1, false, { "- [ ] foo" })
      local unchanged = call(
        "nvim_exec_lua",
        [[
          vim.bo.filetype = "markdown"
          vim.treesitter.start(0, "markdown")
          local stock = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
          vim.cmd("doautocmd BufWinEnter")
          vim.cmd("redraw!")
          vim.wait(50, function() return false end)
          return stock == vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
        ]],
        {}
      )
      local level = call("nvim_get_option_value", "conceallevel", { scope = "local" })
      local cursor = call("nvim_get_option_value", "concealcursor", { scope = "local" })
      stop()
      assert.is_true(unchanged)
      assert.are.equal(2, level)
      assert.are.equal("cn", cursor)
    end)
  end)
end)
