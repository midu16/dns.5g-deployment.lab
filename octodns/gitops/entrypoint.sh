#!/usr/bin/env bash
# GitOps controller: validate and reconcile zones from Git (or mounted volume) to PowerDNS.
set -euo pipefail

SYNC_INTERVAL="${GITOPS_SYNC_INTERVAL:-60}"
AUTO_APPLY="${GITOPS_AUTO_APPLY:-true}"
ZONES_DIR="${ZONES_DIR:-/zones}"
GIT_REPO_URL="${GIT_REPO_URL:-}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_WORKDIR="${GIT_WORKDIR:-/git/zones}"
SYNC_FLAG="${GITOPS_SYNC_FLAG:-/tmp/octodns-sync-requested}"

if [[ "${PDNS_ACTIVE_PRIMARY:-A}" == "B" ]]; then
  PDNS_PRIMARY="${PDNS_PRIMARY:-pdns-primary-b}"
  CONFIG_FILE="${OCTODNS_CONFIG:-/octodns/config-dual-primary.yaml}"
else
  PDNS_PRIMARY="${PDNS_PRIMARY:-pdns-primary}"
  CONFIG_FILE="${OCTODNS_CONFIG:-/octodns/config.yaml}"
fi
PDNS_API_PORT="${PDNS_API_PORT:-8081}"

log() { echo "[gitops] $(date -Iseconds) $*"; }

wait_for_pdns() {
  log "Waiting for PowerDNS API at ${PDNS_PRIMARY}:${PDNS_API_PORT}..."
  for _ in $(seq 1 90); do
    if curl -sf -H "X-API-Key: ${PDNS_API_KEY}" \
      "http://${PDNS_PRIMARY}:${PDNS_API_PORT}/api/v1/servers/localhost/statistics" >/dev/null 2>&1; then
      log "PowerDNS API is ready."
      return 0
    fi
    sleep 2
  done
  log "ERROR: PowerDNS API not reachable."
  return 1
}

update_zones_from_git() {
  if [[ -z "$GIT_REPO_URL" ]]; then
    return 0
  fi
  if [[ ! -d "${GIT_WORKDIR}/.git" ]]; then
    log "Cloning ${GIT_REPO_URL} (branch ${GIT_BRANCH})..."
    git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO_URL" "$GIT_WORKDIR"
  else
    log "Pulling latest from ${GIT_REPO_URL}..."
    git -C "$GIT_WORKDIR" fetch origin "$GIT_BRANCH" --depth 1
    git -C "$GIT_WORKDIR" checkout "$GIT_BRANCH"
    git -C "$GIT_WORKDIR" reset --hard "origin/${GIT_BRANCH}"
  fi
  rsync -a --delete "${GIT_WORKDIR}/zones/" "${ZONES_DIR}/" 2>/dev/null \
    || rsync -a --delete "${GIT_WORKDIR}/" "${ZONES_DIR}/"
}

reconcile_once() {
  log "Validating zone YAML..."
  if ! octodns-validate --config-file "$CONFIG_FILE"; then
    log "ERROR: Validation failed — skipping apply."
    return 1
  fi

  if [[ "$AUTO_APPLY" != "true" ]]; then
    log "Dry-run (GITOPS_AUTO_APPLY=false)..."
    octodns-sync --config-file "$CONFIG_FILE"
    return 0
  fi

  log "Applying changes to PowerDNS primary..."
  octodns-sync --config-file "$CONFIG_FILE" --doit

  log "Triggering NOTIFY for configured zones..."
  while IFS= read -r zone; do
    [[ -z "$zone" ]] && continue
    curl -sf -X PUT \
      -H "X-API-Key: ${PDNS_API_KEY}" \
      "http://${PDNS_PRIMARY}:${PDNS_API_PORT}/api/v1/servers/localhost/zones/${zone}/notify" \
      >/dev/null 2>&1 \
      || log "NOTIFY for ${zone} skipped (zone may not exist yet)"
  done < <(grep -E '^  [a-z0-9._-]+\.:' "$CONFIG_FILE" | tr -d ' :')

  log "Reconcile complete."
  date -Iseconds > /tmp/gitops-last-success
  return 0
}

should_sync() {
  [[ -f "$SYNC_FLAG" ]] && return 0
  return 1
}

clear_sync_flag() {
  rm -f "$SYNC_FLAG"
}

start_webhook() {
  if [[ "${GITOPS_WEBHOOK_ENABLED:-false}" == "true" ]]; then
    log "Starting webhook on port ${GITOPS_WEBHOOK_PORT:-8088}..."
    python3 /octodns/gitops/webhook.py &
  fi
}

main() {
  wait_for_pdns
  start_webhook

  log "GitOps controller started (interval=${SYNC_INTERVAL}s, auto_apply=${AUTO_APPLY})."
  [[ -n "$GIT_REPO_URL" ]] && log "Remote Git: ${GIT_REPO_URL}@${GIT_BRANCH}" \
    || log "Using mounted zones at ${ZONES_DIR} (local GitOps workflow)."

  # Initial reconcile on startup
  update_zones_from_git || true
  reconcile_once || true
  clear_sync_flag

  while true; do
    sleep "$SYNC_INTERVAL"
    update_zones_from_git || { log "Git pull failed; retrying next interval."; continue; }
    if should_sync || [[ "${GITOPS_ALWAYS_RECONCILE:-false}" == "true" ]]; then
      reconcile_once || true
      clear_sync_flag
    else
      # Detect drift: dry-run output changes when files differ from PDNS
      if octodns-sync --config-file "$CONFIG_FILE" 2>&1 | grep -qE 'Create|Update|Delete'; then
        log "Drift detected — reconciling."
        reconcile_once || true
      fi
    fi
  done
}

main "$@"
