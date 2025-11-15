#!/bin/bash
# One-time migration script for existing Raspberry Pis
# This handles the current state → clean state transition
# After this, use Ansible playbook for repeatable setups

set -e

echo "=========================================="
echo "Raspberry Pi Migration Script"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Deploy SSH keys to both Pis"
echo "  2. Create 'cuiv' user"
echo "  3. Clean up old software (Pi-hole, Docker, etc.)"
echo "  4. Upgrade to Debian 12"
echo "  5. Remove old users (pi, media)"
echo ""
echo "⚠️  WARNING: This is destructive!"
echo ""
read -rp "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Variables
PI_HOLE_IP="192.168.1.107"
PI_HOLE_USER="pi"
PI4_IP="192.168.1.114"
PI4_USER="cuiv"
PASSWORD="0bi4amAni"
SSH_KEY="$HOME/.ssh/id_ed25519.pub"

echo ""
echo "=========================================="
echo "Phase 1: Deploy SSH Keys"
echo "=========================================="

# Function to deploy SSH key
deploy_ssh_key() {
    local ip=$1
    local user=$2
    
    echo ""
    echo "→ Deploying SSH key to $user@$ip"
    
    # Create cuiv user if needed (on pi-hole)
    if [ "$user" = "pi" ]; then
        echo "  Creating cuiv user..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$user@$ip" \
            "sudo useradd -m -s /bin/bash -G sudo cuiv 2>/dev/null || true; \
             echo 'cuiv:$PASSWORD' | sudo chpasswd; \
             echo 'cuiv ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cuiv"
        user="cuiv"
    fi
    
    # Ensure .ssh directory exists
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$user@$ip" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    
    # Deploy SSH key
    sshpass -p "$PASSWORD" ssh-copy-id -i "$SSH_KEY" -o StrictHostKeyChecking=no "$user@$ip"
    
    # Ensure sudo without password
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$user@$ip" \
        "echo 'cuiv ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/cuiv"
    
    echo "  ✅ SSH key deployed to cuiv@$ip"
}

deploy_ssh_key "$PI_HOLE_IP" "$PI_HOLE_USER"
deploy_ssh_key "$PI4_IP" "$PI4_USER"

echo ""
echo "✅ SSH keys deployed to both Pis"
echo ""
read -rp "Press Enter to continue to cleanup phase..."

echo ""
echo "=========================================="
echo "Phase 2: Cleanup Old Software"
echo "=========================================="

# Function to clean up a Pi
cleanup_pi() {
    local ip=$1
    local name=$2
    
    echo ""
    echo "→ Cleaning up $name ($ip)"
    
    ssh cuiv@"$ip" << 'ENDSSH'
set -e

echo "  Stopping services..."
sudo systemctl stop pihole-FTL 2>/dev/null || true
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl stop tailscaled 2>/dev/null || true

echo "  Removing Pi-hole..."
if command -v pihole &> /dev/null; then
    yes | sudo pihole uninstall 2>/dev/null || true
fi
sudo rm -rf /etc/pihole /opt/pihole /etc/.pihole /var/www/html/admin

echo "  Removing Docker..."
if command -v docker &> /dev/null; then
    sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
    sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    sudo docker system prune -af 2>/dev/null || true
fi
sudo apt-get purge -y docker docker.io docker-ce docker-ce-cli containerd containerd.io 2>/dev/null || true
sudo rm -rf /var/lib/docker /etc/docker

echo "  Cleaning packages..."
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo journalctl --vacuum-time=7d

echo "  ✅ Cleanup complete"
ENDSSH
}

cleanup_pi "$PI_HOLE_IP" "Pi-hole (Pi 3)"
cleanup_pi "$PI4_IP" "Pi 4"

echo ""
echo "✅ Cleanup complete on both Pis"
echo ""
read -rp "Press Enter to continue to OS upgrade..."

echo ""
echo "=========================================="
echo "Phase 3: OS Upgrade to Debian 12"
echo "=========================================="

