#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Clone DocTrust at pinned revision and build binaries.
#
# Environment variables:
#   DOCTRUST_REF   — git ref to checkout (default: pinned commit)
#   DOCTRUST_REPO  — repository URL (default: https://github.com/PithomLabs/doctrust)
#   DOCTRUST_DIR   — local clone directory (default: ./doctrust)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DOCTRUST_REF="${DOCTRUST_REF:-29961d657cc0d33f6b17ec0b0cc535840272d1d9}"
DOCTRUST_REPO="${DOCTRUST_REPO:-https://github.com/PithomLabs/doctrust}"
DOCTRUST_DIR="${DOCTRUST_DIR:-$REPO_ROOT/doctrust}"

echo "=== Setup ==="
echo "Repository: $DOCTRUST_REPO"
echo "Ref:        $DOCTRUST_REF"
echo "Directory:  $DOCTRUST_DIR"
echo ""

# Step 1: Clone if not present.
if [ ! -d "$DOCTRUST_DIR/.git" ]; then
    echo "--- Cloning DocTrust ---"
    git clone "$DOCTRUST_REPO" "$DOCTRUST_DIR"
else
    echo "--- DocTrust already cloned ---"
fi

# Step 2: Checkout pinned ref.
echo "--- Checking out $DOCTRUST_REF ---"
cd "$DOCTRUST_DIR"
git fetch origin
git checkout "$DOCTRUST_REF"
echo "HEAD: $(git rev-parse HEAD)"

# Step 3: Build MCP server binary.
echo ""
echo "--- Building doctrust-mcp ---"
make mcp
echo "Binary: $DOCTRUST_DIR/bin/doctrust-mcp"

# Step 4: Build verification binaries.
echo ""
echo "--- Building verification binaries ---"
make -C "$DOCTRUST_DIR" bin/verify-audit 2>/dev/null || echo "verify-audit build skipped (not critical)"
make -C "$DOCTRUST_DIR" bin/verify-ruleset 2>/dev/null || echo "verify-ruleset build skipped (not critical)"

# Step 5: Build the deterministic client.
echo ""
echo "--- Building deterministic MCP client ---"
cd "$REPO_ROOT/deterministic"
go build -o "$REPO_ROOT/bin/deterministic-client" .
echo "Binary: $REPO_ROOT/bin/deterministic-client"

# Step 6: Record versions.
echo ""
echo "--- Recording versions ---"
mkdir -p "$REPO_ROOT/evidence"
cat > "$REPO_ROOT/evidence/versions.json" <<EOF
{
  "doctrust_ref": "$DOCTRUST_REF",
  "doctrust_commit": "$(cd "$DOCTRUST_DIR" && git rev-parse HEAD)",
  "go_version": "$(go version)",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
echo "Versions written to evidence/versions.json"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  ./scripts/run-deterministic.sh    # Run the five-tool MCP integration test"
echo "  ./scripts/run-inspector.sh        # Run MCP Inspector"
echo "  ./scripts/run-goose.sh            # Run Goose agent"
echo "  ./scripts/run-all.sh              # Run everything"
