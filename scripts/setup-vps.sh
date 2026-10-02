#!/usr/bin/env bash
# ============================================================
# Oracle Cloud / Ubuntu VPS Initial Bootstrap Script
# Run this once on a fresh VPS instance to set up everything:
#   curl -sSL <raw_url_or_file> | bash
# ============================================================

set -euo pipefail

echo "============================================================"
echo " Starting Minecraft VPS Automated Bootstrap"
echo "============================================================"

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
APP_DIR="$USER_HOME/minecraft"

# 1. Update system packages
echo "[1/6] Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  jq \
  ufw \
  fail2ban \
  netfilter-persistent \
  iptables-persistent

# 2. Install official Docker CE and Compose plugin
echo "[2/6] Installing Docker CE and Docker Compose..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable docker group for non-root usage
sudo usermod -aG docker "$USER_NAME"

# 3. Configure Firewall & Network Rules
echo "[3/6] Configuring host firewall (iptables / ufw)..."
# Oracle Cloud Ubuntu instances use iptables by default
sudo iptables -I INPUT 6 -p udp --dport 19132 -m conntrack --ctstate NEW -j ACCEPT || true
sudo iptables -I INPUT 6 -p tcp --dport 25565 -m conntrack --ctstate NEW -j ACCEPT || true
sudo iptables -I INPUT 6 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT || true
sudo netfilter-persistent save

# 4. Prepare directories and permissions
echo "[4/6] Setting up project directory structure..."
mkdir -p "$APP_DIR/server-data" "$APP_DIR/backups" "$APP_DIR/scripts"
sudo chown -R "$USER_NAME:$USER_NAME" "$APP_DIR"

if [ -f "$APP_DIR/scripts/mc.sh" ]; then
  chmod +x "$APP_DIR/scripts/mc.sh" "$APP_DIR/scripts/backup.sh" || true
  sudo ln -sf "$APP_DIR/scripts/mc.sh" /usr/local/bin/mc
fi

# 5. Configure Automated Cron Jobs
echo "[5/6] Setting up automated backup and Oracle idle protection cron jobs..."
CRON_TMP=$(mktemp)
crontab -u "$USER_NAME" -l 2>/dev/null > "$CRON_TMP" || true

# Add daily backup job (at 04:00 AM UTC) if not present
if ! grep -q "backup.sh" "$CRON_TMP"; then
  echo "0 4 * * * $APP_DIR/scripts/backup.sh >> $APP_DIR/backups/backup.log 2>&1" >> "$CRON_TMP"
fi

# Add Oracle Always Free idle reclamation mitigation (runs light sha256 check every hour)
if ! grep -q "openssl speed" "$CRON_TMP"; then
  echo "15 * * * * openssl speed -elapsed -evp sha256 > /dev/null 2>&1" >> "$CRON_TMP"
fi

crontab -u "$USER_NAME" "$CRON_TMP"
rm -f "$CRON_TMP"

# 6. Summary
echo "============================================================"
echo " VPS Bootstrap Completed Successfully!"
echo "============================================================"
echo "Directory: $APP_DIR"
echo "Global CLI: 'mc' (e.g., mc start, mc logs, mc status)"
echo ""
echo "Next steps:"
echo " 1. Make sure you set your GitHub Secrets (VPS_HOST, VPS_USER, VPS_SSH_KEY)."
echo " 2. Push to 'main' branch or run 'mc start' on the server."
echo " 3. Verify Ingress Rules in Oracle Cloud Console (UDP 19132, TCP 25565)."
echo "============================================================"
