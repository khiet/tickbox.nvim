local parse = require("tickbox.parse")

describe("parse.classify", function()
  it("reads an unchecked item", function()
    local task = parse.classify("- [ ] foo")
    assert.are.equal("unchecked", task.state)
    -- 0-indexed, end-exclusive bytes: "- [ ]" and the space between the brackets.
    assert.are.same({ 0, 5 }, { task.prefix_start, task.prefix_end })
    assert.are.same({ 3, 4 }, { task.interior_start, task.interior_end })
  end)

  -- line, state, prefix range, interior range
  local accepted = {
    { "- [x] foo", "checked", { 0, 5 }, { 3, 4 } },
    { "- [X] foo", "checked", { 0, 5 }, { 3, 4 } },
    { "* [ ] foo", "unchecked", { 0, 5 }, { 3, 4 } },
    { "+ [x] foo", "checked", { 0, 5 }, { 3, 4 } },
    { "1. [ ] foo", "unchecked", { 0, 6 }, { 4, 5 } },
    { "1) [x] foo", "checked", { 0, 6 }, { 4, 5 } },
    { "12. [ ] foo", "unchecked", { 0, 7 }, { 5, 6 } },
    { "    - [ ] foo", "unchecked", { 4, 9 }, { 7, 8 } },
    { "\t- [x] foo", "checked", { 1, 6 }, { 4, 5 } },
    { "-   [ ] foo", "unchecked", { 0, 7 }, { 5, 6 } },
    { "- [ ] ", "unchecked", { 0, 5 }, { 3, 4 } },
    { "- [/] foo", "in_progress", { 0, 5 }, { 3, 4 } },
    { "- [-] foo", "cancelled", { 0, 5 }, { 3, 4 } },
    { "1. [/] foo", "in_progress", { 0, 6 }, { 4, 5 } },
    { "  * [-] foo", "cancelled", { 2, 7 }, { 5, 6 } },
  }
  for _, case in ipairs(accepted) do
    it("accepts '" .. case[1] .. "'", function()
      local task = parse.classify(case[1])
      assert.are.equal(case[2], task.state)
      assert.are.same(case[3], { task.prefix_start, task.prefix_end })
      assert.are.same(case[4], { task.interior_start, task.interior_end })
    end)
  end

  local rejected = {
    "",
    "# heading",
    "- plain item",
    "- [ ]",
    "- [ ]x",
    "- [x]foo",
    "-[ ] foo",
    "- [] foo",
    "- [  ] foo",
    "- [y] foo",
    "- [_] foo",
    "- [\\] foo",
    "- [/]foo",
    "text - [ ] foo",
    "[ ] foo",
    "1 [ ] foo",
    "a. [ ] foo",
    ". [ ] foo",
  }
  for _, line in ipairs(rejected) do
    it("rejects '" .. line .. "'", function()
      assert.is_nil(parse.classify(line))
    end)
  end
end)

describe("parse.fenced", function()
  -- Each case lists lines and the 1-indexed lines inside a fence.
  local cases = {
    { "no fence", { "a", "b" }, {} },
    { "backticks", { "a", "```", "b", "```", "c" }, { 2, 3, 4 } },
    { "tildes", { "~~~", "b", "~~~", "c" }, { 1, 2, 3 } },
    { "info string", { "```lua", "b", "```", "c" }, { 1, 2, 3 } },
    { "indented", { "- a", "    ```", "    b", "    ```", "c" }, { 2, 3, 4 } },
    { "unclosed runs to the end", { "```", "b", "c" }, { 1, 2, 3 } },
    { "other fence char does not close", { "```", "~~~", "b", "```", "c" }, { 1, 2, 3, 4 } },
    { "shorter run does not close", { "````", "```", "b", "````", "c" }, { 1, 2, 3, 4 } },
    { "longer run closes", { "```", "b", "`````", "c" }, { 1, 2, 3 } },
    { "closer takes no info string", { "```", "```lua", "b", "```", "c" }, { 1, 2, 3, 4 } },
    { "two backticks are not a fence", { "``", "b" }, {} },
    { "backtick in info string is not a fence", { "``` a`b", "c" }, {} },
    { "text after a closing run does not close", { "```", "```~", "c" }, { 1, 2, 3 } },
    { "text after a tilde run does not close", { "~~~", "~~~`", "c" }, { 1, 2, 3 } },
    { "backtick after a tilde in the info string", { "```~`", "c" }, {} },
    {
      "closer indented past its opener does not close",
      { "```markdown", "    ```", "    - [ ] sample", "    ```", "```", "c" },
      { 1, 2, 3, 4, 5 },
    },
    { "closer may be indented up to three columns", { "```", "   ```", "c" }, { 1, 2 } },
    { "opened on a bullet", { "- ```", "  - [ ] sample", "  ```", "c" }, { 1, 2, 3 } },
    { "opened on an ordered marker", { "1. ~~~md", "   b", "   ~~~", "c" }, { 1, 2, 3 } },
    { "indented marker", { "  * ```", "    b", "    ```", "c" }, { 1, 2, 3 } },
    { "tab after the marker", { "-\t```", "  - [ ] sample", "  ```", "c" }, { 1, 2, 3 } },
    { "nested markers on one line", { "- - ```", "    b", "    ```", "c" }, { 1, 2, 3 } },
    { "marker line does not close", { "```", "- ```", "b", "```", "c" }, { 1, 2, 3, 4 } },
    { "marker with one fence char is not a fence", { "- `a`", "b" }, {} },
    { "reopens after closing", { "```", "```", "b", "~~~", "c" }, { 1, 2, 4, 5 } },
  }
  for _, case in ipairs(cases) do
    it(case[1], function()
      local expected = {}
      for _, i in ipairs(case[3]) do
        expected[i] = true
      end
      assert.are.same(expected, parse.fenced(case[2]))
    end)
  end
end)

describe("parse.fields", function()
  it("splits trailing fields from the text", function()
    local text, fields =
      parse.fields("FUS-1136 Carry the package on secondary insurances [priority:: high] [repo:: FBA + FA]")
    assert.are.equal("FUS-1136 Carry the package on secondary insurances", text)
    assert.are.same({ priority = "high", repo = "FBA + FA" }, fields)
  end)

  it("removes a field in the middle without a double space", function()
    local text, fields = parse.fields("ship [due:: friday] the build")
    assert.are.equal("ship the build", text)
    assert.are.same({ due = "friday" }, fields)
  end)

  it("removes a leading field", function()
    assert.are.equal("ship it", (parse.fields("[a:: 1] ship it")))
  end)

  it("keeps a malformed token in the text", function()
    local text, fields = parse.fields("a [priority:high] b [ :: x] c")
    assert.are.equal("a [priority:high] b [ :: x] c", text)
    assert.are.same({}, fields)
  end)

  it("keeps the key as written and the last of a repeated key", function()
    local _, fields = parse.fields("x [Due_by-x:: a] [Due_by-x:: b]")
    assert.are.same({ ["Due_by-x"] = "b" }, fields)
  end)

  it("trims the value and accepts no space after the colons", function()
    local _, fields = parse.fields("x [a::1] [b::   two  ]")
    assert.are.same({ a = "1", b = "two" }, fields)
  end)

  it("trims the text with no fields", function()
    local text, fields = parse.fields("  plain  ")
    assert.are.equal("plain", text)
    assert.are.same({}, fields)
  end)
end)
