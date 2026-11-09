-- The task state alphabet. Every table keyed by state in the other modules derives from
-- this one, so a new state is an edit here plus docs.
local M = {}

-- Cycle order. The first entry is the blank box, where a toggled-off task returns.
M.order = { "unchecked", "in_progress", "checked", "cancelled" }

-- Per state: `interior` is the character written between the brackets, `reads` any
-- others read as the same state; `highlight` is the group its glyph is drawn with and
-- `link` the group that defaults to; `icon` the default glyph; `role` is how the state
-- counts in progress tallies: "open", "done" or "excluded"; `successor` is filled in
-- from `order` below.
M.states = {
  unchecked = { interior = " ", highlight = "TickboxUnchecked", link = "Comment", icon = "󰄱", role = "open" },
  in_progress = { interior = "/", highlight = "TickboxInProgress", link = "DiagnosticWarn", icon = "󰡖", role = "open" },
  checked = { interior = "x", reads = { "X" }, highlight = "TickboxChecked", link = "DiagnosticOk", icon = "󰱒", role = "done" },
  cancelled = { interior = "-", highlight = "TickboxCancelled", link = "Comment", icon = "󰅗", role = "excluded" },
}

-- State by interior character, covering `interior` and `reads` of every state.
M.of_interior = {}

-- Fills in each state's successor, `of_interior`, and `done`: the one state with the
-- "done" role.
for i, name in ipairs(M.order) do
  local entry = M.states[name]
  entry.successor = M.order[i % #M.order + 1]
  M.of_interior[entry.interior] = name
  if entry.role == "done" then
    M.done = name
  end
  for _, char in ipairs(entry.reads or {}) do
    M.of_interior[char] = name
  end
end

function M.is_done(name)
  return M.states[name].role == "done"
end

-- Whether a task in the state appears in done/total counts.
function M.counts(name)
  return M.states[name].role ~= "excluded"
end

-- Toggle is a done/not-done switch: the done state goes back to the blank box, and
-- every other state becomes done.
function M.toggled(name)
  return M.is_done(name) and M.order[1] or M.done
end

return M
