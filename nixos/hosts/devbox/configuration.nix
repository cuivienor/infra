{ config, pkgs, ... }:

{
  # LXC container settings
  boot.isContainer = true;

  # Networking
  networking = {
    hostName = "devbox";
    useDHCP = false;
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "192.168.1.140";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = "192.168.1.1";
    nameservers = [
      "192.168.1.102"
      "192.168.1.110"
      "1.1.1.1"
    ];
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  programs.zsh.enable = true;

  # Users
  users.users = {
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
    ];

    cuiv = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
      ];
    };
  };

  # Allow passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = false;

  # Basic packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    ripgrep
    fd
    tree
    jq
  ];

  # Enable nix command and flakes
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "cuiv"
    ];
  };

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Timezone
  time.timeZone = "UTC";

  # System state version - do not change
  system.stateVersion = "24.11";
}
