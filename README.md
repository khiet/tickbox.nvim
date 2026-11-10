# tickbox.nvim

Yet another to-do plugin for Neovim, kept to one job: tick, untick or mark a
task in progress, and see a small done/total summary. It extends your markdown
workflow without getting in its way, touching only task lists, so links draw
and headings fold only where there are tasks.

Checkboxes for the task lists in your markdown notes. `- [ ]` draws as a box,
`- [x]` as a ticked box, and one key toggles the task under the cursor.

Everything else in the buffer stays as you wrote it, and there are no default
keymaps. No treesitter or `conceallevel` either, once `links` and `compact` are
both off. If you already render whole documents with
[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
or [markview.nvim](https://github.com/OXY2DEV/markview.nvim), they draw
checkboxes too and you do not need this. tickbox is for people who want the
boxes and nothing else.

![tickbox toggling, cycling and folding a task list](assets/demo.gif)

## Features

- Boxes for `[ ]`, `[/]`, `[x]` and `[-]`: to do, in progress, done, cancelled.
- Toggle or cycle the task under the cursor, or every task in a selection. `.` repeats.
- `<CR>`, `o` and `O` can start the next task for you.
- `done/total` counts on parent tasks and headings.
- Parents tick themselves once every child is done.
- Headings with tasks fold, with native `za`, `zM` and `zR`.
- The box sits one space from the task's text, so lines indented under a task line up with it.
- Links on task lines draw as just their label, and `gx` still opens them.
- No default keymaps. No treesitter or `conceallevel` once `links` and `compact` are both off.

To turn on everything that is off by default:

```lua
opts = { progress = true, auto_check_parent = true, fold = true }
```

## Requirements

- Neovim 0.10 or later. Below that, `setup` raises an error naming the minimum version.
- A [Nerd Font](https://www.nerdfonts.com) for the default icons. Without one, use Unicode icons instead:

```lua
opts = { icons = { unchecked = "☐", in_progress = "◐", checked = "☑", cancelled = "☒" } }
```

## Quickstart

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "khiet/tickbox.nvim",
  ft = "markdown",
  opts = {},
  keys = {
    { "<leader>t", "<Plug>(tickbox-toggle)", mode = { "n", "x" }, ft = "markdown", desc = "Toggle task" },
    { "<leader>c", "<Plug>(tickbox-cycle)",  mode = { "n", "x" }, ft = "markdown", desc = "Cycle task state" },
  },
}
```

Then:

1. Open any markdown file and type `- [ ] buy milk`.
2. Leave insert mode. The `[ ]` draws as a box.
3. Press `<leader>t` to tick it, or `<leader>c` to walk it through to do, in progress, done and cancelled.

<details>
<summary>vim.pack and other plugin managers</summary>

With vim.pack (Neovim 0.12+):

```lua
vim.pack.add({ "https://github.com/khiet/tickbox.nvim" })
vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
```

Any other plugin manager, or `packadd`, works too: the plugin attaches itself on `FileType`, and calling `setup` is optional.

</details>

## Configuration

`require("tickbox").setup(opts)`, or lazy.nvim's `opts`, with these defaults:

```lua
require("tickbox").setup({
  filetypes = { "markdown" },                  -- replaces the default list
  icons = {                                    -- any of them may be left out
    unchecked = "󰄱",
    in_progress = "󰡖",
    checked = "󰱒",
    cancelled = "󰅗",
  },
  progress = false,                            -- done/total on parents and headings
  auto_check_parent = false,                   -- keep parents in step with children
  fold = false,                                -- fold headings that have tasks
  links = true,                                -- draw links on task lines as their label
  compact = true,                              -- draw the box one space from the task text
})
```

- `filetypes`: with lazy.nvim, extra filetypes also need listing in both `ft` fields of the plugin spec, or the plugin stays unloaded and unmapped there.
- `progress`: every parent task and heading with at least one counted task shows `done/total` at the end of its line, in `TickboxProgress`. See [Progress and parents](#progress-and-parents).
- `auto_check_parent`: after a toggle, cycle or set, an ancestor whose counted descendants are all checked becomes `[x]`, and a checked ancestor with a descendant that is not becomes `[ ]`.
- `fold`: headings that have tasks fold in attached buffers. Off, the plugin leaves every fold option untouched. See [Folding](#folding).
- `links`: an inline link on a task line draws as its label, in `TickboxLink`. `links = false` draws links raw. See [Links](#links).
- `compact`: the box draws one space from the task's text. `compact = false` pads the box to the width of `- [ ]`, so the text stays in its raw column. See [Compact box](#compact-box).

`links` and `compact` both hide text, which sets `conceallevel` and `concealcursor` on the window and replaces the buffer's treesitter highlighter. With both `false`, the plugin leaves all three alone.

Each call starts from the defaults rather than the previous call's options.

## Usage

### Task states

| Text | State | Icon key | Highlight |
| --- | --- | --- | --- |
| `[ ]` | unchecked | `unchecked` | `TickboxUnchecked` |
| `[/]` | in progress | `in_progress` | `TickboxInProgress` |
| `[x]` or `[X]` | checked | `checked` | `TickboxChecked` |
| `[-]` | cancelled | `cancelled` | `TickboxCancelled` |

Toggling is a done/not-done switch: a checked task becomes `[ ]` and every other task becomes `[x]`. Cycling walks `[ ]`, `[/]`, `[x]`, `[-]` and back to `[ ]`; `[X]` cycles as checked. Setting goes straight to the state you name and is not a toggle: a task already in that state is left alone, and `[X]` stays as written when set to `checked`.

### Progress and parents

With `progress = true`, every parent task and heading shows `done/total` for the tasks under it. Cancelled tasks are not counted. With `auto_check_parent = true`, ticking the last child ticks the parent, and unticking a child unticks it again, in the same undo step. Nesting follows indentation: a task's descendants are the task lines below it with greater indentation, and a heading holds every task up to the next heading of the same or a higher level. Full rules: `:h tickbox-progress`.

### Folding

With `fold = true`, headings that have tasks under them fold with the native `za`, `zc`, `zM` and `zR`. It sets `foldmethod`, `foldexpr`, `foldtext` and `foldlevel` on attached buffers, and folds start open. A closed heading keeps its own text and highlighting and, with `progress`, its count; the rest of the line takes the `fold` item of `fillchars`. Full rules: `:h tickbox-fold`.

### Compact box

`compact` is on by default. `- [x] buy milk` draws as the box, one space and `buy milk`: the rest of `- [x]` is hidden, so lines indented under a task line up with its text. The text does not change. With `compact = false` the box is padded to the width of `- [x]` instead, and the text stays in its raw column.

The padded box also draws wherever Neovim would show the hidden text: on every line of a visual selection, in a window at `conceallevel` 0 or 1, and in a buffer without a treesitter highlighter, such as markdown on Neovim 0.10 and 0.11 unless you start one. Three costs come with hiding text:

- Neovim wraps on the raw width, so a task line wraps 4 cells early.
- The text shifts 4 cells right while you type on a line or select it.
- Horizontal motions still cross the hidden prefix, so `l` appears to pause there.

Full rules: `:h tickbox-compact`.

### Links

`links` is on by default. `- [ ] review [ABC-123](https://example.com/ABC-123) today` draws as `review ABC-123 today`, with the label underlined. The text does not change, and `gx` opens the URL as usual. No other line changes appearance: plain bullets, prose, headings and fenced lines stay raw even when they hold links.

The line being typed shows the raw link, which is how you edit a URL. Like `compact`, it sets `conceallevel` and `concealcursor` on the window and replaces the buffer's treesitter highlighter with one that conceals nothing else, so it needs a treesitter highlighter on the buffer; without one, links stay raw. Full rules: `:h tickbox-links`.

### Commands

| Command | Effect |
| --- | --- |
| `:Tickbox toggle` | Toggle the cursor line, or every task in a range such as `:'<,'>Tickbox toggle` |
| `:Tickbox cycle` | Cycle the cursor line, or every task in a range such as `:'<,'>Tickbox cycle` |
| `:Tickbox set <state>` | Set the cursor line, or every task in a range such as `:'<,'>Tickbox set cancelled`, to `unchecked`, `in_progress`, `checked` or `cancelled` |
| `:Tickbox enable` | Render the current buffer again |
| `:Tickbox disable` | Show the raw markdown of the current buffer, until `:Tickbox enable` or the buffer is wiped |

Toggling, cycling and setting keep working while rendering is disabled.

### Mappings

The plugin ships no default keymap. `<Plug>(tickbox-toggle)`, `<Plug>(tickbox-cycle)`, `<Plug>(tickbox-set-unchecked)`, `<Plug>(tickbox-set-in-progress)`, `<Plug>(tickbox-set-checked)` and `<Plug>(tickbox-set-cancelled)` work in normal mode, where `.` repeats them, and in visual mode, where they act on every selected task as one undo step:

```lua
vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
vim.keymap.set({ "n", "x" }, "<leader>c", "<Plug>(tickbox-cycle)")
vim.keymap.set({ "n", "x" }, "<leader>p", "<Plug>(tickbox-set-in-progress)")
```

### Continuing a list

Three more `<Plug>` mappings, also unbound, start a new unchecked task with the indentation and marker of the task line under the cursor. Off a task line they act as plain keys:

| Mapping | Mode | On a task line |
| --- | --- | --- |
| `<Plug>(tickbox-newline)` | insert | Like `<CR>`; on an empty task it clears the line instead, ending the list |
| `<Plug>(tickbox-open-below)` | normal | Like `o` |
| `<Plug>(tickbox-open-above)` | normal | Like `O` |

The new task is `[ ]` whatever the state of the one under the cursor. Ordered tasks such as `1. [ ]` are not continued. `u` undoes the new task together with the text typed after it, but `.` does not repeat the task prefix. The new line ignores `formatoptions`, so a plugin that continues lists itself, like vim-markdown, does not add a second marker. Bind them per buffer, since `<CR>`, `o` and `O` are too common to map everywhere:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("i", "<CR>", "<Plug>(tickbox-newline)", { buffer = args.buf })
    vim.keymap.set("n", "o", "<Plug>(tickbox-open-below)", { buffer = args.buf })
    vim.keymap.set("n", "O", "<Plug>(tickbox-open-above)", { buffer = args.buf })
  end,
})
```

If your completion plugin confirms with `<CR>`, see [Recipes](#recipes) before binding it.

## API

| Function | Effect |
| --- | --- |
| `setup(opts?)` | See [Configuration](#configuration) |
| `toggle()` | Toggle the cursor line. Returns `true` if it edited the line, `false` on a non-task line, a fenced line, in a filetype that is not configured or in a nomodifiable buffer |
| `toggle_range(first, last)` | Toggle every task on these 1-indexed, inclusive lines as one undo step. Returns `true` if any line changed |
| `cycle()` | Cycle the cursor line. Returns what `toggle()` would |
| `cycle_range(first, last)` | Cycle every task on these lines as one undo step. Returns what `toggle_range` would |
| `set(state)` | Set the cursor line to `"unchecked"`, `"in_progress"`, `"checked"` or `"cancelled"`. Returns `true` if it edited the line, `false` if the task is already in that state or in the cases where `toggle()` returns `false`. Raises an error on an unknown state |
| `set_range(state, first, last)` | Set every task on these lines as one undo step. Tasks already in the state are left alone. Returns `true` if any line changed. Raises an error on an unknown state |
| `enable(buf?)` | Clear `disable`. A filetype that is not configured still does not render |
| `disable(buf?)` | Stop rendering the buffer |
| `is_enabled(buf?)` | Whether the buffer renders: its filetype is configured and it is not disabled |

`buf` defaults to the current buffer. The same reference lives in `:help tickbox`.

## Highlights

| Group | Default link |
| --- | --- |
| `TickboxUnchecked` | `Comment` |
| `TickboxInProgress` | `DiagnosticWarn` |
| `TickboxChecked` | `DiagnosticOk` |
| `TickboxCancelled` | `Comment` |
| `TickboxCheckedText` | None |
| `TickboxProgress` | `Comment` |
| `TickboxLink` | `Underlined` |

All are defined with `default = true`, so a colorscheme or your own definition wins.

`TickboxCheckedText` styles the text of checked tasks, after the box. It has no attributes until you define it, so checked lines look unchanged by default. To strike done tasks through and dim them like comments:

```lua
local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
vim.api.nvim_set_hl(0, "TickboxCheckedText", vim.tbl_extend("force", comment, { strikethrough = true }))
```

A `link` overrides every other attribute, so `{ strikethrough = true, link = "Comment" }` would not strike anything through.

## Task syntax

A task is a line with optional indentation, a list marker (`-`, `*`, `+`, or digits followed by `.` or `)`), spaces, `[ ]`, `[/]`, `[x]`, `[X]` or `[-]`, and then at least one space. So `- [ ]x` and a line ending in `- [ ]` stay raw. Lines inside ``` or ~~~ fences are left alone, and in insert and replace mode the cursor line shows its raw text, so the overlay never covers what you are editing. Full rules, including how fences are matched: `:h tickbox-tasks`.

