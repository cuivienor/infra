#!/bin/bash
# Cleanup orphaned restic data from interrupted backups
# Run this after backups complete to remove unreferenced chunks

set -e

echo "================================================="
echo "Restic Repository Cleanup Script"
echo "================================================="
echo ""

CONTAINER_IP="192.168.1.58"

echo "Checking backup status on ct300-backup..."
ssh root@${CONTAINER_IP} "systemctl is-active restic-backup-data.service" || {
    echo "✅ No backup currently running"
}

echo ""
echo "Current repository stats:"
ssh root@${CONTAINER_IP} "source /etc/restic/data.env && restic snapshots"

echo ""
echo "Checking for orphaned data..."
ssh root@${CONTAINER_IP} "source /etc/restic/data.env && restic stats"

echo ""
read -p "Run 'restic prune' to remove orphaned data? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running prune (this may take a while)..."
    ssh root@${CONTAINER_IP} "source /etc/restic/data.env && restic prune --verbose"

    echo ""
    echo "Checking repository after prune..."
    ssh root@${CONTAINER_IP} "source /etc/restic/data.env && restic check"

    echo ""
    echo "Final stats:"
    ssh root@${CONTAINER_IP} "source /etc/restic/data.env && restic stats"

    echo ""
    echo "✅ Cleanup complete!"
    echo ""
    echo "Check B2 bucket size at: https://secure.backblaze.com/b2_buckets.htm"
else
    echo "Skipped prune. Run manually with:"
    echo "  ssh root@${CONTAINER_IP} 'source /etc/restic/data.env && restic prune'"
fi
