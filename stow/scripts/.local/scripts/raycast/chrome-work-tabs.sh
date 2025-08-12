#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Chrome Work Tabs
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 💼
# @raycast.description Launch Chrome with work-related tabs
# @raycast.author cuiv
# @raycast.authorURL https://github.com/cuiv

# Documentation:
# @raycast.packageName Browser Tools

# Define your tab URLs here
TABS=(
    "https://mail.google.com"
    "https://calendar.google.com"
    "https://meet.google.com"
    "https://app.graphite.dev/"
    "https://github.com/orgs/shop/projects/624/views/2"
)

# Open Chrome with a new window and all tabs
# --new creates a new instance, --args passes arguments to Chrome
open -n -a "Google Chrome" --args --new-window "${TABS[@]}"
