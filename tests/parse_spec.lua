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

describe("parse.links", function()
  -- The line as it draws: each link reduced to its label.
  local function drawn(line)
    local out, at = {}, 0
    for _, link in ipairs(parse.links(line, 0)) do
      out[#out + 1] = line:sub(at + 1, link.start)
      out[#out + 1] = line:sub(link.label_start + 1, link.label_end)
      at = link.stop
    end
    out[#out + 1] = line:sub(at + 1)
    return table.concat(out)
  end

  it("returns 0-indexed, end-exclusive ranges", function()
    assert.are.same(
      { { start = 4, label_start = 5, label_end = 6, stop = 10 } },
      parse.links("see [a](u) now", 0)
    )
  end)

  it("ignores everything before `from`", function()
    assert.are.same({}, parse.links("[a](u) now", 1))
    assert.are.same(1, #parse.links("[a](u) [b](v)", 6))
  end)

  local rendered = {
    { "a label", "see [a b](https://x.io/a) now", "see a b now" },
    { "several links", "[a](u) and [b](v)", "a and b" },
    { "balanced parens in the url", "[a](https://x.io/a_(b)) now", "a now" },
    { "an angle-bracket url", "[a](<https://x.io/a b>) now", "a now" },
    { "a double-quoted title", '[a](u "t (x)") now', "a now" },
    { "a single-quoted title", "[a](u 't') now", "a now" },
    { "a parenthesized title", "[a](u (t)) now", "a now" },
    { "spaces inside the parens", "[a]( u  't' ) now", "a now" },
    { "balanced brackets in a label", "[a [b] c](u) now", "a [b] c now" },
    { "a code span in a label", "[`]`](u) now", "`]` now" },
    { "an escaped bracket in a label", "[a\\]b](u) now", "a\\]b now" },
    { "a multibyte label", "[日本語](u) now", "日本語 now" },
    { "a link after an unclosed bracket", "[ [a](u) now", "[ a now" },
    { "the inner of a link in brackets", "[[a](u)] now", "[a] now" },
    { "a link after an unmatched backtick", "` [a](u) now", "` a now" },
    { "a link after an escaped backslash", "\\\\[a](u) now", "\\\\a now" },
    { "a link after a code span", "`x` [a](u) now", "`x` a now" },
  }
  for _, case in ipairs(rendered) do
    it("renders " .. case[1], function()
      assert.are.equal(case[3], drawn(case[2]))
    end)
  end

  local raw = {
    { "an image", "![a](u) now" },
    { "an image inside a link", "[![a](u)](v) now" },
    { "a reference link", "[a][b] now" },
    { "a shortcut reference", "[a] now" },
    { "a bare url", "https://x.io/a now" },
    { "an autolink", "<https://x.io/a> now" },
    { "brackets inside an autolink", "<https://x.io/[a](u)> now" },
    { "a link in a code span", "`[a](u)` now" },
    { "a link in a double-backtick span", "`` ` [a](u) `` now" },
    { "an empty label", "[](u) now" },
    { "a blank label", "[ ](u) now" },
    { "an empty url", "[a]() now" },
    { "an empty angle url", "[a](<>) now" },
    { "an unclosed url", "[a](u now" },
    { "unbalanced parens in the url", "[a](u(b) now" },
    { "an escaped opening bracket", "\\[a](u) now" },
    { "a space inside the url", "[a](u v) now" },
    { "an unclosed title", '[a](u "t) now' },
    { "a space before the parens", "[a] (u) now" },
  }
  for _, case in ipairs(raw) do
    it("leaves raw " .. case[1], function()
      assert.are.same({}, parse.links(case[2], 0))
    end)
  end
end)
