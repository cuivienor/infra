#!/usr/bin/env bash

window_title="Chat_Window"
app_name="Ghostty"

# Function to check if chat window exists and get its window ID
get_chat_window_id() {
    # First try to find it in AeroSpace
    local window_id=$(aerospace list-windows --all --format '%{window-id} %{app-name} %{window-title}' |
        grep "$app_name" | grep "$window_title" | head -1 | awk '{print $1}')
    
    # If not found in AeroSpace, check if process exists using AppleScript
    if [[ -z "$window_id" ]]; then
        local process_exists=$(osascript -e "
        tell application \"System Events\"
            try
                tell process \"$app_name\"
                    set windowList to every window
                    repeat with currentWindow in windowList
                        if name of currentWindow contains \"$window_title\" then
                            return \"found\"
                        end if
                    end repeat
                end tell
            end try
            return \"not_found\"
        end tell" 2>/dev/null)
        
        echo "DEBUG: Process check result: '$process_exists'" >&2
        
        # If process exists but not in AeroSpace, it's probably minimized
        if [[ "$process_exists" == "found" ]]; then
            # Try to get window ID from AeroSpace again (sometimes minimized windows still have IDs)
            window_id=$(aerospace list-windows --all --format '%{window-id} %{app-name} %{window-title}' |
                grep "$app_name" | grep "$window_title" | head -1 | awk '{print $1}')
            
            # If still no ID, return a placeholder that indicates window exists
            if [[ -z "$window_id" ]]; then
                echo "minimized_window"
                return
            fi
        fi
    fi
    
    echo "$window_id"
}

# Function to check if window is visible
is_window_visible() {
    local window_id=$1
    if [[ -n "$window_id" ]]; then
        # Check if window exists in visible windows (non-minimized)
        local visible_window=$(aerospace list-windows --workspace focused --format '%{window-id}' | grep "^$window_id$")
        echo "DEBUG: Window in focused workspace: '$visible_window'" >&2
        
        # If window is in focused workspace, it's visible
        if [[ -n "$visible_window" ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

# Function to toggle chat window visibility
toggle_chat_window() {
    local window_id=$1
    local visible=$(is_window_visible "$window_id")
    echo "DEBUG: In toggle, visible = '$visible'" >&2

    if [[ "$visible" == "true" ]]; then
        # Window is visible, hide it using macOS native minimize
        echo "DEBUG: Hiding window..." >&2
        aerospace macos-native-minimize --window-id "$window_id"
    else
        # Window is hidden, show it
        echo "DEBUG: Showing window..." >&2
        aerospace focus --window-id "$window_id"
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
echo "DEBUG: Window ID found: '$window_id'" >&2

if [[ -n "$window_id" ]]; then
    # Window exists, toggle its visibility
    if [[ "$window_id" == "minimized_window" ]]; then
        echo "DEBUG: Found minimized window, showing it..." >&2
        # Window is minimized, unminimize it using AppleScript
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
    else
        echo "DEBUG: Window exists, checking visibility..." >&2
        visible=$(is_window_visible "$window_id")
        echo "DEBUG: Window visible: '$visible'" >&2
        toggle_chat_window "$window_id"
    fi
else
    # Window doesn't exist, create it
    echo "DEBUG: No window found, creating new one..." >&2
    create_chat_window
fi

