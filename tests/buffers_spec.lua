local h = require("tests.helpers")
local buffers = require("tickbox.buffers")
local tickbox = require("tickbox")

local raw = "- [ ] foo"

local function source(name)
  return table.concat(vim.fn.readfile(("lua/tickbox/%s.lua"):format(name)), "\n")
end

describe("buffers", function()
  after_each(function()
    tickbox.setup()
  end)

  it("is the only module that gates editing", function()
    for _, name in ipairs({ "toggle", "continue" }) do
      assert.is_nil(source(name):find("tickbox.render", 1, true), name .. " requires render")
      assert.is_nil(source(name):find(".modifiable", 1, true), name .. " spells out the edit gate")
    end
  end)

  it("leaves render with only start", function()
    assert.are.same({ "start" }, vim.tbl_keys(require("tickbox.render")))
  end)

  it("lets a configured, modifiable buffer be edited", function()
    h.open({ raw })
    assert.is_true(buffers.may_edit())
    assert.is_true(buffers.may_edit(0))
    assert.is_true(buffers.may_edit(vim.api.nvim_get_current_buf()))
  end)

  it("refuses to edit a nomodifiable buffer", function()
    h.open({ raw })
    vim.bo.modifiable = false
    assert.is_false(buffers.may_edit())
    vim.bo.modifiable = true
  end)

  it("refuses to edit a filetype that is not configured", function()
    h.open({ raw }, "text")
    assert.is_false(buffers.may_edit())
    assert.is_false(buffers.is_enabled())
  end)

  it("edits a disabled buffer but does not render it", function()
    h.open({ raw })
    buffers.disable()
    assert.is_true(buffers.may_edit())
    assert.is_false(buffers.is_enabled())
    buffers.enable()
    assert.is_true(buffers.is_enabled())
  end)

  it("answers for a buffer that is not current", function()
    local first = h.open({ raw })
    vim.bo[first].bufhidden = "hide"
    h.open({ "text" }, "text")
    assert.is_true(buffers.may_edit(first))
    assert.is_true(buffers.is_enabled(first))
    vim.api.nvim_buf_delete(first, { force = true })
  end)

  it("holds the options from the latest setup", function()
    tickbox.setup({ progress = true, filetypes = { "text" } })
    assert.is_true(buffers.options().progress)
    assert.are.same({ "text" }, buffers.options().filetypes)
    tickbox.setup()
    assert.is_false(buffers.options().progress)
    assert.are.same({ "markdown" }, buffers.options().filetypes)
  end)

  it("attaches by the filetypes of the latest setup", function()
    tickbox.setup({ filetypes = { "text" } })
    h.open({ raw }, "text")
    assert.is_true(buffers.may_edit())
    h.open({ raw })
    assert.is_false(buffers.may_edit())
  end)
end)
