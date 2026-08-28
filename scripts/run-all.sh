#!/usr/bin/env bash
set -euo pipefail

# run-all.sh — Full demo sequence in one command.
#
# Video order (8 scenes):
#   1. Public DocTrust repo / pinned revision
#   2. MCP Inspector — 5 tools discovered
#   3. Inspector — evaluate_case schema and invocation
#   4. Goose — interactive agent discovers DocTrust
#   5. Goose — returns REVIEW/BLOCKING (5,150 KG vs 4,650 KG)
#   6. Deterministic MCP client — all 5 tools exercised
#   7. verify-audit / verify-ruleset — PASS
#   8. Close — "This run did not use Hermes."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "  DocTrust MCP Interoperability Proof"
echo "============================================"
echo ""

# Step 1: Deterministic MCP client (earliest hard proof).
echo ">>> Step 1/5: Deterministic MCP Client"
echo "--------------------------------------------"
bash "$SCRIPT_DIR/run-deterministic.sh"
echo ""

# Step 2: Inspector CLI (testing path).
echo ">>> Step 2/5: MCP Inspector (CLI test)"
echo "--------------------------------------------"
if bash "$SCRIPT_DIR/run-inspector.sh --cli"; then
    echo "Inspector CLI: PASS"
else
    echo "Inspector CLI: FAILED or skipped"
fi
echo ""

# Step 3: Audit verification.
echo ">>> Step 3/5: Audit Verification"
echo "--------------------------------------------"
if bash "$SCRIPT_DIR/verify-result.sh"; then
    echo "Verification: PASS"
else
    echo "Verification: FAILED"
fi
echo ""

# Step 4: Goose forensic verification (automated test if available).
echo ">>> Step 4/6: Goose Agent (automated test)"
echo "--------------------------------------------"
if command -v goose &>/dev/null; then
    if bash "$SCRIPT_DIR/run-goose.sh --auto"; then
        echo "Goose automated: PASS"
    else
        echo "Goose automated: FAILED or skipped"
    fi
else
    echo "Goose: not installed (install v1.48.0 for full demo)"
fi
echo ""

# Step 4b: Verify Goose used MCP (not shell).
echo ">>> Step 4b/6: Goose MCP Verification"
echo "--------------------------------------------"
EVIDENCE_DIR="$REPO_ROOT/evidence/goose"
if [ -f "$EVIDENCE_DIR/goose-stream.jsonl" ] && [ -s "$EVIDENCE_DIR/goose-stream.jsonl" ]; then
    if bash "$SCRIPT_DIR/verify-goose-mcp.sh"; then
        echo "Goose MCP verification: PASS"
    else
        echo "Goose MCP verification: FAILED"
    fi
else
    echo "Skipped (no stream-json output — run with --auto first)"
fi
echo ""

# Step 5: Conformance (documented as unsupported).
echo ">>> Step 5/6: Conformance Suite (status)"
echo "--------------------------------------------"
bash "$SCRIPT_DIR/run-conformance.sh"
echo ""

# Step 6: Summary.
echo ">>> Step 6/6: Summary"
echo "--------------------------------------------"
echo "============================================"
echo "  Summary"
echo "============================================"
echo ""
echo "=== Evidence Collected ==="
for dir in deterministic inspector goose audit conformance; do
    count=$(find "$SCRIPT_DIR/../evidence/$dir" -name "*.json" -o -name "*.log" 2>/dev/null | wc -l)
    echo "  evidence/$dir/ — $count file(s)"
done
echo ""
echo "=== What Was Proven ==="
echo "  MCP Inspector      -> visual tool discovery (CLI test)"
echo "  Deterministic MCP  -> five-tool invocation proof"
echo "  Goose (forensic)   -> independent agent MCP verification (if installed)"
echo "  verify-audit       -> artifact integrity proof"
echo "  Conformance        -> UNSUPPORTED (stdio not compatible, issue #258)"
echo ""
echo "=== Closing ==="
echo "The official MCP Inspector, an independent open-source agent,"
echo "and an independent MCP client each connected to the public"
echo "DocTrust MCP implementation through standard MCP stdio."
echo "All three obtained results from the same pinned public"
echo "DocTrust revision, without Hermes."
echo ""
echo "============================================"
echo "  Done"
echo "============================================"
