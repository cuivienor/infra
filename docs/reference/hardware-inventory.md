# Homelab Hardware Inventory

**Last Updated**: 2025-11-12  
**System**: homelab (192.168.1.56)  
**Purpose**: Complete hardware reference for planning future upgrades and expansions

---

## System Overview

| Component | Details |
|-----------|---------|
| **Motherboard** | ASRock Z370/OEM |
| **BIOS** | American Megatrends L0.01 (07/17/2019) |
| **Chassis** | Desktop Form Factor |
| **OS** | Proxmox VE 8.4.14 on Debian 12 (Bookworm) |
| **Kernel** | 6.8.12-10-pve |

---

## CPU

### Specifications

| Property | Value |
|----------|-------|
| **Model** | Intel Core i5-9600K |
| **Base Clock** | 3.70 GHz |
| **Max Turbo** | 4.60 GHz |
| **Current Speed** | ~4.35 GHz (turbo active) |
| **Architecture** | Coffee Lake (9th Gen) |
| **Socket** | LGA 1151 (300 Series) |
| **Cores** | 6 physical cores |
| **Threads** | 6 (no hyperthreading) |
| **TDP** | 95W |

### Cache

- **L1 Data**: 192 KiB (6x 32 KiB)
- **L1 Instruction**: 192 KiB (6x 32 KiB)
- **L2**: 1.5 MiB (6x 256 KiB)
- **L3**: 9 MiB (shared)

### Features

- **Virtualization**: VT-x (enabled)
- **Instruction Sets**: SSE4.1, SSE4.2, AVX, AVX2, AES-NI
- **Power Management**: Intel Turbo Boost, SpeedStep
- **Governor**: Performance mode (all cores)
- **Frequency Range**: 800 MHz - 4600 MHz

### Security Mitigations

✅ **Protected Against**:
- Meltdown: Not affected
- L1TF: Not affected
- MDS: Not affected
- Retbleed: Enhanced IBRS
- Spectre v1: Mitigations active
- Spectre v2: Enhanced IBRS

⚠️ **Vulnerable** (microcode needed):
- Gather data sampling
- MMIO stale data
- SRBDS
- TSX async abort

---

## Memory

### Configuration

| Slot | Module | Capacity | Type | Speed | Manufacturer | Part Number |
|------|--------|----------|------|-------|--------------|-------------|
| **A-DIMM0** | Empty | - | - | - | - | - |
| **A-DIMM1** | Installed | 16 GB | DDR4 | 2133 MT/s | Corsair (029E) | CMK32GX4M2A2666C16 |
| **B-DIMM0** | Empty | - | - | - | - | - |
| **B-DIMM1** | Installed | 16 GB | DDR4 | 2133 MT/s | Corsair (029E) | CMK32GX4M2A2666C16 |

### Summary

- **Total Installed**: 32 GB (2x 16GB modules)
- **Configuration**: Dual-channel
- **Available Slots**: 2 (A-DIMM0, B-DIMM0)
- **Max Capacity**: 64 GB (4x 16GB)
- **Speed**: DDR4-2133 (rated for 2666, running at 2133)
- **Current Usage**: ~2.8 GB used, ~28 GB available

### Upgrade Path

💡 Can add 2x 16GB modules to reach 64GB total (max supported by CPU)

---

## Storage Devices

### Boot/System Drive

#### Samsung 970 EVO Plus 2TB (NVMe)

| Property | Value |
|----------|-------|
| **Model** | Samsung SSD 970 EVO Plus 2TB |
| **Serial** | S6S2NS0T923900R |
| **Interface** | NVMe 1.3 (PCIe Gen3 x4) |
| **Capacity** | 2.0 TB (2,000 GB) |
| **Type** | SSD (NVMe M.2) |
| **Device** | `/dev/nvme0n1` |

**Partitions**:
- `/dev/nvme0n1p1`: 1MB (BIOS boot)
- `/dev/nvme0n1p2`: 1GB EFI System Partition (mounted `/boot/efi`)
- `/dev/nvme0n1p3`: 1.82TB LVM Physical Volume

**LVM Configuration** (`pve` volume group):
- `pve-swap`: 8 GB (swap)
- `pve-root`: 96 GB (Proxmox root filesystem, 9% used)
- `pve-data`: 1.67 TB thin pool (for LXC containers)
  - CT300: 20 GB (backup) - 6.63% used
  - CT301: 8 GB (samba) - 14.96% used
  - CT302: 8 GB (ripper) - 30.81% used
  - CT303: 12 GB (analyzer) - 50.53% used
  - CT304: 20 GB (transcoder) - 9.98% used
  - CT305: 32 GB (jellyfin) - 7.26% used
