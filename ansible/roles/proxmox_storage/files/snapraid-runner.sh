#!/bin/bash
# SnapRAID runner script
# Managed by Ansible

set -euo pipefail

SNAPRAID="/usr/local/bin/snapraid"
CONFIG="/etc/snapraid.conf"
LOG_DIR="/var/log/snapraid"
LOG_FILE="${LOG_DIR}/snapraid-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "${LOG_DIR}"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Check if snapraid is running
if pidof -x snapraid > /dev/null; then
    log "ERROR: SnapRAID is already running"
    exit 1
fi

case "${1:-}" in
    sync)
        log "Starting SnapRAID sync"
        ${SNAPRAID} -c ${CONFIG} sync 2>&1 | tee -a "${LOG_FILE}"
        log "SnapRAID sync completed"
        ;;
    scrub)
        log "Starting SnapRAID scrub ({{ snapraid_scrub_percent }}%)"
        ${SNAPRAID} -c ${CONFIG} scrub -p {{ snapraid_scrub_percent }} 2>&1 | tee -a "${LOG_FILE}"
        log "SnapRAID scrub completed"
        ;;
    status)
        ${SNAPRAID} -c ${CONFIG} status
        ;;
    *)
        echo "Usage: $0 {sync|scrub|status}"
        exit 1
        ;;
esac

# Keep only last 30 days of logs
find "${LOG_DIR}" -name "snapraid-*.log" -mtime +30 -delete

exit 0
