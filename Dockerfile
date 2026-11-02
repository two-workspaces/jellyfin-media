FROM caddy:2.11.7-alpine AS caddy
FROM filebrowser/filebrowser:v2.63.23 AS filebrowser

# Pinned: a moving tag (latest, 12) would rebase every deploy of this template at once.
FROM jellyfin/jellyfin:12.4.20261026-211555

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=filebrowser /bin/filebrowser /usr/local/bin/filebrowser

RUN apt-get update && apt-get install -y --no-install-recommends python3-minimal && rm -rf /var/lib/apt/lists/*

# Railway allows one volume per service, so all data sits under /data. The cache
# (image thumbnails, transcode segments) stays off the volume and can be rebuilt.
ENV PORT=8080 \
    JELLYFIN_DATA_DIR=/data/jellyfin \
    JELLYFIN_CONFIG_DIR=/data/jellyfin/config \
    JELLYFIN_LOG_DIR=/tmp/jellyfin-log \
    JELLYFIN_CACHE_DIR=/cache \
    XDG_CACHE_HOME=/cache

COPY Caddyfile /etc/caddy/Caddyfile
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
COPY --chmod=0755 drop-file-cache /usr/local/bin/drop-file-cache
ENTRYPOINT ["/railway-entrypoint.sh"]
