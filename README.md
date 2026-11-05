# tickbox.nvim

Render GitHub-style task lists in markdown buffers and toggle them from normal mode.

- `- [ ] task` renders as a hollow box, `- [x] task` as a ticked box. Nothing else in the buffer is changed.
- One mapping toggles the task under the cursor, or every task in a visual range.
- No treesitter, no `conceallevel`, no default keymaps.

Requires Neovim 0.10 or later. See the spec in issue #1.
