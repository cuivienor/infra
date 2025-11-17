#!/bin/bash
# Simple wrapper to run media pipeline scripts in background
#
# Usage: ./run-bg.sh <script-path> [script-args...]
#
# Examples:
#   ./run-bg.sh ~/scripts/rip-disc.sh -t movie -n "The Matrix"
#   ./run-bg.sh ~/scripts/rip-disc.sh -t show -n "Avatar" -s 1 -d 1
#
# The script itself handles logging and state management.
# This wrapper just handles backgrounding with nohup.

set -e

SCRIPT="$1"
shift  # Remove first argument, rest are script arguments

if [ -z "$SCRIPT" ]; then
    cat << EOF
Usage: $0 <script-path> [script-args...]

Simple wrapper to run scripts in background using nohup.
The script itself handles logging and state management.

Examples:
  $0 ~/scripts/rip-disc.sh -t movie -n "The Matrix"
  $0 ~/scripts/rip-disc.sh -t show -n "Avatar" -s 1 -d 1

Monitoring:
  ls ~/active-jobs/                    # See all active jobs
  cat ~/active-jobs/*/status           # Check status
  tail -f ~/active-jobs/*/rip.log      # Follow logs
EOF
    exit 1
fi

# Verify script exists
if [ ! -f "$SCRIPT" ]; then
    echo "Error: Script not found: $SCRIPT"
    exit 1
fi

echo "Starting in background: $SCRIPT $*"
echo ""

# Run in background with nohup
# Scripts handle their own logging, so we discard nohup output
nohup "$SCRIPT" "$@" > /dev/null 2>&1 &
PID=$!

echo "Started with PID: $PID"
echo ""

# Give it a moment to start
sleep 1

# Check if process is still running
if ps -p $PID > /dev/null 2>&1; then
    echo "✓ Process running"
    echo ""
    echo "Monitor with:"
    echo "  ls ~/active-jobs/              # See active jobs"
    echo "  tail -f ~/active-jobs/*/rip.log  # Follow logs"
else
    echo "✗ Process may have failed immediately"
    echo "Check ~/active-jobs/ for state information"
fi
