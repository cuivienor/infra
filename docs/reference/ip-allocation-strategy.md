# IP Allocation Strategy

**Range**: 192.168.1.100 - 192.168.1.199 (100 IPs)  
**Purpose**: Static infrastructure IPs managed outside of DHCP

---

## Allocation Summary

| Range | Category | Count | Notes |
|-------|----------|-------|-------|
| .100-.104 | Physical Hosts | 5 | Proxmox, Raspberry Pis |
| .105-.109 | Proxmox & Virtualization | 5 | PVE tools, backup proxies |
| .110-.119 | Network, DNS & Security | 10 | DNS, proxy, firewall, auth |
| .120-.129 | Backup & Storage | 10 | Backup, file sharing, sync |
| .130-.149 | Media & *Arr Stack | 20 | Streaming, downloading, organizing |
| .150-.159 | Monitoring & Analytics | 10 | Metrics, logs, dashboards |
| .160-.169 | Databases & Dev Tools | 10 | DBs, Git, CI/CD |
| .170-.179 | IoT & Home Automation | 10 | Smart home, MQTT, sensors |
| .180-.189 | Personal & Productivity | 10 | Notes, recipes, finance |
| .190-.199 | Reserved | 10 | Future growth |

---

## Detailed Allocation

### .100-.104: Physical Hosts (5 IPs)

| IP | Hostname | Status | Description |
|----|----------|--------|-------------|
| .100 | homelab | ✅ Active | Proxmox hypervisor |
| .101 | pi3 | ✅ Active | Raspberry Pi 3B |
| .102 | pi4 | ✅ Active | Raspberry Pi 4B |
| .103 | - | Reserved | Future hardware |
| .104 | - | Reserved | Future hardware |

---

### .105-.109: Proxmox & Virtualization (5 IPs)

PVE management and virtualization tools.

| IP | Service | Status | Description |
|----|---------|--------|-------------|
| .105 | PBS | Planned | Proxmox Backup Server |
| .106 | - | Reserved | PVE tools |
| .107-.109 | - | Reserved | Future |

---

### .110-.119: Network, DNS & Security (10 IPs)

Core networking infrastructure.

| IP | Service | Container | Status | Description |
|----|---------|-----------|--------|-------------|
| .110 | AdGuard Home | TBD | Planned | DNS + ad blocking |
| .111 | Traefik | TBD | Planned | Reverse proxy |
| .112 | Authentik | TBD | Planned | SSO/Identity provider |
| .113 | Vaultwarden | TBD | Planned | Password manager |
| .114 | WireGuard | TBD | Planned | VPN server |
| .115-.119 | - | - | Reserved | Future (OPNsense, Crowdsec, etc.) |

---

### .120-.129: Backup & Storage (10 IPs)

Data protection and file services.

| IP | Service | Container | Status | Description |
|----|---------|-----------|--------|-------------|
| .120 | Restic/Backrest | CT300 | ✅ Active | Backup management |
| .121 | Samba | CT301 | ✅ Active | File sharing |
| .122 | Syncthing | TBD | Planned | File sync |
| .123 | Nextcloud | TBD | Planned | Cloud storage |
| .124 | MinIO | TBD | Planned | S3-compatible storage |
| .125-.129 | - | - | Reserved | Future |

---

### .130-.149: Media & *Arr Stack (20 IPs)

Media streaming, acquisition, and organization.

| IP | Service | Container | Status | Description |
|----|---------|-----------|--------|-------------|
| .130 | Jellyfin | CT305 | ✅ Active | Media streaming |
| .131 | Ripper | CT302 | ✅ Active | MakeMKV disc ripping |
| .132 | Transcoder | CT304 | ✅ Active | FFmpeg GPU encoding |
| .133 | Analyzer | CT303 | ✅ Active | FileBot + media tools |
| .134 | Sonarr | TBD | Planned | TV show management |
| .135 | Radarr | TBD | Planned | Movie management |
| .136 | Lidarr | TBD | Planned | Music management |
| .137 | Readarr | TBD | Planned | Book management |
| .138 | Prowlarr | TBD | Planned | Indexer manager |
| .139 | qBittorrent | TBD | Planned | Torrent client |
| .140 | SABnzbd | TBD | Planned | Usenet client |
| .141 | Bazarr | TBD | Planned | Subtitles |
| .142 | Overseerr | TBD | Planned | Request management |
| .143 | Tautulli | TBD | Planned | Media stats |
| .144 | Audiobookshelf | TBD | Planned | Audiobook server |
| .145 | Navidrome | TBD | Planned | Music streaming |
| .146 | Calibre-web | TBD | Planned | E-book server |
| .147-.149 | - | - | Reserved | Future media services |

