#!/usr/bin/env bash
set -euo pipefail

# run-conformance.sh — MCP Conformance Suite status for DocTrust.
#
# STATUS: UNSUPPORTED — the official Conformance Suite does not support stdio transport.
#
# @modelcontextprotocol/conformance v0.1.16 only supports HTTP (Streamable HTTP).
# DocTrust uses stdio only. There is no way to test a stdio server with the
# current Conformance Suite without an HTTP shim.
#
# GitHub issue: https://github.com/modelcontextprotocol/conformance/issues/258
#   "Add support for a stdio testing" — still open as of Aug 2026.
#
# The Conformance Suite is therefore NOT included in the primary video sequence.
# This script documents the finding for completeness.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EVIDENCE_DIR="$REPO_ROOT/evidence/conformance"

mkdir -p "$EVIDENCE_DIR"

echo "=== MCP Conformance Suite ==="
echo ""
echo "Package:    @modelcontextprotocol/conformance"
echo "Version:    0.1.16 (latest stable)"
echo "GitHub:     https://github.com/modelcontextprotocol/conformance"
echo "Issue:      #258 (Add support for stdio testing) — OPEN"
echo ""
echo "STATUS: UNSUPPORTED for DocTrust"
echo ""
echo "Reason: The Conformance Suite only supports HTTP (Streamable HTTP) transport."
echo "DocTrust uses stdio. The 'server' command requires --url which implies HTTP."
echo "There is no --stdio, --command, or equivalent flag."
echo ""
echo "The primary interoperability evidence for this PoC is:"
echo "  - MCP Inspector (visual tool discovery)"
echo "  - Goose (independent agent interoperability)"
echo "  - Deterministic MCP client (complete five-tool invocation)"
echo ""
echo "This script is retained for documentation purposes only."
echo "It is NOT part of the primary video sequence."
echo ""

# Record the finding.
cat > "$EVIDENCE_DIR/conformance-status.json" <<EOF
{
  "package": "@modelcontextprotocol/conformance",
  "version": "0.1.16",
  "status": "unsupported",
  "reason": "Conformance Suite only supports HTTP (Streamable HTTP) transport. DocTrust uses stdio.",
  "github_issue": "https://github.com/modelcontextprotocol/conformance/issues/258",
  "issue_status": "open",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "note": "Not included in primary video sequence."
}
EOF

echo "Status recorded to: $EVIDENCE_DIR/conformance-status.json"
