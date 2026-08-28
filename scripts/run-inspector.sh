#!/usr/bin/env bash
set -euo pipefail

# run-inspector.sh — Launch the MCP Inspector against DocTrust.
#
# Verified against Inspector v2.4.0.
#
# The Inspector uses positional commands for stdio (no --command flag).
# Stdio is the default transport — the command is everything after the Inspector args.
#
# Video mode (default): launches web UI in browser.
# CLI mode: runs non-interactively for testing/diagnostics.
#
# Usage:
#   ./scripts/run-inspector.sh          # Web UI (for video)
#   ./scripts/run-inspector.sh --cli    # CLI mode (for testing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCTRUST_DIR="${DOCTRUST_DIR:-$REPO_ROOT/doctrust}"

DOCTRUST_BIN="$DOCTRUST_DIR/bin/doctrust-mcp"
SNAPSHOT_ROOT="$DOCTRUST_DIR/demo/shipment_release"
RULESETS_DIR="$DOCTRUST_DIR/rulesets"
EVIDENCE_DIR="$REPO_ROOT/evidence/inspector"

MODE="web"
if [ "${1:-}" = "--cli" ]; then
    MODE="cli"
fi

# Preflight checks.
if [ ! -x "$DOCTRUST_BIN" ]; then
    echo "ERROR: doctrust-mcp binary not found at $DOCTRUST_BIN"
    echo "Run ./scripts/setup.sh first."
    exit 1
fi

if ! command -v npx &>/dev/null; then
    echo "ERROR: npx not found. Install Node.js (>= 22.19.0) first."
    exit 1
fi

if [ ! -d "$SNAPSHOT_ROOT/reviewers" ]; then
    echo "ERROR: reviewers directory not found at $SNAPSHOT_ROOT/reviewers"
    echo "Snapshot root must be demo/shipment_release/ for audit artifact generation."
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"

echo "=== MCP Inspector ==="
echo "Version:         @modelcontextprotocol/inspector v2.4.0"
echo "DocTrust binary: $DOCTRUST_BIN"
echo "Snapshot root:   $SNAPSHOT_ROOT"
echo "Rulesets dir:    $RULESETS_DIR"
echo "Mode:            $MODE"
echo "Evidence dir:    $EVIDENCE_DIR"
echo ""
echo "The Inspector spawns its own DocTrust stdio process."
echo ""

if [ "$MODE" = "cli" ]; then
    # CLI mode: non-interactive, deterministic output.
    # Inspector v2.4.0: positional command, --cli flag, -- separator for Inspector options.
    echo "--- Running in CLI mode ---"
    echo "Discovering tools..."
    npx @modelcontextprotocol/inspector --cli \
        "$DOCTRUST_BIN" --domain shipment_release --snapshot-root "$SNAPSHOT_ROOT" --rulesets-dir "$RULESETS_DIR" \
        -- --method tools/list \
        2>&1 | tee "$EVIDENCE_DIR/inspector-tools-list.json"

    echo ""
    echo "Invoking evaluate_case..."
    npx @modelcontextprotocol/inspector --cli \
        "$DOCTRUST_BIN" --domain shipment_release --snapshot-root "$SNAPSHOT_ROOT" --rulesets-dir "$RULESETS_DIR" \
        -- --method tools/call \
           --tool-name evaluate_case \
           --tool-arg "snapshot_path=publication-verification/p6-20260825-012014-676181/available/evidence_snapshot.json" \
        2>&1 | tee "$EVIDENCE_DIR/inspector-evaluate-case.json"

    echo ""
    echo "CLI output saved to: $EVIDENCE_DIR/"
else
    # Web UI mode: opens browser, visual evidence for video.
    echo "--- Launching Web UI ---"
    echo "The Inspector will open in your browser."
    echo "Look for 5 DocTrust tools in the tool list."
    echo ""
    echo "To test from the UI:"
    echo "  1. Verify 5 tools are discovered"
    echo "  2. Click evaluate_case to see its schema"
    echo "  3. Make a real invocation with the anomaly snapshot"
    echo ""
    echo "Press Ctrl+C when done."
    echo ""

    # Inspector v2.4.0: positional command for stdio.
    npx @modelcontextprotocol/inspector \
        "$DOCTRUST_BIN" --domain shipment_release --snapshot-root "$SNAPSHOT_ROOT" --rulesets-dir "$RULESETS_DIR" \
        2>&1 | tee "$EVIDENCE_DIR/inspector-web-ui.log"
fi

echo ""
echo "Inspector output saved to: $EVIDENCE_DIR/"
