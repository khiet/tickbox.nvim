# tickbox.nvim

Render and toggle GitHub-style task lists in markdown.

## Features

- `- [ ] task` renders as a hollow box and `- [x] task` as a ticked box. Nothing else in the buffer changes.
- One mapping toggles the task under the cursor, or every task in a visual selection.
- No treesitter, no `conceallevel`, no default keymaps.

## Requirements

- Neovim 0.10 or later
- A [Nerd Font](https://www.nerdfonts.com) for the default icons, or set Unicode ones in [Configuration](#configuration)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "khiet/tickbox.nvim",
  ft = "markdown",
  opts = {},
  keys = {
    { "<leader>t", "<Plug>(tickbox-toggle)", mode = { "n", "x" }, ft = "markdown", desc = "Toggle task" },
  },
}
```

Extra `filetypes` also need listing in both `ft` fields, or the plugin stays unloaded and unmapped there.

<details>
<summary>vim.pack (Neovim 0.12+)</summary>

```lua
vim.pack.add({ "https://github.com/khiet/tickbox.nvim" })
vim.keymap.set({ "n", "x" }, "<leader>t", "<Plug>(tickbox-toggle)")
```

</details>

Any other plugin manager, or `packadd`, works too: the plugin attaches itself on `FileType`, and calling `setup` is optional.

## Configuration

`require("tickbox").setup(opts)`, or lazy.nvim's `opts`, with these defaults:

```lua
require("tickbox").setup({
  filetypes = { "markdown" },                  -- replaces the default list
  icons = { unchecked = "󰄱", checked = "󰱒" }, -- either one may be left out
})
```

Each call starts from the defaults rather than the previous call's options. Below Neovim 0.10 it raises an error naming the minimum version. Without a Nerd Font, try `icons = { unchecked = "☐", checked = "☑" }`.

## Usage

### Commands

| Command | Effect |
| --- | --- |
| `:Tickbox toggle` | Toggle the cursor line, or every task in a range such as `:'<,'>Tickbox toggle` |
| `:Tickbox enable` | Render the current buffer again |
| `:Tickbox disable` | Show the raw markdown of the current buffer, until `:Tickbox enable` or the buffer is wiped |

Toggling keeps working while rendering is disabled.

### Mapping

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

## API

| Function | Effect |
| --- | --- |
| `setup(opts?)` | See [Configuration](#configuration) |
| `toggle()` | Toggle the cursor line. Returns `true` if it edited the line, `false` on a non-task line, a fenced line, in a filetype that is not configured or in a nomodifiable buffer |
| `toggle_range(first, last)` | Toggle every task on these 1-indexed, inclusive lines as one undo step. Returns `true` if any line changed |
| `enable(buf?)` | Clear `disable`. A filetype that is not configured still does not render |
| `disable(buf?)` | Stop rendering the buffer |
| `is_enabled(buf?)` | Whether the buffer renders: its filetype is configured and it is not disabled |

`buf` defaults to the current buffer. The same reference lives in `:help tickbox`.

## Highlights

| Group | Default link |
| --- | --- |
| `TickboxUnchecked` | `Comment` |
| `TickboxChecked` | `DiagnosticOk` |

Both are defined with `default = true`, so a colorscheme or your own definition wins.

## Task syntax

A task is a line with optional indentation, a marker (`-`, `*`, `+`, or digits followed by `.` or `)`), spaces, `[ ]`, `[x]` or `[X]`, and then at least one space. So `- [ ]x` and a line ending in `- [ ]` stay raw.

Lines inside ``` or ~~~ fences are left alone. Fence matching is deliberately simpler than CommonMark:

- An opening fence at any indentation counts, so indented code holding a bare ``` opens a fence.
- A fence may open right after a list marker, as in `` - ``` ``. A line that starts with a marker never closes a fence.
- The end of a list item does not close its fence.

In insert and replace mode the cursor line shows its raw text, so the overlay never covers what you are editing.

## Alternatives

- [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) and [markview.nvim](https://github.com/OXY2DEV/markview.nvim) render the whole markdown document, checkboxes included. Pick one of them for full rendering; pick tickbox for task lists alone, without treesitter.

## Contributing

`make test` runs the specs headless with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). It looks for plenary in `~/.local/share/nvim/lazy/plenary.nvim`, where lazy.nvim installs it. Otherwise clone it and set `PLENARY_DIR`:

```sh
git clone https://github.com/nvim-lua/plenary.nvim /path/to/plenary.nvim
make test PLENARY_DIR=/path/to/plenary.nvim
```

## License

[MIT](LICENSE)
