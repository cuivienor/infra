#!/bin/bash
# configure-makemkv.sh - Configure MakeMKV for media user
#
# Run this on CT 200 as the media user

set -e

echo "=========================================="
echo "MakeMKV Configuration"
echo "=========================================="
echo ""

# Create config directory if it doesn't exist
mkdir -p ~/.MakeMKV

CONFIG_FILE="$HOME/.MakeMKV/settings.conf"

echo "Current configuration:"
if [ -f "$CONFIG_FILE" ]; then
    echo "  Config file exists at: $CONFIG_FILE"
    echo ""
    cat "$CONFIG_FILE"
    echo ""
else
    echo "  No config file found, will create new one"
    echo ""
fi

echo "=========================================="
echo "Enter your MakeMKV license key"
echo "=========================================="
echo "You can find your key at: https://www.makemkv.com/forum/"
echo "(or use the beta key if still in trial)"
echo ""
read -p "License key: " LICENSE_KEY

if [ -z "$LICENSE_KEY" ]; then
    echo "Error: License key cannot be empty"
    exit 1
fi

echo ""
echo "Creating MakeMKV configuration..."

# Create or overwrite settings.conf
cat > "$CONFIG_FILE" << EOF
# MakeMKV Settings Configuration
# Generated: $(date)

# License key
app_Key="$LICENSE_KEY"

# Output filename template
# {t} = title name from disc
app_DefaultOutputFileName="{t}"

# Selection string (select all tracks)
app_DefaultSelectionString="+sel:all"

# Disable automatic updates
app_UpdateEnable="0"

# Language
app_InterfaceLanguage="eng"
EOF

echo "✓ Configuration written to: $CONFIG_FILE"
echo ""

# Set proper permissions
chmod 600 "$CONFIG_FILE"

echo "Configuration contents:"
echo "=========================================="
cat "$CONFIG_FILE"
echo "=========================================="
echo ""

# Test MakeMKV
echo "Testing MakeMKV..."
echo ""

if makemkvcon info disc:0 2>&1 | grep -q "Error"; then
    echo "⚠ No disc in drive or error reading disc"
    echo "   (This is normal if no disc is inserted)"
else
    echo "✓ MakeMKV is working!"
fi

echo ""
echo "=========================================="
echo "✓ Configuration Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Insert a disc"
echo "  2. Run: ~/scripts/rip-disc.sh show \"Show Name\" \"S01 Disc1\""
echo "  3. Files should be named correctly without !ERRtemplate"
echo ""