- **Free Space**: 16.24 GB

### Data Disks (MergerFS Pool)

#### Disk 1: WDC WD101EDBZ (10TB)

| Property | Value |
|----------|-------|
| **Model** | WDC WD101EDBZ-11B1DA0 |
| **Serial** | VCHLGZTP |
| **Capacity** | 10 TB (10,000 GB) |
| **RPM** | 7200 |
| **Form Factor** | 3.5" |
| **Interface** | SATA 3.2 (6.0 Gb/s) |
| **Device** | `/dev/sdc` → `/dev/sdc1` |
| **Mount** | `/mnt/disk1` |
| **Filesystem** | ext4 |
| **Usage** | 4.2 TB / 9.1 TB (49% used) |

#### Disk 2: Seagate BarraCuda (10TB)

| Property | Value |
|----------|-------|
| **Model** | ST10000DM0004-1ZC101 |
| **Serial** | ZA2DWAHC |
| **Capacity** | 10 TB (10,000 GB) |
| **RPM** | 7200 |
| **Form Factor** | 3.5" |
| **Interface** | SATA 3.1 (6.0 Gb/s) |
| **Device** | `/dev/sdd` → `/dev/sdd1` |
| **Mount** | `/mnt/disk2` |
| **Filesystem** | ext4 |
| **Usage** | 279 MB / 9.1 TB (1% used) |
| **Technology** | CMR (Conventional Magnetic Recording) |

#### Disk 3: WDC WD180EDGZ (18TB)

| Property | Value |
|----------|-------|
| **Model** | WDC WD180EDGZ-11B2DA0 |
| **Serial** | 3FKXJ3UV |
| **Capacity** | 18 TB (18,000 GB) |
| **RPM** | 7200 |
| **Form Factor** | 3.5" |
| **Interface** | SATA 3.3 (6.0 Gb/s) |
| **Device** | `/dev/sdb` → `/dev/sdb1` |
| **Mount** | `/mnt/disk3` |
| **Filesystem** | ext4 |
| **Usage** | 261 GB / 17 TB (2% used) |

#### Parity Disk: WDC WD180EDGZ (18TB)

| Property | Value |
|----------|-------|
| **Model** | WDC WD180EDGZ-11B2DA0 |
| **Serial** | 3FKJMTSV |
| **Capacity** | 18 TB (18,000 GB) |
| **RPM** | 7200 |
| **Form Factor** | 3.5" |
| **Interface** | SATA 3.3 (6.0 Gb/s) |
| **Device** | `/dev/sda` → `/dev/sda1` |
| **Mount** | `/mnt/parity` |
| **Filesystem** | ext4 |
| **Usage** | 3.8 TB / 17 TB (25% used) |
| **Purpose** | SnapRAID parity disk |

### MergerFS Pool

| Property | Value |
|----------|-------|
| **Mount Point** | `/mnt/storage` |
| **Total Capacity** | 35 TB |
| **Used** | 4.4 TB (14%) |
| **Available** | 29 TB |
| **Policy** | `eppfrd` (Existing Path, Percentage Free, Round-robin) |
| **Min Free Space** | 200 GB |
| **Component Disks** | disk1 (10TB), disk2 (10TB), disk3 (18TB) |

**Distribution**:
- Disk 1: 4.2 TB used (49%)
- Disk 2: 279 MB used (1%)
- Disk 3: 261 GB used (2%)

💡 **Note**: Data is unevenly distributed; disk2 and disk3 have room for rebalancing

---

## Graphics & Video

### Primary GPU: Intel Arc A380

| Property | Value |
|----------|-------|
| **Model** | Intel DG2 Arc A380 |
| **Manufacturer** | ASRock (AIB partner) |
| **PCIe Slot** | 07:00.0 (via PCIe switch at 05:00.0) |
| **Device** | `/dev/dri/card1`, `/dev/dri/renderD128` |
| **Driver** | i915 (kernel module) |
| **VA-API** | Intel iHD driver v23.1.1 |
| **Purpose** | Hardware transcoding (primary) |

**Capabilities**:
- AV1 encode/decode
- HEVC (H.265) encode/decode
- H.264 (AVC) encode/decode
- VP9 decode
- Hardware acceleration via VA-API 1.17

**Current Usage**:
- CT304 (transcoder): Hardware transcoding
- CT305 (jellyfin): Primary GPU for media server transcoding

**Audio Controller**: Intel DG2 Audio (08:00.0)

### Secondary GPU: NVIDIA GeForce GTX 1080

