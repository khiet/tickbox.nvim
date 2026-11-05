local h = require("tests.helpers")
local tickbox = require("tickbox")

local rendered = h.UNCHECKED .. "     foo"
local raw = "- [ ] foo"

local function soft(row)
  return h.screen_line(row, { soft = true })
end

describe("enable and disable", function()
  it("shows raw text after disable and renders again after enable", function()
    h.open({ raw })
    assert.are.equal(rendered, h.screen_line(1))
    tickbox.disable()
    assert.are.equal(raw, soft(1))
    tickbox.enable()
    assert.are.equal(rendered, soft(1))
  end)

  it("works through :Tickbox", function()
    h.open({ raw })
    vim.cmd("Tickbox disable")
    assert.are.equal(raw, soft(1))
    assert.is_false(tickbox.is_enabled())
    vim.cmd("Tickbox enable")
    assert.are.equal(rendered, soft(1))
    assert.is_true(tickbox.is_enabled())
  end)

  it("leaves other buffers rendered", function()
    local first = h.open({ raw })
    vim.bo[first].bufhidden = "hide"
    local second = h.open({ raw })
    tickbox.disable(first)
    assert.is_false(tickbox.is_enabled(first))
    assert.is_true(tickbox.is_enabled(second))
    assert.are.equal(rendered, h.screen_line(1))

    vim.cmd("buffer! " .. first)
    assert.are.equal(raw, h.screen_line(1))
    tickbox.enable(first)
    vim.bo[first].bufhidden = "wipe"
  end)

  it("still toggles while disabled", function()
    h.open({ raw })
    tickbox.disable()
    assert.is_true(tickbox.toggle())
    assert.are.same({ "- [x] foo" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.equal("- [x] foo", h.screen_line(1))
  end)

  it("stays disabled through a :e reload", function()
    local path = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ raw }, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    tickbox.disable()
    vim.cmd("edit!")
    assert.are.equal(raw, h.screen_line(1))
    vim.cmd("bwipeout!")
    vim.fn.delete(path)
  end)

  it("does not attach a buffer of another filetype", function()
    h.open({ raw }, "text")
    assert.is_false(tickbox.is_enabled())
    tickbox.enable()
    assert.is_false(tickbox.is_enabled())
    assert.are.equal(raw, h.screen_line(1))
  end)

  it("rejects an invalid buffer", function()
    local ok, err = pcall(tickbox.disable, 9999)
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("9999", 1, true))
    assert.is_false(tickbox.is_enabled(9999))
  end)

  it("reports a fresh markdown buffer as enabled", function()
    h.open({ raw })
    assert.is_true(tickbox.is_enabled())
  end)
end)

describe(":Tickbox completion", function()
  it("offers every subcommand", function()
    assert.are.same({ "toggle", "enable", "disable" }, vim.fn.getcompletion("Tickbox ", "cmdline"))
  end)

  it("filters by what was typed", function()
    assert.are.same({ "enable" }, vim.fn.getcompletion("Tickbox en", "cmdline"))
    assert.are.same({}, vim.fn.getcompletion("Tickbox zzz", "cmdline"))
  end)

  it("works behind a range", function()
    assert.are.same({ "toggle" }, vim.fn.getcompletion("1,2Tickbox to", "cmdline"))
  end)

  it("offers nothing once a subcommand is given", function()
    assert.are.same({}, vim.fn.getcompletion("Tickbox toggle ", "cmdline"))
  end)
end)
