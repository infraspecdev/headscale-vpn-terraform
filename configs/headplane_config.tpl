server:
  host: "0.0.0.0"
  port: 3000
  cookie_secret: "${COOKIE_SECRET}"
  cookie_secure: false
  data_path: /var/lib/headplane

headscale:
  url: http://localhost:8080
  config_path: /etc/headscale/config.yaml
  config_strict: false
  api_key: __HEADPLANE_API_KEY__

integration:
  proc:
    enabled: true
