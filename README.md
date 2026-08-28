# DocTrust MCP Interoperability Proof

An independent interoperability test demonstrating that DocTrust's MCP server can be discovered and driven by third-party MCP tooling and an independent AI agent.

## Evidence Chain

```
Public DocTrust revision (pinned commit)
        +
MCP Inspector (visual tool discovery)
        +
Independent Goose agent (natural-language compliance request)
        +
Deterministic MCP client (tools/list + all 5 DocTrust tools)
        +
Real DocTrust compliance result (REVIEW / BLOCKING)
        +
Verified audit artifact (SHA-256 hash + Ed25519 signatures)
```

## What This Proves

> **"The official MCP Inspector, an independent open-source agent, and an independent MCP client each connected to the public DocTrust MCP implementation through standard MCP stdio. All three obtained results from the same pinned public DocTrust revision, without Hermes."**

## Prerequisites

| Prerequisite | Version | Install |
|---|---|---|
| Go | matching DocTrust's `go.mod` | https://go.dev/dl/ |
| Node.js | >= 22.19.0 | https://nodejs.org/ |
| Git | any recent | https://git-scm.com/ |
| **Goose** | **v1.48.0** | `curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh \| bash` |

Verify Goose is installed:

```bash
goose --version
```

### Why Goose v1.48.0?

Goose is the independent agent that demonstrates MCP interoperability. The exact version is pinned because:
- Config syntax varies between versions
- The video must be reproducible
- The `--with-extension` flag syntax is version-specific

## Quick Start

```bash
git clone https://github.com/PithomLabs/doctrust-mcp-proof
cd doctrust-mcp-proof

# 1. Clone DocTrust and build everything
./scripts/setup.sh

# 2. Run the full demo sequence (automated tests)
./scripts/run-all.sh

# 3. For the video, run each step interactively:
./scripts/run-inspector.sh        # Opens Inspector web UI
./scripts/run-goose.sh            # Opens Goose interactively
./scripts/run-deterministic.sh    # Five-tool MCP proof
./scripts/verify-result.sh        # Audit verification
```

## Manual Steps

```bash
# Deterministic MCP client (five-tool proof)
./scripts/run-deterministic.sh

# Inspector — web UI (for video)
./scripts/run-inspector.sh

# Inspector — CLI (for testing)
./scripts/run-inspector.sh --cli

# Goose — interactive (for video)
./scripts/run-goose.sh

# Goose — automated (for testing)
./scripts/run-goose.sh --auto

# Audit verification
./scripts/verify-result.sh

# Conformance Suite (documented as unsupported for stdio)
./scripts/run-conformance.sh
```

## Version Pins

| Component | Version | Status | Source |
|---|---|---|---|
| DocTrust | `29961d6` | Pinned commit | `scripts/setup.sh` as `DOCTRUST_REF` |
| Go MCP SDK | v1.7.0 | DocTrust dependency | `go.mod` in DocTrust |
| Goose | **v1.48.0** | Verified | https://github.com/aaif-goose/goose/releases |
| MCP Inspector | **v2.4.0** | Verified | `@modelcontextprotocol/inspector` npm |
| MCP Conformance | 0.1.16 | **Unsupported** | Does not support stdio transport |

### Conformance Suite Status

The official MCP Conformance Suite (`@modelcontextprotocol/conformance` v0.1.16) does not support stdio transport. It only supports HTTP (Streamable HTTP). DocTrust uses stdio.

