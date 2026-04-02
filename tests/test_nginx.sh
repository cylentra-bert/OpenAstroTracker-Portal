#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Nginx Config Validation ==="

# Check config exists
if [ ! -f "$REPO_DIR/nginx/openastrotracker.conf" ]; then
    echo "FAIL: nginx config not found"
    exit 1
fi
echo "  PASS: Config file exists"

echo "Checking structure..."

# Brace balance
OPENS=$(grep -c '{' "$REPO_DIR/nginx/openastrotracker.conf" || true)
CLOSES=$(grep -c '}' "$REPO_DIR/nginx/openastrotracker.conf" || true)
if [ "$OPENS" -ne "$CLOSES" ]; then
    echo "FAIL: Mismatched braces (open=$OPENS close=$CLOSES)"
    exit 1
fi
echo "  PASS: Brace balance ($OPENS open, $CLOSES close)"

# All proxy_pass targets are localhost
if grep -q 'proxy_pass' "$REPO_DIR/nginx/openastrotracker.conf"; then
    NON_LOCAL=$(grep 'proxy_pass' "$REPO_DIR/nginx/openastrotracker.conf" | grep -v '127.0.0.1' | grep -v 'localhost' || true)
    if [ -n "$NON_LOCAL" ]; then
        echo "FAIL: Non-localhost proxy_pass found: $NON_LOCAL"
        exit 1
    fi
    echo "  PASS: All proxy_pass targets are localhost"
fi

# Semicolons on directive lines (basic check: proxy_pass lines must end with ;)
BAD_DIRECTIVES=$(grep -n 'proxy_pass\|proxy_set_header\|proxy_http_version\|proxy_read_timeout' "$REPO_DIR/nginx/openastrotracker.conf" | grep -v ';$' || true)
if [ -n "$BAD_DIRECTIVES" ]; then
    echo "FAIL: Directive lines missing trailing semicolon:"
    echo "$BAD_DIRECTIVES"
    exit 1
fi
echo "  PASS: Directive lines have trailing semicolons"

# WebSocket upgrade headers for /desktop/
if grep -q '/desktop/' "$REPO_DIR/nginx/openastrotracker.conf"; then
    if ! grep -A10 'location /desktop/' "$REPO_DIR/nginx/openastrotracker.conf" | grep -q 'Upgrade'; then
        echo "FAIL: /desktop/ location missing WebSocket upgrade headers"
        exit 1
    fi
    echo "  PASS: /desktop/ has WebSocket upgrade headers"
fi

# WebSocket upgrade headers for /pa/ (polar alignment uses Socket.IO)
if grep -q '/pa/' "$REPO_DIR/nginx/openastrotracker.conf"; then
    if ! grep -A10 'location /pa/' "$REPO_DIR/nginx/openastrotracker.conf" | grep -q 'Upgrade'; then
        echo "FAIL: /pa/ location missing WebSocket upgrade headers"
        exit 1
    fi
    echo "  PASS: /pa/ has WebSocket upgrade headers"
fi

# Socket.IO location exists (required for polar alignment tool)
if ! grep -q '/socket.io/' "$REPO_DIR/nginx/openastrotracker.conf"; then
    echo "FAIL: Missing /socket.io/ location block"
    exit 1
fi
echo "  PASS: /socket.io/ location block present"

# Auth protection on /desktop/ locations
if grep -q '/desktop/' "$REPO_DIR/nginx/openastrotracker.conf"; then
    if ! grep -B2 -A5 'location.*\/desktop\/' "$REPO_DIR/nginx/openastrotracker.conf" | grep -q 'auth_basic'; then
        echo "FAIL: /desktop/ location missing auth_basic protection"
        exit 1
    fi
    echo "  PASS: /desktop/ has auth_basic protection"
fi

# Expected proxy ports match service definitions
# PA (Flask) on 5000, NoVNC on 6080, INDI Web on 8624
for port_check in "5000:pa" "6080:desktop" "8624:indi"; do
    PORT="${port_check%%:*}"
    NAME="${port_check##*:}"
    if ! grep -q "127.0.0.1:$PORT" "$REPO_DIR/nginx/openastrotracker.conf"; then
        echo "FAIL: Expected proxy to 127.0.0.1:$PORT for /$NAME/"
        exit 1
    fi
    echo "  PASS: /$NAME/ proxies to expected port $PORT"
done

echo ""
echo "All nginx checks passed"
