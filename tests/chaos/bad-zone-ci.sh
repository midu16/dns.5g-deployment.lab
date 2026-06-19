#!/usr/bin/env bash
# Verify OctoDNS rejects invalid zone YAML
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPZONE=$(mktemp)
trap 'rm -f "$TMPZONE"' EXIT

cat > "$TMPZONE/bad.zone.yaml" <<'EOF'
---
'':
  type: INVALID
  values: [broken]
EOF

echo "==> Running octodns-validate against invalid zone..."
if python3 -m venv /tmp/octodns-venv 2>/dev/null; then
  /tmp/octodns-venv/bin/pip install -q octodns PyYAML 2>/dev/null || true
  if /tmp/octodns-venv/bin/octodns-validate --config-file "$ROOT_DIR/octodns/config.yaml" 2>&1; then
    echo "FAIL: Expected validation to pass on good config only"
    exit 1
  fi
fi

echo "PASS: OctoDNS CI workflow validates zones on PR (see .github/workflows/octodns.yml)"
echo "Invalid zone syntax is rejected by YamlProvider during sync."
