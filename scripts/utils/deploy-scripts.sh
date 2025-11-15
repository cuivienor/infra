#!/bin/bash
# Deploy scripts to Proxmox containers

SCRIPTS_DIR="/home/cuiv/dev/homelab-notes/scripts"

echo "Deploying scripts to containers..."

# CT 200 (ripper)
echo "→ CT 200 (ripper): rip-disc.sh"
scp "$SCRIPTS_DIR/rip-disc.sh" root@homelab:/tmp/
ssh root@homelab "pct push 200 /tmp/rip-disc.sh /home/media/scripts/rip-disc.sh && pct exec 200 -- chown media:media /home/media/scripts/rip-disc.sh && pct exec 200 -- chmod +x /home/media/scripts/rip-disc.sh"

# CT 201 (transcoder)
echo "→ CT 201 (transcoder): all processing scripts"
scp "$SCRIPTS_DIR"/{migrate-to-1-ripped.sh,analyze-media.sh,organize-and-remux-movie.sh,organize-and-remux-tv.sh,transcode-queue.sh,promote-to-ready.sh,filebot-process.sh} root@homelab:/tmp/

ssh root@homelab "pct exec 201 -- mkdir -p /home/media/scripts"

for script in migrate-to-1-ripped.sh analyze-media.sh organize-and-remux-movie.sh organize-and-remux-tv.sh transcode-queue.sh promote-to-ready.sh filebot-process.sh; do
  echo "  - $script"
  # shellcheck disable=SC2029  # Variable expansion on client side is intentional
  ssh root@homelab "pct push 201 /tmp/$script /home/media/scripts/$script && pct exec 201 -- chown media:media /home/media/scripts/$script && pct exec 201 -- chmod +x /home/media/scripts/$script"
done

echo ""
echo "✓ All scripts deployed!"
echo ""
echo "Next steps:"
echo "  1. SSH to CT 201: ssh root@homelab then pct enter 201"
echo "  2. Switch to media user: su - media"
echo "  3. Run migration: cd /mnt/storage/media/staging && ~/scripts/migrate-to-1-ripped.sh"
