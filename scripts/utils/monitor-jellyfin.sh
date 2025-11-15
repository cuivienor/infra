#!/bin/bash
# Monitor Jellyfin streaming activity in real-time
# Usage: ./monitor-jellyfin.sh [interval_seconds]

INTERVAL=${1:-5}  # Default 5 seconds
JELLYFIN_IP="192.168.1.85"

echo "Jellyfin Stream Monitor"
echo "======================="
echo "Press Ctrl+C to exit"
echo ""

while true; do
    clear
    echo "=== Jellyfin Streaming Status @ $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo ""
    
    # Count active transcodes
    TRANSCODE_COUNT=$(ssh root@${JELLYFIN_IP} "pgrep -c ffmpeg" 2>/dev/null || echo "0")
    
    echo "Active Transcodes: ${TRANSCODE_COUNT}"
    echo ""
    
    if [ "$TRANSCODE_COUNT" -gt 0 ]; then
        echo "=== Active FFmpeg Processes ==="
        ssh root@${JELLYFIN_IP} "ps aux | grep '[f]fmpeg' | awk '{print \$2, \$3, \$4, \$11, \$12, \$13, \$14, \$15}' | column -t" 2>/dev/null
        echo ""
    fi
    
    # GPU Usage
    echo "=== Intel Arc GPU Usage ==="
    ssh root@${JELLYFIN_IP} "intel_gpu_top -l 1 -s 100 2>/dev/null | grep -E 'Video|Render' | head -3" 2>/dev/null || echo "GPU monitoring not available (install intel-gpu-tools)"
    echo ""
    
    # System resources
    echo "=== Container Resources ==="
    ssh root@${JELLYFIN_IP} "echo 'CPU:' && top -bn1 | grep 'Cpu(s)' && echo 'Memory:' && free -h | grep Mem" 2>/dev/null
    echo ""
    
    echo "=== Jellyfin Service Status ==="
    ssh root@${JELLYFIN_IP} "systemctl is-active jellyfin" 2>/dev/null
    echo ""
    
    echo "Refreshing every ${INTERVAL} seconds... (Dashboard: http://${JELLYFIN_IP}:8096)"
    sleep "${INTERVAL}"
done