- GitHub issue: [#258 — Add support for stdio testing](https://github.com/modelcontextprotocol/conformance/issues/258) (still open)
- The Conformance Suite is **not included** in the primary video sequence
- The primary interoperability evidence is Inspector + Goose + deterministic client

## Architecture

Each client, once verified, launches its own DocTrust process through standard MCP stdio. There is no shared background server.

```
MCP Inspector        Goose         Deterministic Client
     |                  |                  |
     | spawns           | spawns           | spawns
     v                  v                  v
DocTrust           DocTrust           DocTrust
(stdio)            (stdio)            (stdio)
     |                  |                  |
     v                  v                  v
Tool discovery     Natural-language    tools/list
Schema inspection  compliance request  get_ruleset
Direct tool call   evaluate_case       evaluate_case
                   human result        get_findings
                                       get_evidence
                                       get_audit_artifact
                                             |
                                             v
                                       verify-audit
```

### Snapshot Root Requirement

DocTrust resolves `reviewers/owner.pub` and audit artifact sidecars relative to the `--snapshot-root` directory. For the anomaly fixture, this must be:

```
DOCTRUST_SNAPSHOT_ROOT=<path-to-docTrust>/demo/shipment_release
```

Not the repo root. This is because the reviewers ring is at `demo/shipment_release/reviewers/owner.pub`, not at the repo root.

The scripts derive this path automatically. If you use a custom DocTrust checkout location, set `DOCTRUST_DIR`:

```bash
DOCTRUST_DIR=/path/to/your/doctrust ./scripts/run-all.sh
```

## Fixture

**Primary:** `demo/shipment_release/publication-verification/p6-20260825-012014-676181/available/`

| Field | Value |
|---|---|
| case_id | `5f48ac09e214462a` |
| Status | **REVIEW / BLOCKING** |
| Finding 0 | `required_shipment_documents` — PASS (all 4 documents present) |
| Finding 1 | `gross_weight_reconciliation` — **REVIEW / BLOCKING** |
| Mismatch | bill_of_lading = **5,150 KG** vs others = **4,650 KG** |
| Outlier | `bill_of_lading` (10.7% discrepancy) |
| Human review | Present — "HOLD - gross weight mismatch vs corroborating documents" |

### Important caveat

Despite living under `fixtures/pass/`, `fixtures/pass/evidence_snapshot.json` produces **REVIEW / BLOCKING** (only 2 of 4 documents). The true PASS case is `fixtures/pass/evidence_snapshot_extended.json`.

## What Each Component Proves

| Component | Claim |
|---|---|
| MCP Inspector (web UI) | Visual protocol and tool-discovery proof |
| Goose (interactive) | Independent agent interoperability proof |
| Deterministic MCP client | Complete tools/list + 5 DocTrust tools invocation proof |
| verify-audit / verify-ruleset | DocTrust artifact and integrity proof |

Do not use one component as evidence for another's claim.

## What This Project Does NOT Build

- ~~New DocTrust features~~
- ~~New compliance domains~~
- ~~LLM policy authoring~~
- ~~Second EvidenceProvider~~
- ~~New document benchmark or dataset~~
- ~~stdio-to-HTTP proxy~~
- ~~Docker configuration~~
- ~~Modified DocTrust fixtures~~
- ~~Hermes integration~~
- ~~Credential management~~
- ~~Shared background server process~~

## Directory Structure

```
doctrust-mcp-proof/
├── README.md
├── .gitignore
├── config/
│   └── goose.yaml              # Goose MCP extension config (template)
├── scripts/
│   ├── setup.sh                # Clone + build DocTrust
│   ├── run-deterministic.sh    # Five-tool MCP integration test
│   ├── run-inspector.sh        # MCP Inspector (web UI or CLI)
│   ├── run-goose.sh            # Goose agent (interactive or automated)
│   ├── run-conformance.sh      # Conformance Suite (unsupported, documented)
│   ├── verify-result.sh        # Audit verification
│   └── run-all.sh              # Full demo sequence
├── deterministic/
│   ├── client.go               # Thin MCP client (no DocTrust logic)
│   ├── client_test.go          # Unit tests
│   ├── go.mod
│   └── go.sum
├── evidence/                   # Captured demo outputs
│   ├── inspector/
│   ├── conformance/
│   ├── goose/
│   ├── deterministic/
│   └── audit/
└── docs/
    └── demo-script.md          # Video recording guide
```
