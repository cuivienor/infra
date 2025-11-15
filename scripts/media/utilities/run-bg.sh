#!/bin/bash
# Quick wrapper to run scripts in background with logs

SCRIPT="$1"
shift  # Remove first argument, rest are script arguments

if [ -z "$SCRIPT" ]; then
    echo "Usage: $0 <script-path> [script-args...]"
    echo ""
    echo "Examples:"
    echo '  $0 ~/scripts/organize-and-remux-tv.sh "Avatar The Last Airbender" 01'
    echo '  $0 ~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_Name/'
    exit 1
fi

# Create logs directory
mkdir -p ~/logs

# Generate log filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_NAME=$(basename "$SCRIPT" .sh)
LOG_FILE="$HOME/logs/${SCRIPT_NAME}_${TIMESTAMP}.log"

# Set STAGING_BASE if not already set
export STAGING_BASE="${STAGING_BASE:-/mnt/staging}"

echo "Starting: $SCRIPT $*"
echo "Log file: $LOG_FILE"
echo ""
echo "To monitor progress:"
echo "  tail -f $LOG_FILE"
echo ""
echo "To check if still running:"
echo "  ps aux | grep $SCRIPT_NAME"
echo ""

# Run in background with nohup, auto-confirm prompts, redirect all output to log
nohup bash -c "yes | $SCRIPT $(printf '%q ' "$@")" > "$LOG_FILE" 2>&1 &
PID=$!

echo "Started with PID: $PID"
echo "PID: $PID" >> "$LOG_FILE"

# Give it a moment to start
sleep 1

# Check if process is still running
if ps -p $PID > /dev/null; then
    echo "✓ Process running"
else
    echo "✗ Process may have failed, check log:"
    echo "  cat $LOG_FILE"
fi
