# Demo of the interactive action picker. Render with:
#   vhs assets/demo.tape
Output assets/demo.gif

Set FontSize 17
Set Width 940
Set Height 620
Set Theme "Catppuccin Mocha"
Set Padding 14
Set TypingSpeed 60ms

Type "macconvert menu"
Sleep 800ms
Enter
Sleep 1.5s

# walk into Images and toggle a couple of actions
Down@180ms 3
Sleep 600ms
Space
Sleep 700ms
Down@180ms 2
Space
Sleep 700ms

# jump to the Video header and toggle the whole category
Down@120ms 6
Sleep 500ms
Space
Sleep 1s
Space
Sleep 800ms

# select everything, then apply
Type "a"
Sleep 1.2s
Enter
Sleep 6s
