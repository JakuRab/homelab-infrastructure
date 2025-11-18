# Dockerfile — install official Caddy binary with Cloudflare DNS plugin precompiled

ARG CADDY_VERSION=2.8.4

FROM alpine:3.20 AS downloader
ARG CADDY_VERSION
RUN set -eux; \
    apk add --no-cache curl; \
    curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=amd64&version=v${CADDY_VERSION}&p=github.com/caddy-dns/cloudflare" -o /tmp/caddy.bin; \
    chmod +x /tmp/caddy.bin

FROM caddy:${CADDY_VERSION}
COPY --from=downloader /tmp/caddy.bin /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
