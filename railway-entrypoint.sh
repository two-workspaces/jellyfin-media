#!/bin/bash
# Railway entrypoint for Jellyfin: the setup wizard is completed on loopback before
# the public port opens, dufs adds the uploads Jellyfin doesn't have, and Caddy serves
# both on $PORT.
set -euo pipefail

: "${JELLYFIN_ADMIN_PASSWORD:?JELLYFIN_ADMIN_PASSWORD is not set}"

mkdir -p "$JELLYFIN_CONFIG_DIR" /cache /data/media/movies /data/media/shows /data/media/music

# Without this Jellyfin ignores X-Forwarded-For from Caddy, sees every visitor as
# 127.0.0.1 and treats the whole internet as its local network.
[ -e "$JELLYFIN_CONFIG_DIR/network.xml" ] || cat > "$JELLYFIN_CONFIG_DIR/network.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <AutoDiscovery>false</AutoDiscovery>
  <KnownProxies>
    <string>127.0.0.1</string>
  </KnownProxies>
</NetworkConfiguration>
XML

trap 'kill $(jobs -p) 2>/dev/null; wait; exit 0' TERM INT

/jellyfin/jellyfin &
jellyfin_pid=$!

auth='Authorization: MediaBrowser Client="Railway", Device="Railway", DeviceId="railway-setup", Version="1"'
api() { curl -fsS -H 'Content-Type: application/json' -H "$auth" "http://127.0.0.1:8096$1" "${@:2}"; }

for i in $(seq 300); do
  [ "$(curl -fsS http://127.0.0.1:8096/health 2>/dev/null)" = Healthy ] && break
  [ "$i" = 300 ] && { echo "railway: Jellyfin didn't start in 5 minutes"; exit 1; }
  kill -0 "$jellyfin_pid"
  sleep 1
done

if ! api /System/Info/Public | grep -q '"StartupWizardCompleted":true'; then
  echo "railway: first boot, completing the setup wizard"
  pw=${JELLYFIN_ADMIN_PASSWORD//\\/\\\\}
  pw=${pw//\"/\\\"}
  api /Startup/User >/dev/null  # creates the first user
  api /Startup/Configuration -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
  api /Startup/User -d "{\"Name\":\"admin\",\"Password\":\"$pw\"}"
  api /Startup/RemoteAccess -d '{"EnableRemoteAccess":true}'
  api /Startup/Complete -X POST
  token=$(api /Users/AuthenticateByName -d "{\"Username\":\"admin\",\"Pw\":\"$pw\"}" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)
  auth="$auth, Token=\"$token\""
  for lib in Movies:movies:movies Shows:tvshows:shows Music:music:music; do
    IFS=: read -r name type dir <<<"$lib"
    api "/Library/VirtualFolders?name=$name&collectionType=$type&refreshLibrary=false" \
      -d "{\"LibraryOptions\":{\"EnableRealtimeMonitor\":true,\"PathInfos\":[{\"Path\":\"/data/media/$dir\"}]}}"
  done
fi

# Basic auth, read from the variable on every boot. No symlink or archive permissions.
dufs /data/media --bind 127.0.0.1 --port 8081 --path-prefix upload \
  --allow-upload --allow-delete --allow-search --auth "admin:$JELLYFIN_ADMIN_PASSWORD@/:rw" &
dufs_pid=$!

caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
caddy_pid=$!

# Railway counts the kernel's cache of files this container has read as the service's
# memory, and with no memory pressure it's never freed. Streaming a film would keep
# showing as gigabytes, so drop it every 15 minutes.
while sleep 900; do nice -n 19 drop-file-cache /data /cache /tmp; done &

# Any of them exiting means the service is broken: exit so Railway restarts it.
wait -n "$jellyfin_pid" "$dufs_pid" "$caddy_pid"
exit 1
