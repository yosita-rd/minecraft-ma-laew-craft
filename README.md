# 🎮 Ma-Laew-Craft: Minecraft Bedrock & Java Hybrid Server

[![Deploy Minecraft Server](https://github.com/yosita-rd/minecraft-ma-laew-craft/actions/workflows/deploy.yml/badge.svg)](https://github.com/yosita-rd/minecraft-ma-laew-craft/actions/workflows/deploy.yml)

A production-grade, 24/7 Minecraft hybrid server powered by **PaperMC**, **GeyserMC**, and **Floodgate**, designed to run permanently on **Oracle Cloud Always Free ARM64 (Ampere A1)** with zero hosting cost.

Includes complete **Local-to-Cloud Git workflow**, **GitHub Actions CI/CD pipeline**, automated **zero-downtime backups**, and an **interactive server management CLI (`mc`)**.

---

## 📑 Table of Contents

- [Architecture & Compatibility](#-architecture--compatibility)
- [Repository Structure](#-repository-structure)
- [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
  - [1. Create Oracle Cloud VPS (Always Free)](#1-create-oracle-cloud-vps-always-free)
  - [2. Open Firewall Ports in Oracle Cloud](#2-open-firewall-ports-in-oracle-cloud)
  - [3. Bootstrap VPS (1-Command Setup)](#3-bootstrap-vps-1-command-setup)
  - [4. Configure GitHub Actions CI/CD](#4-configure-github-actions-cicd)
- [Connecting from iPad / iOS & PC](#-connecting-from-ipad--ios--pc)
- [Server Administration (`mc` CLI)](#-server-administration-mc-cli)
- [Backup & World Recovery](#-backup--world-recovery)
- [Troubleshooting & FAQ](#-troubleshooting--faq)

---

## 🏗 Architecture & Compatibility

```mermaid
flowchart TD
    subgraph Clients["Clients"]
        Bedrock["📱 iPad / iOS / Android / Win10 Bedrock<br>(UDP 19132)"]
        Java["💻 PC Java Edition Client<br>(TCP 25565)"]
    end

    subgraph VPS["Oracle Cloud Always Free (ARM64 Ubuntu 24.04)"]
        subgraph Container["Docker: itzg/minecraft-server"]
            Paper["PaperMC 1.21.x (Native ARM64 OpenJDK 21)"]
            Geyser["GeyserMC Plugin (Bedrock Protocol Translator)"]
            Floodgate["Floodgate Plugin (Xbox Live Authentication)"]
            Plugins["ViaVersion + Chunky + Spark"]
        end
        WorldData[("/server-data Persistent Storage")]
        BackupStorage[("/backups Rolling 7-Day Backups")]
    end

    Bedrock -->|UDP:19132| Geyser
    Java -->|TCP:25565| Paper
    Geyser <--> Floodgate
    Paper <--> WorldData
    WorldData -.->|Daily Cron 04:00 UTC| BackupStorage
```

### Why PaperMC + Geyser on ARM64?
- **Native ARM64 Performance**: Mojang's official Bedrock Dedicated Server (`bedrock_server`) binary is compiled only for `x86_64`. Running it on ARM64 requires `box64` emulation, which suffers from severe TLS/handshake bugs on iOS clients (`InitialConnection-13`).
- **PaperMC + Geyser** runs natively on Java 21 (`aarch64`) with 0% emulation overhead, rock-solid stability, full access to 12–24 GB of RAM on Oracle Free Tier, and cross-play compatibility for both Bedrock and Java clients.

---

## 📁 Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── deploy.yml         # Auto-deploy to VPS on 'git push' to main
│       └── backup.yml         # Manual trigger for world backup & status
├── scripts/
│   ├── setup-vps.sh          # 1-command bootstrap script for fresh VPS
│   ├── mc.sh                 # Management CLI (start, stop, logs, cmd, status)
│   └── backup.sh             # Safe RCON save-flush & 7-day rolling backup
├── docker-compose.yml        # Multi-platform container configuration
├── .env.example              # Template for server environment variables
├── .gitignore                # Protects secrets & world data from git
└── README.md                 # Complete documentation
```

---

## 🚀 Step-by-Step Setup Guide

### 1. Create Oracle Cloud VPS (Always Free)

1. Sign up for [Oracle Cloud Infrastructure (OCI) Free Tier](https://cloud.oracle.com/).
2. In the OCI Console, navigate to **Compute** → **Instances** → **Create Instance**.
3. Configure the instance:
   - **Name**: `mc-server`
   - **Image**: `Ubuntu 24.04 LTS (aarch64)`
   - **Shape**: `Ampere` → `VM.Standard.A1.Flex`
   - **OCPUs**: `2` (can scale up to 4)
   - **Memory**: `12 GB` (can scale up to 24 GB)
   - **Networking**: Assign a **Public IPv4 address**
   - **SSH Keys**: Download or paste your public SSH key (`id_ed25519.pub` or `id_rsa.pub`)
   - **Boot Volume**: `50 GB` (within the 200 GB Always Free limit)
4. Click **Create** and wait until the status shows **Running**. Copy your **Public IP**.

---

### 2. Open Firewall Ports in Oracle Cloud

Minecraft Bedrock uses **UDP 19132**; Java uses **TCP 25565**.

1. In OCI Console: **Networking** → **Virtual Cloud Networks** → Click your VCN.
2. Click **Public Subnet** → Click **Default Security List for...**.
3. Under **Ingress Rules**, click **Add Ingress Rules**:
   - **Bedrock Rule**:
     - Source CIDR: `0.0.0.0/0`
     - IP Protocol: `UDP`
     - Destination Port: `19132`
     - Description: `Minecraft Bedrock UDP`
   - **Java Rule (Optional)**:
     - Source CIDR: `0.0.0.0/0`
     - IP Protocol: `TCP`
     - Destination Port: `25565`
     - Description: `Minecraft Java TCP`
4. Click **Add Ingress Rules**.

---

### 3. Bootstrap VPS (1-Command Setup)

Connect to your VPS from your terminal:

```bash
ssh ubuntu@<YOUR_VPS_PUBLIC_IP>
```

Run the bootstrap script to automatically install Docker, open host firewalls, link the `mc` CLI, and configure automated cron jobs:

```bash
curl -fsSL https://raw.githubusercontent.com/yosita-rd/minecraft-ma-laew-craft/main/scripts/setup-vps.sh | bash
```

---

### 4. Configure GitHub Actions CI/CD

To enable automatic deployment whenever you `git push` from your PC:

1. Open your GitHub repository: [`yosita-rd/minecraft-ma-laew-craft`](https://github.com/yosita-rd/minecraft-ma-laew-craft)
2. Go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
3. Add the following secrets:

| Secret Name | Description | Example Value |
| --- | --- | --- |
| `VPS_HOST` | Your Oracle Cloud VPS Public IP | `129.150.x.x` |
| `VPS_USER` | SSH Username | `ubuntu` |
| `VPS_SSH_KEY` | Private SSH key (matching your public key on VPS) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `VPS_SSH_PORT` | SSH Port (optional, defaults to 22) | `22` |
| `RCON_PASSWORD` | Strong password for server console commands | `MySecretPass123!` |

Once secrets are set, any push to `main` will automatically deploy changes and ensure the server is running.

---

## 📱 Connecting from iPad / iOS & PC

### On iPad / iPhone / Android (Bedrock Edition):
1. Open **Minecraft** and ensure you are logged into your Microsoft / Xbox account.
2. Tap **Play** → **Servers** tab.
3. Scroll to the bottom and tap **Add Server**.
4. Fill in:
   - **Server Name**: `Ma-Laew-Craft`
   - **Server Address**: `<YOUR_VPS_PUBLIC_IP>`
   - **Port**: `19132` (Default Bedrock UDP port)
5. Tap **Save** and tap to join!

### On PC (Java Edition):
1. Open **Minecraft: Java Edition**.
2. Click **Multiplayer** → **Add Server**.
3. Server Address: `<YOUR_VPS_PUBLIC_IP>:25565`.

---

## 🛠 Server Administration (`mc` CLI)

Once logged into your VPS via SSH, use the `mc` command:

| Command | Action |
| --- | --- |
| `mc start` | Start the Minecraft server container |
| `mc stop` | Stop the server container gracefully |
| `mc restart` | Restart the server container |
| `mc logs` | Follow live server console logs (`Ctrl+C` to exit) |
| `mc cmd <command>` | Execute in-game console commands via RCON |
| `mc cmd op <Player>` | Grant Operator (Admin) privileges to a player |
| `mc cmd whitelist add <Player>` | Add a player to the whitelist |
| `mc status` | View CPU / RAM usage and online players |
| `mc backup` | Run an immediate world backup |
| `mc restore <file>` | Safely restore world from a backup `.tar.gz` |
| `mc update` | Pull latest Docker image and restart |

---

## 💾 Backup & World Recovery

### Automated Backups
- The server runs an automated daily backup at **04:00 AM UTC**.
- Backups use RCON chunk flushing (`save-off` -> `save-all flush` -> `save-on`) for zero world corruption.
- Archives are saved in `~/minecraft/backups/world_YYYYMMDD_HHMMSS.tar.gz`.
- Backups older than **7 days** are purged automatically.

### Manual Backup
- Via SSH: `mc backup`
- Via GitHub Actions: Go to **Actions** → **Trigger Server Backup & Status** → **Run workflow**.

### Restoring a Backup
```bash
# Example:
mc restore ~/minecraft/backups/world_20261002_040000.tar.gz
```

---

## ⚙️ Oracle Idle Reclamation Protection

Oracle Cloud Always Free instances may be reclaimed if CPU utilization remains below 20% for 7 consecutive days. 

The `setup-vps.sh` script automatically installs an hourly cron job (`15 * * * * openssl speed...`) that generates a 10-second harmless cryptographic benchmark, keeping the instance active without affecting server performance.

---

## 📄 License & Credits

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [GeyserMC](https://geysermc.org/) & [Floodgate](https://github.com/GeyserMC/Floodgate)
- [PaperMC](https://papermc.io/)