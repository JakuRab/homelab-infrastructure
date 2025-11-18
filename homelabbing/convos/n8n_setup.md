  Summary of n8n Installation

  1. Docker Compose (`n8n-docker-compose.yml`):
  A new file was created to define the n8n service.

  1 version: '3.7'
  2
  3 services:
  4   n8n:
  5     image: n8nio/n8n
  6     container_name: n8n
  7     restart: unless-stopped
  8     environment:
  9       - GENERIC_TIMEZONE=Europe/Warsaw
  10     labels:
  11       - "glance.name=n8n"
  12       - "glance.icon=sh:n8n-light"
  13       - "glance.url=n8n.rabalski.eu"
  10     volumes:
  11       - /opt/n8n/data:/home/node/.n8n
  12     networks:
  13       - caddy_net
   14
   15 networks:
   16   caddy_net:
   17     external: true

  2. Caddyfile Update:
  Your Caddyfile (at `configs/caddy/Caddyfile`) was modified to add a reverse proxy entry for the new service.

   1 # ===========================
   2 # n8n
   3 # ===========================
   4 n8n.rabalski.eu {
   5   import gate
   6   encode zstd gzip
   7   reverse_proxy http://n8n:5678
  8 }

  3. Final Server-Side Instructions:
  You will need to perform these actions on your clockworkcity server:
   * Prepare bind mount with correct ownership (fixes EACCES on /home/node/.n8n):
     ```bash
     sudo mkdir -p /opt/n8n/data
     sudo chown -R 1000:1000 /opt/n8n
     sudo chmod -R u+rwX,g+rwX,o-rwx /opt/n8n
     ```
   * Deploy the n8n stack in Portainer using the compose file above (configs/n8n/docker-compose.yml).
   * Edit `configs/caddy/Caddyfile` with the new service block.
   * Reload Caddy's configuration with: docker exec caddy caddy reload --config /etc/caddy/Caddyfile
   * Create DNS rewrites in AdGuard Home for n8n.rabalski.eu:
     - A record → 192.168.1.10 (LAN IP of clockworkcity)
     - AAAA record → your LAN IPv6 for clockworkcity (if you have one). If you don't use IPv6 internally, add a custom rule to suppress AAAA so clients prefer IPv4:
       ```
       ||n8n.rabalski.eu^$dnsrewrite=NOERROR;A;192.168.1.10
       ||n8n.rabalski.eu^$dnsrewrite=NOERROR;AAAA;
       ```
     - Flush AdGuard cache and your client DNS cache after changes.
   * If the browser shows a TLS error, check Caddy logs and test over HTTP/2 explicitly while the container starts:
     ```bash
     docker logs caddy --since 2m
     curl -I --http2 https://n8n.rabalski.eu
     ```

Updated docker-compose.yml with Glance labels (saved to configs/n8n/docker-compose.yml):

```yaml
version: '3.7'

services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    environment:
      - GENERIC_TIMEZONE=Europe/Warsaw
      - N8N_HOST=n8n.rabalski.eu
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - N8N_EDITOR_BASE_URL=https://n8n.rabalski.eu
      - WEBHOOK_URL=https://n8n.rabalski.eu
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - DB_SQLITE_POOL_SIZE=1
      - N8N_RUNNERS_ENABLED=true
    labels:
      - "glance.name=n8n"
      - "glance.icon=sh:n8n-light"
      - "glance.url=n8n.rabalski.eu"
    volumes:
      - /opt/n8n/data:/home/node/.n8n
    networks:
      - caddy_net

networks:
  caddy_net:
    external: true
```