| Property | Value |
|----------|-------|
| **Model** | NVIDIA GP104 [GeForce GTX 1080] |
| **Manufacturer** | EVGA |
| **PCIe Slot** | 01:00.0 |
| **Device** | `/dev/dri/card0`, `/dev/dri/renderD129` |
| **Driver** | nouveau (open source) |
| **Purpose** | Display output, secondary GPU |

**Specifications**:
- CUDA Cores: 2560
- Memory: 8GB GDDR5X
- Memory Bus: 256-bit
- TDP: 180W

**Current Usage**:
- CT305 (jellyfin): Available for additional transcoding if needed
- Display output

**Audio Controller**: NVIDIA GP104 HD Audio (01:00.1)

### Integrated Graphics

**Intel UHD Graphics 630** (built into i5-9600K)
- Not currently in use (discrete GPUs handle all display/compute)
- Can be enabled if needed

---

## Optical Drive

### HL-DT-ST BD-RE WH16NS60

| Property | Value |
|----------|-------|
| **Model** | HL-DT-ST BD-RE WH16NS60 |
| **Serial** | KLHO5IG3827 |
| **Type** | Blu-ray Reader/Writer |
| **Speed** | 204x (CD equivalent) |
| **Interface** | SATA |
| **Block Device** | `/dev/sr0` (major 11, minor 0) |
| **SCSI Generic** | `/dev/sg4` (major 21, minor 4) |

**Capabilities**:
- ✅ Read: CD, DVD, Blu-ray, multisession, MCN
- ✅ Write: CD-R, CD-RW, DVD-R, DVD-RAM, MRW, RAM
- ✅ Tray: Open, close, lock
- ✅ Audio: Play audio CDs

**Current Usage**:
- CT302 (ripper): MakeMKV Blu-ray ripping
- Device passthrough via LXC cgroup rules

---

## Network

### Primary Network Interface

| Property | Value |
|----------|-------|
| **Chip** | Intel I219-V |
| **Interface** | `eno1` (enp0s31f6) |
| **MAC Address** | 70:85:c2:a5:c3:c4 |
| **Speed** | 1000 Mb/s (Gigabit) |
| **Duplex** | Full |
| **State** | UP |
| **Driver** | e1000e |

**Bridge Configuration**:
- Bridge: `vmbr0` (Linux bridge)
- IP: 192.168.1.56/24
- Gateway: 192.168.1.1
- Method: Static

**Container veth Interfaces**:
- veth300i0: CT300 (backup)
- veth301i0: CT301 (samba)
- veth302i0: CT302 (ripper)
- veth303i0: CT303 (analyzer)
- veth304i0: CT304 (transcoder)
- veth305i0: CT305 (jellyfin)

### Wireless Network Interface

| Property | Value |
|----------|-------|
| **Chip** | Intel Dual Band Wireless-AC 3168NGW |
| **Interface** | `wlp4s0` |
| **MAC Address** | 3c:6a:a7:a0:f1:68 |
| **PCIe** | 04:00.0 |
| **State** | DOWN (not in use) |
| **Driver** | iwlwifi |

**Bluetooth**: Intel Wireless-AC 3168 Bluetooth (USB)

💡 **Note**: Wireless not currently used; wired connection only

---

## USB Devices

### Connected Devices

| Device | Product | Usage |
|--------|---------|-------|
| **Hub** | USB 2.0 root hub (16 ports) | Primary hub |
| **Hub** | USB 3.0 root hub (10 ports) | High-speed hub |
| **Keyboard** | Shenzhen Riitek wireless mini keyboard | Input device |
| **Card Reader** | Alcor Micro AU6477 | SD/CF/MMC reader |
| **Serial 1** | Silicon Labs CP210x UART Bridge | Unknown |
| **Serial 2** | Silicon Labs CP210x UART Bridge | Unknown |
| **Bluetooth** | Intel Wireless-AC 3168 BT | Bluetooth adapter |

### Card Reader Devices

Alcor Micro card reader presents 4 virtual devices (all empty):
- `/dev/sde`: SD/MMC slot
- `/dev/sdf`: Compact Flash slot
- `/dev/sdg`: SM/xD-Picture slot
- `/dev/sdh`: MS/MS-Pro slot

---

## PCIe Topology

### Slot Utilization

| Slot | Device | Link Speed | Usage |
|------|--------|------------|-------|
| **00:01.0** | PCIe Root Port (x16) | PCIe 3.0 | GPU 1 (NVIDIA GTX 1080) |
| **00:1b.0** | PCIe Root Port #17 | PCIe 3.0 | NVMe SSD (Samsung 970 EVO) |
| **00:1c.0** | PCIe Root Port #1 | - | Unused |
| **00:1c.2** | PCIe Root Port #3 | - | Wireless AC 3168 |
| **00:1c.4** | PCIe Root Port #5 | PCIe 3.0 | GPU 2 via PCIe switch |
| **00:1d.0** | PCIe Root Port #9 | - | Unused |

