# Glossary

Terms the code and its tickets use. Each names one concept; use it, not a synonym.

- **Task**: a GFM task list item: a list marker, a space, a bracket pair with one interior character, a space. Ordered markers (`1.` or `1)`) make an **ordered task**.
- **State**: what a task's interior character means. Four states: unchecked `[ ]`, in progress `[/]`, checked `[x]` or `[X]`, cancelled `[-]`.
- **Interior**: the single character between a task's brackets. Writing a task's interior is how its state changes.
- **Prefix**: a task's text from the list marker through the closing bracket. Rendering draws the box over it; continuation copies it.
- **Fence**: a fenced code block, delimited by three or more backticks or tildes, possibly after a list marker. Lines inside a fence are never tasks, never headings, and never counted.
- **Tree**: the task and heading hierarchy of a buffer: each task's parent and children, and done/total counts for parents and headings.
- **Descendants**: the task lines after a task with greater indentation, up to the first non-blank line indented the same or less.
- **Counts**: `done/total` over a task's or heading's descendants. Cancelled tasks are left out; checked tasks are done.
- **Toggle**: a done/not-done switch. Checked becomes unchecked; every other state becomes checked.
- **Cycle**: advance a task to its successor: unchecked, in progress, checked, cancelled, unchecked.
- **Set**: put a task in a named state. A task already in that state is left unedited.
- **Propagate** (auto-check): after an edit, bring ancestors in line with their descendants. Never changes descendants, cancelled ancestors or headings.
- **Attached**: a buffer whose filetype is in the configured `filetypes`. Toggling, cycling, setting and continuation work only in attached buffers.
- **Disabled**: an attached buffer whose rendering was turned off with `disable`. Editing actions ignore it.
- **Foldable heading**: a heading with at least one task under it, cancelled or not. With `fold` on it has a fold, running through the line before the next heading of the same or a higher level. Its **fold level** is the number of foldable headings open at it, not its `#`s.
- **Compact box**: the box drawn one space from the task's text: the icon at the start of the prefix, the rest of the prefix hidden. Drawn with `compact` on, on lines Neovim conceals.
- **Padded box**: the box drawn as the icon and then spaces to the prefix's width, so the task's text stays in its raw column. Drawn with `compact` off, and wherever a compact box's hidden text would show: a visual selection, a window at `conceallevel` 0 or 1, a buffer without a treesitter highlighter.
- **Link**: an inline `[label](destination)` in the text after a task's prefix. With `links` on it draws as its label. A link anywhere else is not a Link here and stays raw.
- **Revealed line**: the cursor line in insert or replace mode, drawn raw so the typed text is visible.
- **Continue**: start a new unchecked task on the next line from an unordered task line, on Enter or `o`/`O`. Enter on a task with no text ends the list instead.