---

### .150-.159: Monitoring & Analytics (10 IPs)

Observability and system monitoring.

| IP | Service | Status | Description |
|----|---------|--------|-------------|
| .150 | Grafana | Planned | Dashboards |
| .151 | Prometheus | Planned | Metrics collection |
| .152 | Loki | Planned | Log aggregation |
| .153 | Uptime Kuma | Planned | Service monitoring |
| .154 | Netdata | Planned | Real-time system stats |
| .155 | Homepage | Planned | Dashboard/start page |
| .156-.159 | - | Reserved | Future (Alertmanager, etc.) |

---

### .160-.169: Databases & Dev Tools (10 IPs)

Development infrastructure.

| IP | Service | Status | Description |
|----|---------|--------|-------------|
| .160 | PostgreSQL | Planned | Primary database |
| .161 | Redis | Planned | Cache/queue |
| .162 | Gitea | Planned | Self-hosted Git |
| .163 | Drone CI | Planned | CI/CD |
| .164 | Docker Registry | Planned | Container images |
| .165 | Code Server | Planned | VS Code in browser |
| .166 | n8n | Planned | Workflow automation |
| .167-.169 | - | Reserved | Future |

---

### .170-.179: IoT & Home Automation (10 IPs)

Smart home and automation.

| IP | Service | Status | Description |
|----|---------|--------|-------------|
| .170 | Home Assistant | Planned | Home automation hub |
| .171 | Zigbee2MQTT | Planned | Zigbee bridge |
| .172 | Node-RED | Planned | Flow-based automation |
| .173 | ESPHome | Planned | ESP device management |
| .174 | MQTT Broker | Planned | Mosquitto |
| .175-.179 | - | Reserved | Future |

---

### .180-.189: Personal & Productivity (10 IPs)

Self-hosted personal applications.

| IP | Service | Status | Description |
|----|---------|--------|-------------|
| .180 | Mealie | Planned | Recipe management |
| .181 | Paperless-ngx | Planned | Document management |
| .182 | Immich | Planned | Photo management |
| .183 | Wallabag | Planned | Read-it-later |
| .184 | Linkding | Planned | Bookmarks |
| .185 | Actual Budget | Planned | Personal finance |
| .186-.189 | - | Reserved | Future |

---

### .190-.199: Reserved (10 IPs)

Buffer for future growth and reorganization.

---

## Current Active Services

| IP | Service | Hostname | Type |
|----|---------|----------|------|
| .100 | Proxmox | homelab | Physical |
| .101 | Raspberry Pi 3 | pi3 | Physical |
| .102 | Raspberry Pi 4 | pi4 | Physical |
| .120 | Backup | backup | LXC (CT300) |
| .121 | Samba | samba | LXC (CT301) |
| .130 | Jellyfin | jellyfin | LXC (CT305) |
| .131 | Ripper | ripper | LXC (CT302) |
| .132 | Transcoder | transcoder | LXC (CT304) |
| .133 | Analyzer | analyzer | LXC (CT303) |

---

## Migration Plan

### Current → New IPs

| Service | CTID | Current IP | New IP | Category |
|---------|------|-----------|--------|----------|
| Backup | 300 | .58 | .120 | Backup & Storage |
| Samba | 301 | .82 | .121 | Backup & Storage |
| Ripper | 302 | .70 | .131 | Media Stack |
| Analyzer | 303 | .73 | .133 | Media Stack |
| Transcoder | 304 | .77 | .132 | Media Stack |
| Jellyfin | 305 | .85 | .130 | Media Stack |

---

## Design Principles

1. **Logical grouping** - Related services in same range
2. **Room for growth** - Each category has spare IPs
3. **Core services first** - Lower IPs for foundational services
4. **Media-heavy** - 20 IPs for *arr stack (your primary use case)
5. **Consistent naming** - Service name as hostname (not CTID)

---

**Last Updated**: 2025-11-15
