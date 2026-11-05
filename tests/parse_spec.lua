local parse = require("tickbox.parse")

describe("parse.classify", function()
  it("reads an unchecked item", function()
    local task = parse.classify("- [ ] foo")
    assert.are.equal("unchecked", task.state)
    -- 0-indexed, end-exclusive bytes: "- [ ]" and the space between the brackets.
    assert.are.same({ 0, 5 }, { task.prefix_start, task.prefix_end })
    assert.are.same({ 3, 4 }, { task.interior_start, task.interior_end })
  end)

  it("reads a checked item", function()
    local task = parse.classify("- [x] foo")
    assert.are.equal("checked", task.state)
    assert.are.same({ 3, 4 }, { task.interior_start, task.interior_end })
  end)

  it("rejects lines that are not task items", function()
    assert.is_nil(parse.classify("# heading"))
    assert.is_nil(parse.classify("- plain item"))
    assert.is_nil(parse.classify(""))
  end)
end)
