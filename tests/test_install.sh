#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# Check if shellcheck is available
if ! command -v shellcheck &>/dev/null; then
    echo "=== Shell Script Validation ==="
    echo "shellcheck is not installed -- skipping shell script validation."
    echo "Install with: apt-get install shellcheck  (or brew install shellcheck)"
    exit 0
fi

check_file() {
    local file="$1"
    if shellcheck -S warning "$file"; then
        echo "  PASS: $file"
        ((PASS++))
    else
        echo "  FAIL: $file"
        ((FAIL++))
    fi
}

echo "=== Shell Script Validation ==="
check_file "$REPO_DIR/install.sh"
check_file "$REPO_DIR/uninstall.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
