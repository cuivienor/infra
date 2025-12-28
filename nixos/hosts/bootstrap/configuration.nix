{ modulesPath, pkgs, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  # Container basics
  boot.isContainer = true;
  system.stateVersion = "24.11";

  # Static networking (matches devbox)
  networking = {
    hostName = "devbox";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.1.140";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";
    nameservers = [
      "192.168.1.102"
      "192.168.1.110"
      "1.1.1.1"
    ];
  };

  # SSH - the critical part
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Users with SSH keys
  users.users = {
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
    ];
    cuiv = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  # Minimal packages for comfortable recovery
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    ripgrep
    fd
    tree
    jq
  ];

  # Nix with flakes
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
}