## Recipes

### Completion plugins and `<CR>`

A buffer-local `<CR>` hides a completion plugin's global one. If yours confirms with `<CR>`, check its menu first. For nvim-cmp, use this in place of the `<CR>` line in the [Continuing a list](#continuing-a-list) callback:

```lua
vim.keymap.set("i", "<CR>", function()
  if require("cmp").visible() then
    return "<Cmd>lua require('cmp').confirm()<CR>"
  end
  return "<Plug>(tickbox-newline)"
end, { buffer = args.buf, expr = true, remap = true })
```

### Toggle or switch buffer

`toggle()` returns `false` when it did nothing, so a mapping can do something else on other lines. This maps `<leader><leader>` to toggle on a task line and otherwise switch to the alternate buffer with `<C-^>`, if there is one. Calling `toggle()` directly means `.` does not repeat it:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("n", "<leader><leader>", function()
      if not require("tickbox").toggle() and vim.fn.bufnr("#") ~= -1 then
        vim.cmd.normal({ vim.keycode("<C-^>"), bang = true })
      end
    end, { buffer = args.buf })
  end,
})
```

## Contributing

`make test` runs the specs headless with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). It looks for plenary in `~/.local/share/nvim/lazy/plenary.nvim`, where lazy.nvim installs it. Otherwise clone it and set `PLENARY_DIR`:

```sh
git clone https://github.com/nvim-lua/plenary.nvim /path/to/plenary.nvim
make test PLENARY_DIR=/path/to/plenary.nvim
```

The demo at the top is recorded with [vhs](https://github.com/charmbracelet/vhs) from `assets/demo.tape`; run `vhs assets/demo.tape` after a visible change.

## License

[MIT](LICENSE)
