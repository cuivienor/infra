# home/profiles/vault-sync/default.nix
# LiveSync Bridge for syncing ~/vault/ with CouchDB
#
# Secrets managed via sops-nix (NixOS level):
# - /run/secrets/vault-couchdb-password
# - /run/secrets/vault-e2e-passphrase
{
  config,
  pkgs,
  lib,
  ...
}:

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

  # Activation script to set up livesync-bridge and generate config from secrets
  home.activation.setupLiveSyncBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    BRIDGE_DIR="${config.home.homeDirectory}/.local/share/livesync-bridge"
    CONFIG_FILE="$BRIDGE_DIR/dat/config.json"
    PASSWORD_FILE="/run/secrets/vault-couchdb-password"
    PASSPHRASE_FILE="/run/secrets/vault-e2e-passphrase"

    # Clone livesync-bridge if not present
    if [ ! -d "$BRIDGE_DIR" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone --recursive https://github.com/vrtmrz/livesync-bridge "$BRIDGE_DIR" || true
      # Install deno dependencies after fresh clone
      if [ -d "$BRIDGE_DIR" ]; then
        (cd "$BRIDGE_DIR" && $DRY_RUN_CMD ${pkgs.deno}/bin/deno install --allow-import 2>/dev/null || true)
      fi
    fi

    # Create dat directory for bridge
    $DRY_RUN_CMD mkdir -p "$BRIDGE_DIR/dat"

    # Generate config from sops secrets if they exist
    if [ -f "$PASSWORD_FILE" ] && [ -f "$PASSPHRASE_FILE" ]; then
      PASSWORD=$(cat "$PASSWORD_FILE")
      PASSPHRASE=$(cat "$PASSPHRASE_FILE")

      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n \
        --arg password "$PASSWORD" \
        --arg passphrase "$PASSPHRASE" \
        --arg vault_dir "${config.home.homeDirectory}/vault" \
        '{
          peers: [
            {
              type: "couchdb",
              name: "remote",
              database: "family-vault",
              username: "peter",
              password: $password,
              url: "https://vault.paniland.com",
              passphrase: $passphrase,
              obfuscatePassphrase: "",
              baseDir: "",
              customChunkSize: 0,
              minimumChunkSize: 20
            },
            {
              type: "storage",
              name: "local",
              baseDir: $vault_dir,
              scanOfflineChanges: true,
              useChokidar: true
            }
          ]
        }' > "$CONFIG_FILE"

      echo "LiveSync Bridge config generated from sops secrets"
    else
      echo ""
      echo "=== LiveSync Bridge: Waiting for sops secrets ==="
      echo "Secrets not found at:"
      echo "  - $PASSWORD_FILE"
      echo "  - $PASSPHRASE_FILE"
      echo ""
      echo "Add to secrets/devbox.yaml via: sops secrets/devbox.yaml"
      echo "  vault-couchdb-password: <peter's CouchDB password>"
      echo "  vault-e2e-passphrase: <shared E2E passphrase>"
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
