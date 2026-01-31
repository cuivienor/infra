# home/profiles/vault-sync/default.nix
# LiveSync Bridge for syncing ~/vault/ with CouchDB
#
# Prerequisites:
# 1. Clone livesync-bridge: git clone --recursive https://github.com/vrtmrz/livesync-bridge ~/.local/share/livesync-bridge
# 2. Edit ~/.config/livesync-bridge/config.json to add your passphrase
# 3. Enable and start: systemctl --user enable --now livesync-bridge
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # LiveSync Bridge configuration
  bridgeConfig = {
    peers = [
      {
        type = "couchdb";
        name = "remote";
        database = "family-vault";
        username = "peter";
        password = "PASTE_PASSWORD_HERE";
        url = "https://vault.paniland.com";
        passphrase = "CHOOSE_E2E_PASSPHRASE";
        obfuscatePassphrase = "";
        baseDir = "";
        customChunkSize = 0;
        minimumChunkSize = 20;
      }
      {
        type = "storage";
        name = "local";
        baseDir = "${config.home.homeDirectory}/vault";
        scanOfflineChanges = true;
        useChokidar = true; # Required for Linux
      }
    ];
  };

  configJson = pkgs.writeText "livesync-bridge-config.json" (builtins.toJSON bridgeConfig);
in
{
  # Create vault directory structure
  home.file = {
    "vault/.gitkeep".text = "";
    "vault/peter/.gitkeep".text = "";
    "vault/ani/.gitkeep".text = "";
    "vault/shared/.gitkeep".text = "";
    "vault/shared/household/.gitkeep".text = "";
    "vault/shared/travel/.gitkeep".text = "";
  };

  # Create initial config (user must edit to add passphrase)
  xdg.configFile."livesync-bridge/config.sample.json" = {
    source = configJson;
  };

  # Activation script to set up livesync-bridge
  home.activation.setupLiveSyncBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    BRIDGE_DIR="${config.home.homeDirectory}/.local/share/livesync-bridge"
    CONFIG_DIR="${config.xdg.configHome}/livesync-bridge"

    # Clone livesync-bridge if not present
    if [ ! -d "$BRIDGE_DIR" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone --recursive https://github.com/vrtmrz/livesync-bridge "$BRIDGE_DIR" || true
    fi

    # Create config directory
    $DRY_RUN_CMD mkdir -p "$CONFIG_DIR"

    # Create dat directory for bridge (it expects config in dat/)
    $DRY_RUN_CMD mkdir -p "$BRIDGE_DIR/dat"

    # Show setup instructions if config doesn't exist
    if [ ! -f "$BRIDGE_DIR/dat/config.json" ]; then
      echo ""
      echo "=== LiveSync Bridge Setup Required ==="
      echo "1. Edit $CONFIG_DIR/config.sample.json"
      echo "   - Set password to your CouchDB password"
      echo "   - Choose an E2E passphrase (IMPORTANT: share with Ani)"
      echo "2. Copy to: $BRIDGE_DIR/dat/config.json"
      echo "3. Enable service: systemctl --user enable --now livesync-bridge"
      echo ""
    fi
  '';

  # Systemd user service for livesync-bridge
  systemd.user.services.livesync-bridge = {
    Unit = {
      Description = "LiveSync Bridge - Sync vault with CouchDB";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "${config.home.homeDirectory}/.local/share/livesync-bridge";
      ExecStart = "${pkgs.deno}/bin/deno task run";
      Restart = "on-failure";
      RestartSec = "10s";

      # Environment
      Environment = [
        "DENO_DIR=${config.home.homeDirectory}/.cache/deno"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
