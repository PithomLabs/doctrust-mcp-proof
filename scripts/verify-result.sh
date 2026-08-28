#!/usr/bin/env bash
set -euo pipefail

# verify-result.sh — Run verify-audit and verify-ruleset on the demo fixture.
#
# Uses DocTrust's own verification CLIs against the anomaly fixture.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCTRUST_DIR="${DOCTRUST_DIR:-$REPO_ROOT/doctrust}"

VERIFY_AUDIT="$DOCTRUST_DIR/bin/verify-audit"
VERIFY_RULESET="$DOCTRUST_DIR/bin/verify-ruleset"
SNAPSHOT_ROOT="$DOCTRUST_DIR/demo/shipment_release"
SNAPSHOT_PATH="publication-verification/p6-20260825-012014-676181/available/evidence_snapshot.json"
EVIDENCE_DIR="$REPO_ROOT/evidence/audit"

mkdir -p "$EVIDENCE_DIR"

echo "=== Audit Verification ==="
echo "Snapshot: $SNAPSHOT_PATH"
echo ""

# Verify ruleset.
if [ -x "$VERIFY_RULESET" ]; then
    echo "--- verify-ruleset ---"
    cd "$DOCTRUST_DIR"
    "$VERIFY_RULESET" \
        --domain shipment_release \
        --rulesets-dir "$DOCTRUST_DIR/rulesets" \
        2>&1 | tee "$EVIDENCE_DIR/verify-ruleset.log" && \
        echo "verify-ruleset: PASS" || \
        echo "verify-ruleset: FAIL"
    echo ""
else
    echo "WARNING: verify-ruleset binary not found, skipping"
    echo ""
fi

# Verify audit artifact.
if [ -x "$VERIFY_AUDIT" ]; then
    echo "--- verify-audit ---"
    # verify-audit needs to run from DocTrust repo root to find rulesets,
    # but the snapshot path is relative to demo/shipment_release/.
    # Use the full path from repo root.
    cd "$DOCTRUST_DIR"
    "$VERIFY_AUDIT" \
        "demo/shipment_release/$SNAPSHOT_PATH" \
        2>&1 | tee "$EVIDENCE_DIR/verify-audit.log" && \
        echo "verify-audit: PASS" || \
        echo "verify-audit: FAIL"
    echo ""
else
    echo "WARNING: verify-audit binary not found, skipping"
    echo ""
fi

echo "Verification logs saved to: $EVIDENCE_DIR/"
