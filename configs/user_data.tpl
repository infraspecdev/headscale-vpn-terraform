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

# Get user ID (0.27+ requires numeric ID for preauthkeys)
USER_ID=$(sudo headscale users list -o json | jq -r ".[] | select(.name == \"$USERNAME\") | .id")

# Create preauth key using user ID
sudo headscale preauthkeys create --user "$USER_ID" --reusable --expiration 365d > /dev/null 2>&1 || true

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

# Write ACL policy file (loaded into database after headscale starts)
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

# Wait for headscale to be fully ready
for i in $(seq 1 30); do
  if headscale users list > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Load ACL policy into database
headscale policy set -f /etc/headscale/acl.json 2>/dev/null || true

# Enable IP forwarding (for subnet routing)
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Create subnet-router user, get key, connect as subnet router
headscale users create subnet-router
SUBNET_USER_ID=$(headscale users list -o json | jq -r '.[] | select(.name == "subnet-router") | .id')
AUTH_KEY=$(headscale preauthkeys create --user "$SUBNET_USER_ID" --reusable --expiration 87600h)
tailscale up --login-server=http://127.0.0.1:8080 --authkey="$AUTH_KEY" --advertise-routes=${VPC_CIDR} --accept-dns=false --timeout=30s || true

# Approve routes (list all route IDs, then enable each)
sleep 5
headscale routes list -o json | jq -r '.[].id' | while read ROUTE_ID; do
  headscale routes enable -r "$ROUTE_ID"
done

# --- Headplane Web UI ---
if [ "${ENABLE_HEADPLANE}" = "true" ]; then

  # Install Docker
  yum install -y docker
  systemctl enable docker
  systemctl start docker

  # Generate a Headscale API key for Headplane login
  HEADPLANE_API_KEY=$(headscale apikeys create --expiration 90d)

  # Store API key in SSM for retrieval
  INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  aws ssm put-parameter \
    --name "/headscale/headplane/apikey" \
    --value "$HEADPLANE_API_KEY" \
    --type SecureString \
    --overwrite \
    --region "$INSTANCE_REGION" 2>/dev/null || true

  # Write Headplane config
  mkdir -p /etc/headplane
  cat > /etc/headplane/config.yaml << 'HEADPLANEEOF'
${HEADPLANE_CONFIG}
HEADPLANEEOF

  # Inject the runtime-generated API key into the Headplane config
  sed -i "s|__HEADPLANE_API_KEY__|$HEADPLANE_API_KEY|g" /etc/headplane/config.yaml

  # Run Headplane container
  docker run -d \
    --name headplane \
    --restart unless-stopped \
    --network host \
    --pid=host \
    -v /etc/headplane/config.yaml:/etc/headplane/config.yaml:ro \
    -v /etc/headscale:/etc/headscale \
    -v /var/run/headscale:/var/run/headscale \
    -v /var/lib/headscale:/var/lib/headscale \
    -v headplane-data:/var/lib/headplane \
    ghcr.io/tale/headplane:latest

fi
