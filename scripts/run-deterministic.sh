#!/usr/bin/env bash
set -euo pipefail

# run-deterministic.sh — Run the five-tool MCP integration test against DocTrust.
#
# This script spawns its own DocTrust stdio process via the deterministic client.
# No shared background server is used.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCTRUST_DIR="${DOCTRUST_DIR:-$REPO_ROOT/doctrust}"

DOCTRUST_BIN="$DOCTRUST_DIR/bin/doctrust-mcp"
CLIENT_BIN="$REPO_ROOT/bin/deterministic-client"
SNAPSHOT_ROOT="$DOCTRUST_DIR/demo/shipment_release"
RULESETS_DIR="$DOCTRUST_DIR/rulesets"
SNAPSHOT_PATH="publication-verification/p6-20260825-012014-676181/available/evidence_snapshot.json"
EVIDENCE_DIR="$REPO_ROOT/evidence/deterministic"

# Preflight checks.
if [ ! -x "$DOCTRUST_BIN" ]; then
    echo "ERROR: doctrust-mcp binary not found at $DOCTRUST_BIN"
    echo "Run ./scripts/setup.sh first."
    exit 1
fi

if [ ! -x "$CLIENT_BIN" ]; then
    echo "ERROR: deterministic-client binary not found at $CLIENT_BIN"
    echo "Run ./scripts/setup.sh first."
    exit 1
fi

if [ ! -f "$SNAPSHOT_ROOT/$SNAPSHOT_PATH" ]; then
    echo "ERROR: snapshot not found at $SNAPSHOT_ROOT/$SNAPSHOT_PATH"
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"

echo "=== Deterministic MCP Client ==="
echo "DocTrust binary: $DOCTRUST_BIN"
echo "Snapshot:        $SNAPSHOT_PATH"
echo "Evidence dir:    $EVIDENCE_DIR"
echo ""

"$CLIENT_BIN" \
    --doctrust-bin "$DOCTRUST_BIN" \
    --snapshot-root "$SNAPSHOT_ROOT" \
    --rulesets-dir "$RULESETS_DIR" \
    --domain shipment_release \
    --snapshot-path "$SNAPSHOT_PATH" \
    --evidence-dir "$EVIDENCE_DIR"

echo ""
echo "Evidence files:"
ls -la "$EVIDENCE_DIR"/*.json 2>/dev/null || echo "  (none)"
