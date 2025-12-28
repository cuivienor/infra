# LXC Templates downloaded from GitHub Releases
# These are built by GitHub Actions and stored as release assets

resource "proxmox_virtual_environment_download_file" "nixos_devbox_bootstrap" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "homelab"

  # Public release URL - built by .github/workflows/build-lxc-templates.yml
  url       = "https://github.com/cuivienor/infra/releases/download/lxc-templates-latest/nixos-devbox-bootstrap.tar.xz"
  file_name = "nixos-devbox-bootstrap.tar.xz"

  # Re-download when content changes
  overwrite = true
}
