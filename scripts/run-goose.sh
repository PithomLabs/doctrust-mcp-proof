#!/usr/bin/env bash
set -euo pipefail

# run-goose.sh — Launch Goose with DocTrust configured as a custom MCP server.
#
# Verified against Goose v1.48.0.
#
# Two explicit modes:
#   Interactive (default) — clean TUI for video recording. No stream-json.
#   Automated (--auto)    — captures structured trace for forensic verification.
#
# Key flags:
#   --no-profile           Disables all built-in extensions (no shell/filesystem).
#   --with-extension       Adds only the DocTrust MCP extension.
#   --output-format stream-json   (automated only) Captures structured trace.
#   --max-turns 10         (automated only) Limits Goose autonomy.
#
# Usage:
#   ./scripts/run-goose.sh          # Interactive (for video)
#   ./scripts/run-goose.sh --auto   # Automated (for forensic verification)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCTRUST_DIR="${DOCTRUST_DIR:-$REPO_ROOT/doctrust}"

DOCTRUST_BIN="$DOCTRUST_DIR/bin/doctrust-mcp"
SNAPSHOT_ROOT="$DOCTRUST_DIR/demo/shipment_release"
RULESETS_DIR="$DOCTRUST_DIR/rulesets"
SNAPSHOT_PATH="publication-verification/p6-20260825-012014-676181/available/evidence_snapshot.json"
EVIDENCE_DIR="$REPO_ROOT/evidence/goose"

MODE="interactive"
if [ "${1:-}" = "--auto" ]; then
    MODE="auto"
fi

# Preflight checks.
if [ ! -x "$DOCTRUST_BIN" ]; then
    echo "ERROR: doctrust-mcp binary not found at $DOCTRUST_BIN"
    echo "Run ./scripts/setup.sh first."
    exit 1
fi

if ! command -v goose &>/dev/null; then
    echo "ERROR: goose not found."
    echo ""
    echo "Install Goose v1.48.0 CLI:"
    echo "  https://github.com/aaif-goose/goose"
    echo ""
    echo "Note: /usr/bin/goose is the desktop app. The CLI is at:"
    echo "  /usr/lib/goose/resources/bin/goose"
    exit 1
fi

# Detect which goose binary to use (CLI vs desktop app).
# The desktop app at /usr/bin/goose is Electron-based and not suitable for scripting.
# The CLI at /usr/lib/goose/resources/bin/goose is the correct one.
GOOSE_BIN=$(command -v goose)
if [ "$GOOSE_BIN" = "/usr/bin/goose" ]; then
    # Check if the CLI version exists at the known path.
    if [ -x "/usr/lib/goose/resources/bin/goose" ]; then
        GOOSE_BIN="/usr/lib/goose/resources/bin/goose"
        echo "Using Goose CLI: $GOOSE_BIN"
    else
        echo "WARNING: /usr/bin/goose is the desktop app, not the CLI."
        echo "Install Goose CLI: https://github.com/aaif-goose/goose"
    fi
fi

GOOSE_VERSION=$("$GOOSE_BIN" --version 2>&1 || echo "unknown")
echo "Goose version: $GOOSE_VERSION"

mkdir -p "$EVIDENCE_DIR"

echo "=== Goose Agent ==="
echo "Version:         $GOOSE_VERSION"
echo "DocTrust binary: $DOCTRUST_BIN"
echo "Snapshot root:   $SNAPSHOT_ROOT"
echo "Rulesets dir:    $RULESETS_DIR"
echo "Mode:            $MODE"
echo "Evidence dir:    $EVIDENCE_DIR"
echo ""
echo "Flags:           --no-profile (no built-in extensions)"
echo "                 --with-extension (DocTrust MCP only)"
echo ""

# Build the --with-extension string.
# Format: "name: command args..." — colon separates extension name from command.
EXTENSION_STRING="doctrust: $DOCTRUST_BIN --domain shipment_release --snapshot-root $SNAPSHOT_ROOT --rulesets-dir $RULESETS_DIR"

REQUEST="Evaluate the shipment case at $SNAPSHOT_ROOT/$SNAPSHOT_PATH and report any compliance findings."

if [ "$MODE" = "auto" ]; then
    # Automated / forensic mode: capture stream-json for MCP verification.
    # Uses 'goose run' (not 'goose session') because --output-format is only on 'run'.
    echo "--- Automated / forensic mode ---"
    echo "Request: $REQUEST"
    echo ""
    echo "Capturing structured stream-json trace..."
    echo ""

    printf '%s\n' "$REQUEST" | "$GOOSE_BIN" run \
        --no-profile \
        --with-extension "$EXTENSION_STRING" \
        --max-turns 10 \
        --output-format stream-json \
        --no-session \
        --instructions - \
        2>&1 | tee "$EVIDENCE_DIR/goose-stream.jsonl"

    echo ""
    echo "Stream trace saved to: $EVIDENCE_DIR/goose-stream.jsonl"
    echo "Run ./scripts/verify-goose-mcp.sh to verify MCP invocation."
else
    # Interactive / video mode: clean TUI, no stream-json.
    echo "--- Interactive / video mode ---"
    echo ""
    echo "When Goose opens, type this request:"
    echo ""
    echo "  $REQUEST"
    echo ""
    echo "Watch for:"
    echo "  - Goose discovering DocTrust tools"
    echo "  - Goose invoking evaluate_case"
    echo "  - REVIEW / BLOCKING result"
    echo "  - Gross-weight mismatch: 5,150 KG vs 4,650 KG"
    echo ""
    echo "After the session, run forensic verification:"
    echo "  ./scripts/run-goose.sh --auto"
    echo "  ./scripts/verify-goose-mcp.sh"
    echo ""
    echo "Press Ctrl+C when done."
    echo ""

    # Launch Goose interactively with --no-profile.
    # Only DocTrust MCP tools are available — no shell/filesystem.
    "$GOOSE_BIN" session \
        --no-profile \
        --with-extension "$EXTENSION_STRING" \
        2>&1 | tee "$EVIDENCE_DIR/goose-output.log"
fi

echo ""
echo "Evidence saved to: $EVIDENCE_DIR/"
