{ lib, ... }:

{
  programs.ssh = {
    enable = true;

    # Opt out of deprecated default config (will be removed in future HM)
    # We explicitly set the defaults we want in the "*" matchBlock
    enableDefaultConfig = lib.mkDefault false;

    matchBlocks = {
      # Global defaults (replaces deprecated built-in defaults)
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "/home/cuiv/.ssh/github-devbox";
        identitiesOnly = true;
      };

      # Proxmox host
      "homelab" = {
        hostname = "192.168.1.100";
        user = "cuiv";
      };

      # LXC Containers
      "backup" = {
        hostname = "192.168.1.120";
        user = "root";
      };
      "samba" = {
        hostname = "192.168.1.121";
        user = "root";
      };
      "ripper" = {
        hostname = "192.168.1.131";
        user = "root";
      };
      "analyzer" = {
        hostname = "192.168.1.133";
        user = "root";
      };
      "transcoder" = {
        hostname = "192.168.1.132";
        user = "root";
      };
      "jellyfin" = {
        hostname = "192.168.1.130";
        user = "root";
      };
      "dns" = {
        hostname = "192.168.1.110";
        user = "root";
      };
      "proxy" = {
        hostname = "192.168.1.111";
        user = "root";
      };
      "wishlist" = {
        hostname = "192.168.1.186";
        user = "root";
      };
      "authelia" = {
        hostname = "192.168.1.112";
        user = "root";
      };
      "cloudflared" = {
        hostname = "192.168.1.113";
        user = "root";
      };
      "lldap" = {
        hostname = "192.168.1.114";
        user = "root";
      };
      "mealie" = {
        hostname = "192.168.1.187";
        user = "root";
      };
      "vault" = {
        hostname = "192.168.1.150";
        user = "root";
      };
      "pipeline-test" = {
        hostname = "192.168.1.199";
        user = "root";
      };

      # NixOS dev container
      "devbox" = {
        hostname = "192.168.1.140";
        user = "cuiv";
      };

      # Raspberry Pis
      "pi3" = {
        hostname = "192.168.1.101";
        user = "cuiv";
      };
      "pi4" = {
        hostname = "192.168.1.102";
        user = "cuiv";
      };
    };
  };
}
