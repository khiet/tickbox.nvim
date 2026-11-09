local h = require("tests.helpers")
local state = require("tickbox.state")

local function per_state(field)
  local values = {}
  for _, name in ipairs(state.order) do
    table.insert(values, state.states[name][field])
  end
  return values
end

describe("state", function()
  it("gives every state an interior, a highlight group and a default icon", function()
    assert.are.same({ "unchecked", "in_progress", "checked", "cancelled" }, state.order)
    assert.are.same({ " ", "/", "x", "-" }, per_state("interior"))
    assert.are.same(
      { "TickboxUnchecked", "TickboxInProgress", "TickboxChecked", "TickboxCancelled" },
      per_state("highlight")
    )
    assert.are.same({ h.UNCHECKED, h.IN_PROGRESS, h.CHECKED, h.CANCELLED }, per_state("icon"))
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
    local toggled = {}
    for _, name in ipairs(state.order) do
      toggled[name] = state.toggled(name)
    end
    assert.are.same(
      { unchecked = "checked", in_progress = "checked", checked = "unchecked", cancelled = "checked" },
      toggled
    )
  end)
end)
