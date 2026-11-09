local state = require("tickbox.state")

describe("state", function()
  it("gives every state an interior, a highlight group, a default icon and a successor", function()
    for _, name in ipairs(state.order) do
      local entry = state.states[name]
      assert.are.equal(1, #entry.interior, name)
      assert.matches("^Tickbox%u", entry.highlight, name)
      assert.is_true(vim.fn.strdisplaywidth(entry.icon) > 0, name)
      assert.is_not_nil(state.states[entry.successor], name)
    end
  end)

  it("cycles unchecked, in progress, checked, cancelled, then unchecked again", function()
    local visited = {}
    local name = "unchecked"
    for _ = 1, #state.order do
      table.insert(visited, name)
      name = state.states[name].successor
    end
    assert.are.same({ "unchecked", "in_progress", "checked", "cancelled" }, visited)
    assert.are.equal("unchecked", name)
  end)

  it("counts every state but cancelled, with checked the only one done", function()
    local done, counted = {}, {}
    for _, name in ipairs(state.order) do
      if state.is_done(name) then
        table.insert(done, name)
      end
      if state.counts(name) then
        table.insert(counted, name)
      end
    end
    assert.are.same({ "checked" }, done)
    assert.are.equal("checked", state.done)
    assert.are.same({ "unchecked", "in_progress", "checked" }, counted)
  end)

  it("reads each written interior back as its state, and X as checked too", function()
    for _, name in ipairs(state.order) do
      assert.are.equal(name, state.of_interior[state.states[name].interior])
    end
    assert.are.equal("checked", state.of_interior["X"])
    assert.is_nil(state.of_interior["?"])
  end)

  it("toggles checked to unchecked and every other state to checked", function()
    for _, name in ipairs(state.order) do
      assert.are.equal(name == "checked" and "unchecked" or "checked", state.toggled(name), name)
    end
  end)
end)
