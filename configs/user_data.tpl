#!/bin/bash

# Install dependencies
yum install -y wget jq sqlite

# Install helper script for user creation via SSM (must be early, before anything can fail)
cat > /usr/local/bin/create-headscale-user.sh << 'HELPEREOF'
#!/bin/bash
set -e

USERNAME="$1"
if [ -z "$USERNAME" ]; then
  echo "ERROR: Username required" >&2
  exit 1
fi

# Wait for headscale service to be fully ready
for i in $(seq 1 30); do
  if sudo headscale users list > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Create user (ignore error if already exists)
sudo headscale users create "$USERNAME" 2>/dev/null || true

# Create preauth key
sudo headscale preauthkeys create --user "$USERNAME" --reusable --expiration 365d > /dev/null 2>&1 || true

# Read key from SQLite (reliable, avoids CLI output bugs)
KEY=$(sudo sqlite3 /var/lib/headscale/db.sqlite "SELECT key FROM pre_auth_keys WHERE user_id = (SELECT id FROM users WHERE name = '$USERNAME') ORDER BY created_at DESC LIMIT 1")

if [ -z "$KEY" ]; then
  echo "ERROR: No key found for $USERNAME" >&2
  exit 1
fi

echo "$KEY"
HELPEREOF
chmod +x /usr/local/bin/create-headscale-user.sh

# Download headscale binary
wget -O /usr/local/bin/headscale \
  "https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_linux_amd64"
chmod +x /usr/local/bin/headscale

# Create headscale user and directories
useradd --system --no-create-home --shell /usr/sbin/nologin headscale || true
mkdir -p /etc/headscale /var/lib/headscale /var/run/headscale
chown headscale:headscale /var/lib/headscale /var/run/headscale

# Write config
cat > /etc/headscale/config.yaml << 'CONFIGEOF'
${HEADSCALE_CONFIG}
CONFIGEOF

# Write ACL policy
cat > /etc/headscale/acl.json << 'ACLEOF'
${ACL_POLICY}
ACLEOF
chown headscale:headscale /etc/headscale/acl.json

# Create systemd service
cat > /etc/systemd/system/headscale.service << 'SERVICEEOF'
[Unit]
Description=headscale
After=network.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=/usr/local/bin/headscale serve
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Start headscale
systemctl daemon-reload
systemctl enable headscale
systemctl start headscale

# Wait for headscale
for i in $(seq 1 30); do
  headscale version 2>/dev/null && break
  sleep 5
done

# Enable IP forwarding (for subnet routing)
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Create subnet-router user, get key, connect as subnet router
headscale users create subnet-router
AUTH_KEY=$(headscale preauthkeys create --user subnet-router --reusable --expiration 87600h)
tailscale up --login-server=http://127.0.0.1:8080 --authkey="$AUTH_KEY" --advertise-routes=${VPC_CIDR} --accept-dns=false

# Approve routes
sleep 5
headscale routes list -o json | jq -r '.[].id' | while read ROUTE_ID; do
  headscale routes enable -r "$ROUTE_ID"
done
