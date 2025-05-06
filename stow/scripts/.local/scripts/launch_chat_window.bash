#!/usr/bin/env bash

window_title="Chat_Window"

# Check if the window already exists
if xdotool search --name "$window_title" >/dev/null; then
  # If it exists, toggle its visibility
  i3-msg "[title=$window_title] scratchpad show"
else
  # If it doesn't exist, create the floating terminal
  i3-msg exec "ghostty --title=$window_title -e ~/.local/scripts/chat.bash"
  sleep 1 # Give it a moment to open
  i3-msg "[title=$window_title] floating enable"
  i3-msg "[title=$window_title] resize set width 75 ppt"
  i3-msg "[title=$window_title] move position center"
  i3-msg "[title=$window_title] move up 28 ppt"
  i3-msg "[title=$window_title] move scratchpad"
  i3-msg "[title=$window_title] scratchpad show"
fi
