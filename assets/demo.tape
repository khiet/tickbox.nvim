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
# Dracula, with the cursor's text colour set to the background: the box icons are
# wider than a cell, and the default black leaves a sliver beside a box the cursor has left.
Set Theme { "name": "Dracula", "background": "#282a36", "foreground": "#f8f8f2", "cursor": "#f8f8f2", "cursorAccent": "#282a36", "selection": "#44475a", "black": "#21222c", "red": "#ff5555", "green": "#50fa7b", "yellow": "#f1fa8c", "blue": "#bd93f9", "magenta": "#ff79c6", "cyan": "#8be9fd", "white": "#f8f8f2", "brightBlack": "#6272a4", "brightRed": "#ff6e6e", "brightGreen": "#69ff94", "brightYellow": "#ffffa5", "brightBlue": "#d6acff", "brightMagenta": "#ff92df", "brightCyan": "#a4ffff", "brightWhite": "#ffffff" }

Hide
Type "nvim --noplugin -i NONE -u assets/demo_init.lua assets/demo.md"
Enter
Sleep 1s
Show

Sleep 1.5s

# Type the Rocket list: plain markdown in, boxes out, Enter continues the list.
Type "Go- [ ] Fuel the rocket"
Sleep 400ms
Enter
Type "Pack snacks"
Sleep 300ms
Enter
Type "Find the moon"
Sleep 300ms
Enter
Type "Paint flames on the side"
Sleep 300ms
# Enter on an empty task ends the list.
Enter
Sleep 400ms
Enter
Escape
Sleep 1.2s

# Visual select: one toggle ticks the rest of the crew.
Type "6G"
Sleep 400ms
Type "Vjj"
Sleep 900ms
Type " t"
Sleep 1.5s

# Fold: the finished section closes and keeps its count.
Type "3G"
Sleep 400ms
Type "za"
Sleep 1.5s

# Cycle once: in progress.
Type "12G"
Sleep 400ms
Type " c"
Sleep 1.2s

# Cycle three times: through done to cancelled.
Type "15G"
Sleep 400ms
Type " c"
Sleep 600ms
Type " c"
Sleep 600ms
Type " c"
Sleep 1.2s

# A child task: indent it, tick it, and the parent ticks itself.
Type "14G"
Sleep 400ms
Type "o"
Type "Look up"
Escape
Sleep 500ms
Type ">>"
Sleep 1.2s
Type " t"
Sleep 3s

Hide
Type ":q!"
Enter
