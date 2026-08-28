#!/usr/bin/env bash
set -euo pipefail

# verify-goose-mcp.sh — Parse Goose stream-json trace and verify MCP invocation.
#
# Reads evidence/goose-stream.jsonl and verifies:
#   1. DocTrust MCP extension was connected
#   2. MCP tool invocations occurred (doctrust__ prefix)
#   3. evaluate_case was invoked
#   4. Result contains REVIEW/BLOCKING
#   5. No shell/developer/filesystem tools were used
#
# Stream-json format (Goose v1.48.0):
#   Tool call:  {"type":"message","message":{"content":[{"type":"toolRequest",
#               "toolCall":{"value":{"name":"doctrust__evaluate_case",...}}}]}}
#   Tool result: {"type":"message","message":{"content":[{"type":"toolResponse",
#               "toolResult":{"value":{"content":[{"type":"text","text":"..."}]}}}]}}
#
# Usage:
#   ./scripts/verify-goose-mcp.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EVIDENCE_DIR="$REPO_ROOT/evidence/goose"
STREAM_FILE="$EVIDENCE_DIR/goose-stream.jsonl"

echo "=== Goose MCP Verification ==="
echo ""

# Check stream file exists.
if [ ! -f "$STREAM_FILE" ]; then
    echo "ERROR: Stream trace not found: $STREAM_FILE"
    echo "Run ./scripts/run-goose.sh --auto first."
    exit 1
fi

if [ ! -s "$STREAM_FILE" ]; then
    echo "ERROR: Stream trace is empty: $STREAM_FILE"
    exit 1
fi

# Filter to JSON-only lines (stream file may have TUI banner at the start).
JSON_LINES=$(grep '^{' "$STREAM_FILE" || true)
JSON_COUNT=$(echo "$JSON_LINES" | grep -c '.' || true)

echo "Stream file: $STREAM_FILE"
echo "Total lines: $(wc -l < "$STREAM_FILE")"
echo "JSON lines:  $JSON_COUNT"
echo ""

if [ "$JSON_COUNT" -eq 0 ]; then
    echo "ERROR: No JSON lines found in stream file."
    exit 1
fi

# --- Check 1: Extension connection ---
echo "--- Check 1: Extension connection ---"
EXTENSION_CONNECTED=$(echo "$JSON_LINES" | jq -r '
    select(.type == "message") |
    .message.content[]? |
    select(.type == "toolRequest") |
    .toolCall.value.name // empty
' 2>/dev/null | grep -c '^doctrust__' || true)

if [ "$EXTENSION_CONNECTED" -gt 0 ]; then
    echo "MCP extension connected:       YES"
else
    EXTENSION_CONNECTED_ALT=$(echo "$JSON_LINES" | grep -c 'doctrust' || true)
    if [ "$EXTENSION_CONNECTED_ALT" -gt 0 ]; then
        echo "MCP extension connected:       YES (via content match)"
    else
        echo "MCP extension connected:       NO"
    fi
fi
echo ""

# --- Check 2: MCP tool invocations ---
echo "--- Check 2: MCP tool invocations ---"
TOOL_NAMES=$(echo "$JSON_LINES" | jq -r '
    select(.type == "message") |
    .message.content[]? |
    select(.type == "toolRequest") |
    .toolCall.value.name // empty
' 2>/dev/null || true)

MCP_TOOLS=$(echo "$TOOL_NAMES" | grep '^doctrust__' || true)
MCP_COUNT=$(echo "$MCP_TOOLS" | grep -c '.' || true)

SHELL_TOOLS=$(echo "$TOOL_NAMES" | grep -E '^(developer__|computer__|filesystem)' || true)
SHELL_COUNT=$(echo "$SHELL_TOOLS" | grep -c '.' || true)

if [ "$MCP_COUNT" -gt 0 ]; then
    echo "MCP tool invocations found:    YES ($MCP_COUNT calls)"
    echo "$MCP_TOOLS" | sed 's/^/  - /'
else
    echo "MCP tool invocations found:    NO"
fi
echo ""

# --- Check 3: evaluate_case invoked ---
echo "--- Check 3: evaluate_case invoked ---"
EVAL_CASE=$(echo "$TOOL_NAMES" | grep -c 'doctrust__evaluate_case' || true)

if [ "$EVAL_CASE" -gt 0 ]; then
    echo "evaluate_case invoked:         YES"
else
    echo "evaluate_case invoked:         NO"
fi
echo ""

# --- Check 4: REVIEW/BLOCKING received ---
echo "--- Check 4: REVIEW/BLOCKING received ---"
REVIEW_FOUND=$(echo "$JSON_LINES" | grep -ci 'REVIEW\|BLOCKING' || true)

if [ "$REVIEW_FOUND" -gt 0 ]; then
    echo "REVIEW/BLOCKING received:      YES"
else
    echo "REVIEW/BLOCKING received:      NO"
fi
echo ""

# --- Check 5: Shell execution observed ---
echo "--- Check 5: Shell execution observed ---"
if [ "$SHELL_COUNT" -gt 0 ]; then
    echo "Shell execution observed:      YES"
    echo "$SHELL_TOOLS" | sed 's/^/  - /'
else
    echo "Shell execution observed:      NO"
fi
echo ""

# --- Final verdict ---
echo "=== Verdict ==="
PASS=true

if [ "$EXTENSION_CONNECTED" -eq 0 ] && [ "${EXTENSION_CONNECTED_ALT:-0}" -eq 0 ]; then
    echo "FAIL: MCP extension not connected"
    PASS=false
fi

if [ "$MCP_COUNT" -eq 0 ]; then
    echo "FAIL: No MCP tool invocations found"
    PASS=false
fi

if [ "$EVAL_CASE" -eq 0 ]; then
    echo "FAIL: evaluate_case not invoked"
    PASS=false
fi

if [ "$REVIEW_FOUND" -eq 0 ]; then
    echo "FAIL: No REVIEW/BLOCKING in result"
    PASS=false
fi

if [ "$SHELL_COUNT" -gt 0 ]; then
    echo "FAIL: Shell execution observed"
    PASS=false
fi

if [ "$PASS" = true ]; then
    echo ""
    echo "MCP extension connected:       YES"
    echo "MCP tool invocations found:    YES ($MCP_COUNT calls)"
    echo "evaluate_case invoked:         YES"
    echo "REVIEW/BLOCKING received:      YES"
    echo "Shell execution observed:      NO"
    echo ""
    echo "Independent interoperability:  PASS"
    exit 0
else
    echo ""
    echo "Independent interoperability:  FAIL"
    exit 1
fi
