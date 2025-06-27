#!/usr/bin/env bash

window_title="Chat_Window"
app_name="Ghostty"

# Function to check if chat window exists and get its window ID
get_chat_window_id() {
    aerospace list-windows --all --format '%{window-id} %{app-name} %{window-title}' |
        grep "$app_name" | grep "$window_title" | head -1 | awk '{print $1}'
}

# Function to check if window is visible
is_window_visible() {
    local window_id=$1
    if [[ -n "$window_id" ]]; then
        # Check if window is minimized or hidden
        osascript -e "
        tell application \"System Events\"
            try
                tell process \"$app_name\"
                    set windowList to every window
                    repeat with currentWindow in windowList
                        if name of currentWindow contains \"$window_title\" then
                            return visible of currentWindow and not (value of attribute \"AXMinimized\" of currentWindow)
                        end if
                    end repeat
                end tell
            end try
            return false
        end tell" 2>/dev/null
    else
        echo "false"
    fi
}

# Function to toggle chat window visibility
toggle_chat_window() {
    local window_id=$1

    if [[ $(is_window_visible "$window_id") == "true" ]]; then
        # Window is visible, hide it
        osascript -e "
        tell application \"System Events\"
            try
                tell process \"$app_name\"
                    set windowList to every window
                    repeat with currentWindow in windowList
                        if name of currentWindow contains \"$window_title\" then
                            set value of attribute \"AXMinimized\" of currentWindow to true
                            exit repeat
                        end if
                    end repeat
                end tell
            end try
        end tell"
    else
        # Window is hidden, show it
        aerospace focus --window-id "$window_id"
        osascript -e "
        tell application \"System Events\"
            try
                tell process \"$app_name\"
                    set windowList to every window
                    repeat with currentWindow in windowList
                        if name of currentWindow contains \"$window_title\" then
                            set value of attribute \"AXMinimized\" of currentWindow to false
                            perform action \"AXRaise\" of currentWindow
                            exit repeat
                        end if
                    end repeat
                end tell
            end try
        end tell"
    fi
}

# Function to create and configure chat window
create_chat_window() {
    # Launch Ghostty with specific title and chat script
    open -na "$app_name" --args --title="$window_title" -e "$HOME/.local/scripts/chat.bash"

    # Wait for window to appear and get its ID
    local attempts=0
    local window_id=""
    while [[ -z "$window_id" && $attempts -lt 10 ]]; do
        sleep 0.5
        window_id=$(get_chat_window_id)
        ((attempts++))
    done

    if [[ -n "$window_id" ]]; then
        # Set floating mode using AeroSpace
        aerospace layout --window-id "$window_id" floating

        # Wait a moment for floating mode to take effect
        sleep 0.5

        # Position and resize the window using AppleScript
        osascript -e "
        tell application \"System Events\"
            try
                tell process \"$app_name\"
                    set chatWindow to first window whose name contains \"$window_title\"
                    
                    -- Get screen dimensions
                    tell application \"Finder\"
                        set screenBounds to bounds of window of desktop
                        set screenWidth to item 3 of screenBounds
                        set screenHeight to item 4 of screenBounds
                    end tell
                    
                    -- Calculate window dimensions (75% width, reasonable height)
                    set windowWidth to screenWidth * 0.75
                    set windowHeight to screenHeight * 0.6
                    
                    -- Calculate position (centered horizontally, upper portion vertically)
                    set windowX to (screenWidth - windowWidth) / 2
                    set windowY to screenHeight * 0.15
                    
                    -- Set size and position
                    set size of chatWindow to {windowWidth, windowHeight}
                    set position of chatWindow to {windowX, windowY}
                    
                    -- Try to make it behave like a dialog (always on top)
                    try
                        set value of attribute \"AXModal\" of chatWindow to true
                    end try
                    
                    -- Bring to front
                    perform action \"AXRaise\" of chatWindow
                end tell
            end try
        end tell"
    fi
}

# Main logic
window_id=$(get_chat_window_id)

if [[ -n "$window_id" ]]; then
    # Window exists, toggle its visibility
    toggle_chat_window "$window_id"
else
    # Window doesn't exist, create it
    create_chat_window
fi

