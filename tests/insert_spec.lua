local h = require("tests.helpers")

local function soft(row)
  return h.screen_line(row, { soft = true })
end

describe("insert mode", function()
  local one = h.UNCHECKED .. "     one"
  local two = h.CHECKED .. "     two"

  before_each(function()
    h.open({ "- [ ] one", "- [x] two" })
    assert.are.equal(one, h.screen_line(1))
  end)

  it("shows the cursor line raw and keeps other task lines rendered", function()
    local first, second
    h.type("i<PROBE><Esc>", function()
      first, second = soft(1), soft(2)
    end)
    assert.are.equal("- [ ] one", first)
    assert.are.equal(two, second)
  end)

  it("restores the overlay on leaving, without an edit", function()
    h.type("i<Esc>")
    assert.are.equal(one, soft(1))
  end)

  it("keeps the cursor line rendered in normal mode", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    assert.are.equal(one, soft(1))
    assert.are.equal(two, soft(2))
  end)

  it("moves the raw line along with the cursor", function()
    local first, second
    -- CursorMovedI waits for an empty typeahead, so probe from a timer once idle.
    vim.defer_fn(function()
      first, second = soft(1), soft(2)
      vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    end, 20)
    vim.api.nvim_feedkeys(vim.keycode("i<Down>"), "mx!", false)
    assert.are.equal(one, first)
    assert.are.equal("- [x] two", second)
  end)

  it("also reveals the line in replace mode", function()
    local first
    h.type("R<PROBE><Esc>", function()
      first = soft(1)
    end)
    assert.are.equal("- [ ] one", first)
    assert.are.equal(one, soft(1))
  end)

  it("reveals only in the window being typed in", function()
    vim.cmd("vsplit")
    local width = vim.fn.winwidth(0)
    local other_window
    h.type("i<PROBE><Esc>", function()
      vim.cmd("redraw")
      other_window = vim.fn.screenstring(1, width + 2)
    end)
    vim.cmd("only")
    assert.are.equal(h.UNCHECKED, other_window)
  end)

  it("survives the revealed line being joined away", function()
    h.type("G0i<BS><Esc>")
    assert.are.same({ "- [ ] one- [x] two" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.equal("", vim.v.errmsg)
  end)
end)
