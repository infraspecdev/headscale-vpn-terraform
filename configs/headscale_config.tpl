server_url: http://${HEADSCALE_IP}:8080
listen_addr: 0.0.0.0:8080

noise:
  private_key_path: /var/lib/headscale/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 24h

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

dns:
  magic_dns: false

policy:
  path: /etc/headscale/acl.json

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
