# tickbox.nvim

Render GitHub-style task lists in markdown buffers and toggle them from normal mode.

- `- [ ] task` renders as a hollow box, `- [x] task` as a ticked box. Nothing else in the buffer is changed.
- One mapping toggles the task under the cursor, or every task in a visual range.
- No treesitter, no `conceallevel`, no default keymaps.

Requires Neovim 0.10 or later. The default glyphs need a Nerd Font; see [Options](#options) for Unicode ones.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "khiet/tickbox.nvim", ft = "markdown" }
```

To pass [options](#options), add `opts = { ... }`. Extra `filetypes` also need listing in `ft`, or the plugin stays unloaded until a markdown buffer opens.

Any other plugin manager, or `packadd`, works too: the plugin attaches itself on `FileType`, and calling `setup` is optional.

## Options

`require("tickbox").setup(opts)` with these defaults:

```lua
require("tickbox").setup({
  filetypes = { "markdown" },                  -- replaces the default list
  icons = { unchecked = "󰄱", checked = "󰱒" }, -- either one may be left out
})
```

Each call starts from the defaults rather than the previous call's options. Below Neovim 0.10 it raises an error naming the minimum version. Without a Nerd Font, try `icons = { unchecked = "☐", checked = "☑" }`.

## Commands

| Command | Effect |
| --- | --- |
| `:Tickbox toggle` | Toggle the cursor line, or every task in a range such as `:'<,'>Tickbox toggle` |
| `:Tickbox enable` | Render the current buffer again |
| `:Tickbox disable` | Show the raw markdown of the current buffer, until `:Tickbox enable` or the buffer is wiped |

Toggling keeps working while rendering is disabled.

## Mapping

The plugin ships no default keymap. `<Plug>(tickbox-toggle)` works in normal mode, where `.` repeats it, and in visual mode, where it toggles every selected task:

```lua
vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
```

### Fallback recipe

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

## Lua API

| Function | Effect |
| --- | --- |
| `setup(opts?)` | See [Options](#options) |
| `toggle()` | Toggle the cursor line. Returns `true` if it edited the line, `false` on a non-task line, a fenced line, in a filetype that is not configured or in a nomodifiable buffer |
| `toggle_range(first, last)` | Toggle every task on these 1-indexed, inclusive lines as one undo step. Returns `true` if any line changed |
| `enable(buf?)` | Clear `disable`. A filetype that is not configured still does not render |
| `disable(buf?)` | Stop rendering the buffer |
| `is_enabled(buf?)` | Whether the buffer renders: its filetype is configured and it is not disabled |

`buf` defaults to the current buffer.

## Highlight groups

| Group | Default link |
| --- | --- |
| `TickboxUnchecked` | `Comment` |
| `TickboxChecked` | `DiagnosticOk` |

Both are defined with `default = true`, so a colorscheme or your own definition wins.

## What counts as a task

A line with optional indentation, a marker (`-`, `*`, `+`, or digits followed by `.` or `)`), spaces, `[ ]`, `[x]` or `[X]`, and then at least one space. So `- [ ]x` and a line ending in `- [ ]` stay raw.

Lines inside ``` or ~~~ fences are left alone. Fence matching is deliberately simpler than CommonMark:

- An opening fence at any indentation counts, so indented code holding a bare ``` opens a fence.
- A fence may open right after a list marker, as in `` - ``` ``.
- The end of a list item does not close its fence.

In insert and replace mode the cursor line shows its raw text, so the overlay never covers what you are editing.

## Contributing

`make test` runs the specs headless with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). It looks for plenary in `~/.local/share/nvim/lazy/plenary.nvim`, where lazy.nvim installs it. Otherwise clone it and set `PLENARY_DIR`:

```sh
git clone https://github.com/nvim-lua/plenary.nvim /path/to/plenary.nvim
make test PLENARY_DIR=/path/to/plenary.nvim
```