# Function to upgrade a Pi
upgrade_pi() {
    local ip=$1
    local name=$2
    
    echo ""
    echo "→ Upgrading $name ($ip) to Debian 12"
    echo "  This will take 15-30 minutes..."
    
    ssh cuiv@"$ip" << 'ENDSSH'
set -e

echo "  Updating Bullseye packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo apt-get autoremove -y

echo "  Switching to Bookworm repos..."
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list

echo "  Updating package lists..."
sudo apt-get update

echo "  Performing distribution upgrade..."
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

echo "  Final cleanup..."
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "  ✅ Upgrade complete, reboot required"
ENDSSH

    echo "  Rebooting $name..."
    ssh cuiv@"$ip" "sudo reboot" || true
    
    echo "  Waiting for reboot..."
    sleep 30
    
    # Wait for Pi to come back
    for i in {1..30}; do
        if ssh -o ConnectTimeout=5 cuiv@"$ip" "echo ok" &>/dev/null; then
            echo "  ✅ $name is back online"
            break
        fi
        echo "  Waiting for $name to come back... ($i/30)"
        sleep 10
    done
}

upgrade_pi "$PI_HOLE_IP" "Pi-hole (Pi 3)"
echo ""
read -rp "First Pi upgraded. Press Enter to upgrade second Pi..."
upgrade_pi "$PI4_IP" "Pi 4"

echo ""
echo "✅ OS upgrades complete on both Pis"
echo ""
read -rp "Press Enter to continue to final cleanup..."

echo ""
echo "=========================================="
echo "Phase 4: Final Cleanup"
echo "=========================================="

# Function for final cleanup
final_cleanup() {
    local ip=$1
    local name=$2
    
    echo ""
    echo "→ Final cleanup on $name ($ip)"
    
    ssh cuiv@"$ip" << 'ENDSSH'
set -e

echo "  Installing essential packages..."
sudo apt-get install -y vim git curl wget htop tmux net-tools dnsutils rsync

echo "  Removing old users..."
sudo userdel -r pi 2>/dev/null || true
sudo userdel -r media 2>/dev/null || true

echo "  Disabling WiFi/Bluetooth..."
if [ -f /boot/firmware/config.txt ]; then
    if ! grep -q "disable-wifi" /boot/firmware/config.txt; then
        echo "" | sudo tee -a /boot/firmware/config.txt
        echo "# Disable WiFi and Bluetooth" | sudo tee -a /boot/firmware/config.txt
        echo "dtoverlay=disable-wifi" | sudo tee -a /boot/firmware/config.txt
        echo "dtoverlay=disable-bt" | sudo tee -a /boot/firmware/config.txt
    fi
fi

echo "  ✅ Final cleanup complete"
ENDSSH
}

final_cleanup "$PI_HOLE_IP" "Pi-hole (Pi 3)"
final_cleanup "$PI4_IP" "Pi 4"

echo ""
echo "=========================================="
echo "Phase 5: Verification"
echo "=========================================="

verify_pi() {
    local ip=$1
    local name=$2
    
    echo ""
    echo "→ Verifying $name ($ip)"
    
    ssh cuiv@"$ip" << 'ENDSSH'
echo "  OS Version: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  Current User: $(whoami)"
echo "  Pi-hole: $(command -v pihole &>/dev/null && echo 'STILL INSTALLED' || echo 'Removed ✅')"
echo "  Docker: $(command -v docker &>/dev/null && echo 'STILL INSTALLED' || echo 'Removed ✅')"
echo "  Old users: $(id pi 2>/dev/null && echo 'pi still exists' || echo 'pi removed ✅')"
ENDSSH
}

verify_pi "$PI_HOLE_IP" "Pi-hole (Pi 3)"
verify_pi "$PI4_IP" "Pi 4"

echo ""
echo "=========================================="
echo "✅ Migration Complete!"
echo "=========================================="
echo ""
echo "Both Pis are now:"
echo "  - Debian 12 (Bookworm)"
echo "  - User: cuiv (SSH key access)"
echo "  - Clean system (old software removed)"
echo ""
echo "Next steps:"
echo "  1. Update ansible/inventory/hosts.yml to use cuiv user"
echo "  2. Test: ansible raspberry_pis -m ping"
echo "  3. Run: ansible-playbook playbooks/raspberry-pi-setup.yml"
echo ""
