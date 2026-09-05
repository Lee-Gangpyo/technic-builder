#!/usr/bin/env bash
# Serve the HTML5 build for LAN / iPad Safari testing.
# Usage: ./scripts/serve_web.sh [port]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/build/web"
PORT="${1:-8080}"

if [[ ! -f "$WEB/index.html" ]]; then
  echo "Missing $WEB/index.html — export first:"
  echo "  godot --headless --path \"$ROOT\" --export-release \"Web (Safari/iPad)\" \"$WEB/index.html\""
  exit 1
fi

# Pick a LAN IP hint (best-effort)
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${LAN_IP:-}" ]]; then
  LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
fi
LAN_IP="${LAN_IP:-<your-lan-ip>}"

echo "Serving Technic Builder Web build"
echo "  Local:  http://127.0.0.1:${PORT}/"
echo "  iPad:   http://${LAN_IP}:${PORT}/"
echo "  Dir:    ${WEB}"
echo "Threads: OFF (Safari-friendly). Ctrl+C to stop."
cd "$WEB"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