### PCIe Switch (Intel 4FA1)

Connected to slot 00:1c.4:
- **05:00.0**: PCIe switch upstream
  - **06:01.0**: Downstream port (unused)
  - **06:04.0**: Downstream port → **Intel Arc A380** (07:00.0)

### Chipset Details

**Chipset**: Intel Z370 (200 Series)
- LPC/eSPI Controller
- SATA Controller (AHCI mode, 6 ports)
- USB 3.0 xHCI Controller
- SMBus Controller
- Thermal Subsystem
- Management Engine

---

## Expansion Capacity

### Available Slots

Based on ASRock Z370/OEM motherboard (typical configuration):

| Slot Type | Total | Used | Available |
|-----------|-------|------|-----------|
| **PCIe x16** (GPU) | 2-3 | 2 | 0-1 |
| **PCIe x1** | 2-3 | 0 | 2-3 |
| **M.2 NVMe** | 1-2 | 1 | 0-1 |
| **RAM DIMM** | 4 | 2 | 2 |
| **SATA** | 6 | 4 | 2 |

### Potential Upgrades

**Memory**: 
- Add 2x 16GB DDR4 modules → 64GB total
- Cost: ~$60-80 per 16GB module

**Storage**:
- 2 available SATA ports for additional HDDs/SSDs
- Possible M.2 slot for additional NVMe SSD (check motherboard)
- Can expand MergerFS pool with larger disks

**PCIe**:
- Available PCIe x1 slots for:
  - Additional NICs (10GbE)
  - HBA/RAID controllers
  - USB expansion cards
  - Capture cards

**GPU**:
- Arc A380 is entry-level; could upgrade to A750/A770 for more transcoding power
- GTX 1080 could be replaced with newer GPU if needed

---

## Power & Thermal

### TDP Budget

| Component | TDP/Power Draw |
|-----------|----------------|
| **CPU** | 95W (i5-9600K) |
| **GPU 1** | ~75W (Arc A380) |
| **GPU 2** | 180W (GTX 1080) |
| **Motherboard** | ~30W |
| **RAM** | ~10W (32GB) |
| **NVMe SSD** | ~8W |
| **HDDs** | ~40W (4x 10W) |
| **Fans/Misc** | ~20W |
| **Total** | ~458W peak |

💡 **PSU Recommendation**: 550-650W 80+ Bronze or better

### Cooling Requirements

- CPU: Stock or aftermarket cooler (95W TDP)
- GPUs: Factory coolers
- Case: Adequate airflow for 4x HDDs + 2x GPUs
- Monitor HDD temperatures (should stay <45°C)

---

## Firmware Versions

| Component | Version | Date |
|-----------|---------|------|
| **BIOS** | American Megatrends L0.01 | 2019-07-17 |
| **BIOS Revision** | 5.12 | - |
| **Proxmox** | 8.4.14 | - |
| **Kernel** | 6.8.12-10-pve | - |

💡 **Note**: BIOS is from 2019; check ASRock for updates (especially for microcode security fixes)

---

## Planning Notes

### Upgrade Priority

1. **BIOS Update** - Address CPU security vulnerabilities
2. **Memory** - Add 2x 16GB to reach 64GB (if needed for more VMs)
3. **Storage** - Replace oldest/smallest disks with larger ones
4. **Network** - Consider 10GbE NIC if local network supports it
5. **GPU** - Upgrade Arc A380 to A750 if transcoding becomes bottleneck

### Bottlenecks

Current limitations:
- **CPU**: 6 cores may limit VM/container count under heavy load
- **Network**: 1GbE limits large file transfers
- **Memory**: 32GB adequate for current 6 containers, may need more for expansion
- **Arc A380**: Entry-level, fine for 1-2 concurrent transcodes

### Future Expansion Ideas

- **10GbE Network**: Upgrade to PCIe 10GbE card (~$150)
- **HBA Card**: Add LSI SAS HBA for more storage expansion
- **Backup Power**: UPS for clean shutdowns during power loss
- **Monitoring**: Temperature sensors, power monitoring
- **Second Host**: Build/acquire second server for HA/backup

---

**Document Version**: 1.0  
**Generated**: 2025-11-12  
**Method**: Live system inspection via SSH + dmidecode/lscpu/smartctl
