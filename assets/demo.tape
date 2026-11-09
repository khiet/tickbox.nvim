# Records the README demo. Run from the repo root, after `brew install vhs`:
#
#   vhs assets/demo.tape
#
# Needs a Nerd Font installed for the default icons. The recording opens
# assets/demo.md with assets/demo_init.lua and quits without saving, so the
# sample file is left as it was.
Output assets/demo.gif

Set Shell "zsh"
Set FontFamily "Hack Nerd Font"
Set FontSize 18
Set Width 880
Set Height 540
Set Padding 16
Set TypingSpeed 60ms

Hide
Type "nvim --noplugin -i NONE -u assets/demo_init.lua assets/demo.md"
Enter
Sleep 1s
Show

# Four states, counts on the headings, done text struck through.
Sleep 2s

# Toggle: Eggs becomes done and the Groceries count moves.
Type "7G"
Sleep 500ms
Type " t"
Sleep 1.5s

# Propagate: ticking the last child ticks its parent.
Type "14G"
Sleep 500ms
Type " t"
Sleep 1.5s

# Cycle: to do, in progress, done, cancelled.
Type "15G"
Sleep 500ms
Type " c"
Sleep 700ms
Type " c"
Sleep 700ms
Type " c"
Sleep 1.5s

# Continue: Enter on a task starts the next one.
Type "A"
Enter
Sleep 400ms
Type "Call the plumber"
Sleep 400ms
Escape
Sleep 1.5s

# Fold: a closed heading keeps its text and its count.
Type "3G"
Sleep 500ms
Type "za"
Sleep 2.5s

Hide
Type ":q!"
Enter
