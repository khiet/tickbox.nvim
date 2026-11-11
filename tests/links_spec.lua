local h = require("tests.helpers")
local tickbox = require("tickbox")

local URL = "https://example.com/ABC-123"
local TASK = "- [ ] see [ABC-123](" .. URL .. ") now"
local DRAWN = h.UNCHECKED .. "     see ABC-123 now"
local RAW = h.UNCHECKED .. "     see [ABC-123](" .. URL .. ") now"

local settle = h.settle
local open_treesitter = h.open_treesitter
local rows = h.screen_lines
local embedded = h.embedded

local function write_file(lines, extension)
  local path = vim.fn.tempname() .. (extension or ".md")
  vim.fn.writefile(lines, path)
  return path
end

-- Moves the cursor off the rows under test, so 'concealcursor' plays no part.
local function park_cursor(buf)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
end

describe("links", function()
  after_each(function()
    tickbox.setup()
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")
    vim.cmd("enew!")
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end)

  describe("off", function()
    it("draws the link raw", function()
      tickbox.setup({ compact = false, links = false })
      local buf = open_treesitter({ TASK, "last" })
      park_cursor(buf)
      assert.are.equal(RAW, h.screen_line(1))
    end)
  end)

  describe("on", function()
    before_each(function()
      tickbox.setup({ compact = false })
    end)

    it("draws a link as its label and leaves the text alone", function()
      local buf = open_treesitter({ TASK, "last" })
      park_cursor(buf)
      assert.are.equal(DRAWN, h.screen_line(1))
      assert.are.equal(TASK, vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
    end)

    it("draws several links on one task", function()
      local buf = open_treesitter({ "- [ ] [a](" .. URL .. ") and [b](" .. URL .. ")", "last" })
      park_cursor(buf)
      assert.are.equal(h.UNCHECKED .. "     a and b", h.screen_line(1))
    end)

    it("draws a link on every kind of task", function()
      for _, case in ipairs({
        { "- [/] [a](" .. URL .. ")", h.IN_PROGRESS .. "     a" },
        { "1. [x] [a](" .. URL .. ")", h.CHECKED .. "      a" },
        { "  * [-] [a](" .. URL .. ")", "  " .. h.CANCELLED .. "     a" },
      }) do
        local buf = open_treesitter({ case[1], "last" })
        park_cursor(buf)
        assert.are.equal(case[2], h.screen_line(1))
      end
    end)

    it("leaves the raw forms raw on a task", function()
      local forms = {
        "![i](" .. URL .. ")",
        "[r][ref]",
        URL,
        "<" .. URL .. ">",
        "`[c](" .. URL .. ")`",
        "[](" .. URL .. ")",
      }
      for _, form in ipairs(forms) do
        local buf = open_treesitter({ "- [ ] " .. form, "last" })
        park_cursor(buf)
        assert.are.equal(h.UNCHECKED .. "     " .. form, h.screen_line(1))
      end
    end)

    it("draws every other line as it does with the option off", function()
      local lines = {
        "prose [a](" .. URL .. ") *em* `code` **strong**",
        "- bullet [a](" .. URL .. ") ~~gone~~",
        "# heading [a](" .. URL .. ")",
        "- [ ] parent [a](" .. URL .. ")",
        "  continuation [a](" .. URL .. ")",
        "```lua",
        "- [ ] fenced [a](" .. URL .. ")",
        "```",
        "  ",
        "last",
      }
      tickbox.setup({ compact = false, links = false })
      local buf = open_treesitter(lines)
      park_cursor(buf)
      local raw = rows(1, #lines)

      tickbox.setup({ compact = false })
      settle()
      park_cursor(buf)
      local with_links = rows(1, #lines)
      assert.are.equal(h.UNCHECKED .. "     parent a", with_links[4])
      with_links[4] = raw[4]
      assert.are.same(raw, with_links)
    end)

    -- Guards the test above: under stock queries this level really does conceal, so a
    -- pass there means the queries were replaced, not that parsing had not finished.
    it("needs the highlighter change to keep other lines raw", function()
      tickbox.setup({ compact = false, links = false })
      local buf = open_treesitter({ "prose [a](" .. URL .. ") *em*", "```lua", "x", "```", "last" })
      park_cursor(buf)
      vim.opt_local.conceallevel = 2
      settle()
      assert.are.equal("prose a em", h.screen_line(1))
      assert.are.equal("x", h.screen_line(2))
    end)

    describe("appearance", function()
      local function attr(col)
        h.screen_line(1)
        return vim.fn.screenattr(1, col)
      end

      -- Where "ABC-123" starts on the drawn line, past the prefix and "see ".
      local LABEL_COL = 11

      before_each(function()
        vim.api.nvim_set_hl(0, "TickboxLink", { underline = true, sp = "#ff0000" })
      end)

      after_each(function()
        -- An empty definition would still count as the user's, and hold off the default.
        vim.cmd("hi clear TickboxLink")
        vim.cmd("hi clear TickboxCheckedText")
      end)

      it("styles the label and not the text around it", function()
        local buf = open_treesitter({ TASK, "last" })
        park_cursor(buf)
        assert.are.equal(attr(LABEL_COL), attr(LABEL_COL + 6))
        local styled, before, after = attr(LABEL_COL), attr(LABEL_COL - 2), attr(LABEL_COL + 8)
        -- Treesitter already styles a label, so the group is what must make the difference.
        vim.api.nvim_set_hl(0, "TickboxLink", {})
        assert.are_not.equal(styled, attr(LABEL_COL))
        assert.are.equal(before, attr(LABEL_COL - 2))
        assert.are.equal(after, attr(LABEL_COL + 8))
      end)

      it("combines with TickboxCheckedText on a checked task", function()
        vim.api.nvim_set_hl(0, "TickboxCheckedText", { strikethrough = true })
        local checked = "- [x] see [ABC-123](" .. URL .. ") now"
        local buf = open_treesitter({ checked, "last" })
        park_cursor(buf)
        local both = attr(LABEL_COL)
        vim.api.nvim_set_hl(0, "TickboxCheckedText", {})
        local link_only = attr(LABEL_COL)
        vim.api.nvim_set_hl(0, "TickboxCheckedText", { strikethrough = true })
        vim.api.nvim_set_hl(0, "TickboxLink", {})
        local checked_only = attr(LABEL_COL)
        assert.are_not.equal(both, link_only)
        assert.are_not.equal(both, checked_only)
      end)
    end)

    describe("TickboxLink", function()
      it("links to Underlined by default and after a colorscheme change", function()
        assert.are.equal("Underlined", vim.api.nvim_get_hl(0, { name = "TickboxLink" }).link)
        vim.cmd("hi clear")
        vim.api.nvim_exec_autocmds("ColorScheme", {})
        assert.are.equal("Underlined", vim.api.nvim_get_hl(0, { name = "TickboxLink" }).link)
      end)

      it("yields to a user definition", function()
        vim.api.nvim_set_hl(0, "TickboxLink", { bold = true })
        tickbox.setup({ compact = false })
        local hl = vim.api.nvim_get_hl(0, { name = "TickboxLink" })
        assert.is_true(hl.bold)
        assert.is_nil(hl.link)
        vim.cmd("hi clear TickboxLink")
        tickbox.setup({ compact = false })
      end)
    end)

    describe("the cursor line", function()
      it("stays concealed in normal mode", function()
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, 12 })
        assert.are.equal(DRAWN, h.screen_line(1))
      end)

      it("draws raw on a Revealed line and conceals again after", function()
        local buf = open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, 12 })
        local seen
        h.type("i<PROBE><Esc>", function()
          seen = h.screen_line(1, { soft = true })
        end)
        assert.are.equal(TASK, seen)
        assert.are.equal(TASK, vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
        assert.are.equal(DRAWN, h.screen_line(1, { soft = true }))
      end)

      -- Needs a UI attached: headless Neovim keeps no screen cursor, and wincol() reports the
      -- raw column even when the cursor is drawn elsewhere.
      it("puts the insert cursor at the raw column when the line is revealed", function()
        local call, stop = embedded()
        call("nvim_exec_lua", [[require("tickbox").setup({ compact = false })]], {})
        call("nvim_command", "enew")
        call("nvim_buf_set_lines", 0, 0, -1, false, { TASK, "last" })
        call("nvim_set_option_value", "filetype", "markdown", { buf = 0 })
        -- On the final "w", the last byte raw and drawn at screen column 21.
        call("nvim_win_set_cursor", 0, { 1, #TASK - 1 })
        call("nvim_command", "redraw")
        local concealed = call("nvim_call_function", "screencol", {})

        call("nvim_input", "i")
        vim.wait(1000, function()
          return call("nvim_get_mode").mode == "i"
        end)
        call("nvim_command", "redraw")
        local revealed = call("nvim_call_function", "screencol", {})
        stop()

        assert.are.equal(21, concealed)
        assert.are.equal(#TASK, revealed)
      end)

      it("draws raw in visual mode", function()
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, 12 })
        local seen
        h.type("v<PROBE><Esc>", function()
          seen = h.screen_line(1)
        end)
        assert.are.equal(RAW, seen)
      end)
    end)

    describe("normal-mode motions", function()
      -- 0-indexed columns in TASK: the "3" ending the label, and the space after the link.
      local LABEL_END = TASK:find("3]", 1, true) - 1
      local AFTER = TASK:find(") now", 1, true)

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

      it("steps right off the label past the hidden url", function()
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, LABEL_END })
        move("l")
        assert.are.equal(AFTER, col())
      end)

      it("steps left from after the link onto the label", function()
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, AFTER })
        move("h")
        assert.are.equal(LABEL_END, col())
      end)

      it("steps over the hidden bracket both ways", function()
        open_treesitter({ TASK, "last" })
        local before = TASK:find("[", 7, true) - 2
        vim.api.nvim_win_set_cursor(0, { 1, before })
        move("l")
        assert.are.equal(before + 2, col())
        move("h")
        assert.are.equal(before, col())
      end)

      it("stops on the label at the end of the line", function()
        local line = "- [ ] see [ABC-123](" .. URL .. ")"
        open_treesitter({ line, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        move("$")
        assert.are.equal(LABEL_END, col())
      end)

      it("crosses adjacent links", function()
        local line = "- [ ] [a](" .. URL .. ")[b](" .. URL .. ") x"
        open_treesitter({ line, "last" })
        local a = line:find("a]", 1, true) - 1
        vim.api.nvim_win_set_cursor(0, { 1, a })
        move("l")
        assert.are.equal(line:find("b]", 1, true) - 1, col())
        move("h")
        assert.are.equal(a, col())
      end)

      it("settles on the label's nearer end when arriving from another line", function()
        local bracket = TASK:find("[", 7, true) - 1
        for _, case in ipairs({
          { "the hidden url", 30, LABEL_END },
          { "the hidden bracket", bracket, bracket + 1 },
        }) do
          open_treesitter({ TASK, string.rep("x", 40) })
          vim.api.nvim_win_set_cursor(0, { 2, case[2] })
          move("k")
          assert.are.same({ 1, case[3] }, vim.api.nvim_win_get_cursor(0), case[1])
        end
      end)

      it("lands on the whole last character of a multibyte label", function()
        local line = "- [ ] see [café](" .. URL .. ") now"
        open_treesitter({ line, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, (line:find(") now", 1, true)) })
        move("h")
        assert.are.equal(line:find("é]", 1, true) - 1, col())
      end)

      it("leaves the cursor in the url in visual mode, where the line draws raw", function()
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, LABEL_END })
        vim.cmd("doautocmd CursorMoved")
        local seen
        h.type("vl<PROBE><Esc>", function()
          vim.cmd("doautocmd CursorMoved")
          seen = col()
        end)
        assert.are.equal(LABEL_END + 1, seen)
      end)

      it("leaves the cursor in the url with links off", function()
        tickbox.setup({ compact = false, links = false })
        open_treesitter({ TASK, "last" })
        vim.api.nvim_win_set_cursor(0, { 1, LABEL_END })
        move("l")
        assert.are.equal(LABEL_END + 1, col())
      end)
    end)

    describe("gx", function()
      for _, case in ipairs({ { "the label", 12 }, { "a bracket", 10 }, { "the hidden url", 30 } }) do
        it("finds the url from " .. case[1], function()
          if vim.fn.has("nvim-0.12") == 0 then
            pending("needs treesitter url metadata in vim.ui._get_urls")
            return
          end
          open_treesitter({ TASK })
          vim.api.nvim_win_set_cursor(0, { 1, case[2] })
          assert.are.same({ URL }, vim.ui._get_urls())
        end)
      end
    end)

    it("gx opens the word under the cursor on plain task text", function()
      open_treesitter({ "- [ ] https://example.com/plain [a](" .. URL .. ")" })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })
      assert.are.same({ "https://example.com/plain" }, vim.ui._get_urls())
    end)

    describe("reloading", function()
      it("survives :e on a real file, which restarts treesitter", function()
        local path = write_file({ TASK, "prose [a](" .. URL .. ") *em*", "last" })
        vim.cmd("edit " .. path)
        settle()
        park_cursor(0)
        assert.are.equal(DRAWN, h.screen_line(1))
        assert.are.equal("prose [a](" .. URL .. ") *em*", h.screen_line(2))

        vim.cmd("edit")
        settle()
        park_cursor(0)
        assert.are.equal(DRAWN, h.screen_line(1))
        assert.are.equal("prose [a](" .. URL .. ") *em*", h.screen_line(2))
        vim.cmd("bwipeout!")
      end)

      it("recovers from treesitter restarted after the buffer opened", function()
        local buf = open_treesitter({ TASK, "prose *em*", "last" })
        vim.treesitter.start(buf, "markdown")
        settle()
        park_cursor(buf)
        assert.are.equal(DRAWN, h.screen_line(1))
        assert.are.equal("prose *em*", h.screen_line(2))
      end)

      it("applies to treesitter started after the buffer opened", function()
        local buf = h.open({ TASK, "last" })
        vim.treesitter.stop(buf)
        settle()
        assert.are.equal(0, vim.wo.conceallevel)
        vim.treesitter.start(buf, "markdown")
        settle()
        park_cursor(buf)
        assert.are.equal(DRAWN, h.screen_line(1))
      end)
    end)

    describe("which buffers qualify", function()
      it("leaves a markdown float with buftype=nofile concealing as usual", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose [a](" .. URL .. ")", "- [ ] [t](" .. URL .. ")" })
        vim.bo[buf].filetype = "markdown"
        local win = vim.api.nvim_open_win(buf, false, {
          relative = "editor",
          row = 5,
          col = 0,
          width = 60,
          height = 2,
          style = "minimal",
        })
        vim.wo[win].conceallevel = 2
        vim.treesitter.start(buf, "markdown")
        local stock = vim.treesitter.highlighter.active[buf]
        vim.treesitter.get_parser(buf):parse(true)
        settle()
        assert.are.equal(stock, vim.treesitter.highlighter.active[buf])
        assert.are.equal("", vim.wo[win].concealcursor)
        assert.are.equal(2, vim.wo[win].conceallevel)
        -- Row 6 is the float's first line, where stock conceal hides the url.
        assert.are.equal("prose a", vim.trim(h.screen_line(6)))
        vim.api.nvim_win_close(win, true)
      end)

      it("changes nothing without a treesitter highlighter", function()
        local buf = h.open({ TASK, "last" })
        vim.treesitter.stop(buf)
        park_cursor(buf)
        settle()
        assert.are.equal(0, vim.wo.conceallevel)
        assert.are.equal("", vim.wo.concealcursor)
        assert.are.equal(RAW, h.screen_line(1))
      end)

      it("keeps the options and highlighter of a window already concealing", function()
        vim.cmd("enew!")
        vim.opt_local.conceallevel = 1
        vim.opt_local.concealcursor = "n"
        local buf = h.open({ TASK, "last" })
        vim.opt_local.conceallevel = 1
        vim.opt_local.concealcursor = "n"
        vim.treesitter.start(buf, "markdown")
        local stock = vim.treesitter.highlighter.active[buf]
        settle()
        assert.are.equal(1, vim.wo.conceallevel)
        assert.are.equal("n", vim.wo.concealcursor)
        assert.are.equal(stock, vim.treesitter.highlighter.active[buf])
      end)
    end)

    describe("a buffer also shown in a window already concealing", function()
      it("keeps the shared highlighter and leaves the other window raw", function()
        local buf = h.open({ TASK, "prose [a](" .. URL .. ")", "last" })
        vim.opt_local.conceallevel = 1
        vim.treesitter.start(buf, "markdown")
        local stock = vim.treesitter.highlighter.active[buf]
        settle()
        vim.cmd("split")
        vim.opt_local.conceallevel = 0
        vim.opt_local.concealcursor = ""
        settle()
        assert.are.equal(stock, vim.treesitter.highlighter.active[buf])
        assert.are.equal(0, vim.wo.conceallevel)
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        assert.are.equal(RAW, h.screen_line(1))
        vim.cmd("wincmd p")
        assert.are.equal(1, vim.wo.conceallevel)
      end)
    end)

    describe("when the highlighter cannot start", function()
      local real_new = vim.treesitter.highlighter.new

      after_each(function()
        vim.treesitter.highlighter.new = real_new
      end)

      it("keeps the stock highlighter, draws raw and settles", function()
        vim.treesitter.highlighter.new = function(parser, opts)
          if opts and opts.queries then
            error("no queries option here")
          end
          return real_new(parser, opts)
        end
        local redraws = 0
        local probe = vim.api.nvim_create_namespace("tickbox_links_probe")
        vim.api.nvim_set_decoration_provider(probe, {
          on_win = function()
            redraws = redraws + 1
          end,
        })

        local buf = open_treesitter({ TASK, "last" })
        park_cursor(buf)
        assert.are.equal(RAW, h.screen_line(1))
        assert.is_truthy(vim.treesitter.highlighter.active[buf])
        assert.are.equal(0, vim.wo.conceallevel)

        -- A retry loop would repaint on its own while the event loop runs.
        redraws = 0
        vim.wait(100, function()
          return false
        end)
        vim.api.nvim_set_decoration_provider(probe, {})
        assert.are.equal(0, redraws)
      end)
    end)

    describe(":Tickbox", function()
      it("disable shows the link raw and enable restores it", function()
        local buf = open_treesitter({ TASK, "last" })
        park_cursor(buf)
        vim.cmd("Tickbox disable")
        assert.are.equal(TASK, h.screen_line(1))
        vim.cmd("Tickbox enable")
        assert.are.equal(DRAWN, h.screen_line(1))
      end)
    end)

    describe("turning it off", function()
      it("restores the options and the stock highlighter", function()
        local buf = open_treesitter({ TASK, "prose *em*", "last" })
        local ours = vim.treesitter.highlighter.active[buf]
        assert.are.equal(2, vim.wo.conceallevel)

        tickbox.setup({ compact = false, links = false })
        settle()
        assert.are.equal(0, vim.wo.conceallevel)
        assert.are.equal("", vim.wo.concealcursor)
        assert.is_truthy(vim.treesitter.highlighter.active[buf])
        assert.are_not.equal(ours, vim.treesitter.highlighter.active[buf])
        park_cursor(buf)
        assert.are.equal(RAW, h.screen_line(1))

        -- The stock queries are back: raising the level conceals the prose again.
        vim.opt_local.conceallevel = 2
        settle()
        assert.are.equal("prose em", h.screen_line(2))
      end)

      it("restores a split, which copied the options but no window variable", function()
        open_treesitter({ TASK, "last" })
        vim.cmd("split")
        assert.are.equal(2, vim.wo.conceallevel)
        tickbox.setup({ compact = false, links = false })
        assert.are.equal(0, vim.wo.conceallevel)
        vim.cmd("wincmd p")
        assert.are.equal(0, vim.wo.conceallevel)
      end)
    end)

    describe("moving between buffers", function()
      it("does not leak the options into another buffer in the window", function()
        open_treesitter({ TASK })
        assert.are.equal(2, vim.wo.conceallevel)
        local path = write_file({ "text" }, ".txt")
        vim.cmd("edit! " .. path)
        assert.are.equal(0, vim.wo.conceallevel)
        assert.are.equal("", vim.wo.concealcursor)
        vim.cmd("bwipeout!")
      end)

      it("applies again when the buffer comes back", function()
        local path = write_file({ TASK, "last" })
        vim.cmd("edit " .. path)
        settle()
        vim.cmd("enew!")
        assert.are.equal(0, vim.wo.conceallevel)
        vim.cmd("buffer " .. vim.fn.fnameescape(path))
        settle()
        assert.are.equal(2, vim.wo.conceallevel)
        vim.cmd("bwipeout!")
      end)
    end)
  end)
end)
