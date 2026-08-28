# Demo Script — Video Recording Guide

This document provides a step-by-step guide for recording the second DocTrust video demo.

**Objective:** Prove that DocTrust is a real MCP server that independent software can consume.

**Duration:** 2-3 minutes

**Narrative arc:**
> Video 1 proved what DocTrust does. Video 2 proves that DocTrust is actually an MCP product that independent software can consume.

---

## Pre-Recording Checklist

- [ ] DocTrust built from public GitHub at pinned commit (`29961d6`)
- [ ] All scripts tested and working
- [ ] Terminal windows arranged
- [ ] Goose v1.48.0 installed (`goose --version`)
- [ ] Node.js >= 22.19.0 installed (`node --version`)
- [ ] No Hermes process running (`pgrep hermes` returns nothing)
- [ ] Screen recording software ready

---

## Scene 1 — Show DocTrust Source (15 seconds)

**Terminal** — show the build:

```bash
git clone https://github.com/PithomLabs/doctrust
cd doctrust
git checkout 29961d6  # pinned commit
make mcp
```

**Voiceover:**
> "This is the public DocTrust repository, checked out at a specific commit. We're building the MCP server binary."

**What to capture:**
- `git clone` output
- `make mcp` build output
- `bin/doctrust-mcp` binary exists

---

## Scene 2 — MCP Inspector: Tool Discovery (30 seconds)

**Browser** — launch Inspector web UI:

```bash
./scripts/run-inspector.sh
```

Inspector opens in browser. The Inspector spawns its own DocTrust stdio process.

**Voiceover:**
> "We connect the official MCP Inspector to DocTrust. The Inspector discovers five tools through the MCP protocol."

**What to capture:**
- Inspector browser window opens
- 5 tools visible in the tool list
- Tool names: evaluate_case, get_findings, get_evidence, get_ruleset, get_audit_artifact

**Key moment:** The tool list appearing in Inspector is the visual proof of MCP discovery.

---

## Scene 3 — MCP Inspector: Schema and Invocation (30 seconds)

**Browser** — still in Inspector:

**Voiceover:**
> "We inspect the evaluate_case schema and make a real invocation."

**What to capture:**
- Click `evaluate_case` — show the JSON schema (snapshot_path parameter)
- Enter the anomaly snapshot path: `publication-verification/p6-20260825-012014-676181/available/evidence_snapshot.json`
- Click "Run" or "Invoke"
- Show the result: REVIEW/BLOCKING

**Key moment:** A real tool invocation through the official MCP Inspector.

---

## Scene 4 — Goose: Interactive Agent (30 seconds)

**Terminal** — launch Goose interactively:

```bash
./scripts/run-goose.sh
```

Goose opens. The user visibly types the request.

**Voiceover:**
> "Now we launch Goose, an independent open-source agent. It has never seen our code. We ask it to evaluate a shipment case."

**What to capture:**
- Goose terminal opens
- User types: "Evaluate the shipment case at .../evidence_snapshot.json and report any compliance findings"
- Goose begins processing

**Key moment:** The user typing the request into an independent agent.

---

## Scene 5 — Goose: Compliance Result (30 seconds)

**Terminal** — still in Goose:

**Voiceover:**
> "Goose discovers the DocTrust tools, invokes evaluate_case, and returns the real compliance result."

**What to capture:**
- Goose shows tool calls (evaluate_case, possibly others — order is not deterministic)
- Goose reports: **REVIEW / BLOCKING**
- Gross-weight mismatch: **5,150 KG vs 4,650 KG**
- bill_of_lading identified as outlier

**Key moment:** The human-readable compliance result from an independent agent.

**Note:** Goose's tool-call order is not deterministic. It may call get_ruleset first, or go directly to evaluate_case. This is expected — the claim is agent interoperability, not exact tool sequence.

---

## Scene 5b — Goose: MCP Verification (15 seconds)

**Terminal** — after the interactive Goose session:

**Voiceover:**
> "Now we run the forensic verification. The structured trace confirms Goose invoked DocTrust through MCP, not through shell access."

**What to capture:**

Run the forensic verification:
```bash
./scripts/run-goose.sh --auto
./scripts/verify-goose-mcp.sh
```

Show the output:
```
MCP extension connected:       YES
MCP tool invocations found:    YES (3 calls)
  - doctrust__get_ruleset
  - doctrust__evaluate_case
  - doctrust__get_findings
evaluate_case invoked:         YES
REVIEW/BLOCKING received:      YES
Shell execution observed:      NO
Independent interoperability:  PASS
```

**Key moment:** The machine-readable proof that the Goose interaction went through MCP.

**Note:** The interactive video run and this forensic run use the same canonical request against the same pinned DocTrust revision. The video demonstrates what happened; the structured trace proves how it happened.

---

## Scene 6 — Deterministic MCP Client (30 seconds)

**Terminal** — run the five-tool sequence:

```bash
./scripts/run-deterministic.sh
```

**Voiceover:**
> "For the complete proof, we run a deterministic client that exercises tools/list plus all five DocTrust tools through MCP."

**What to capture:**

```
=== tools/list ===
  Discovered 5 tools:
    - evaluate_case
    - get_findings
    - get_evidence
    - get_ruleset
    - get_audit_artifact

=== get_ruleset ===
  { "id": "shipment_release", "version": "1", ... }

=== evaluate_case ===
  { "case_id": "5f48ac09e214462a", "status": "REVIEW", ... }

=== get_findings ===
  { "findings": [{ "check_id": "gross_weight_reconciliation", "status": "REVIEW", ... }] }

=== get_evidence (finding 1) ===
  { "evidence": [{ "field": "shipment.gross_weight", ... }] }

=== get_audit_artifact ===
  { "artifact_hash": "sha256:...", "final_disposition": "FAIL" }
```

**Key moment:** All five tools returning real data through MCP.

---

## Scene 7 — Audit Verification (15 seconds)

**Terminal** — verify the artifact:

```bash
./scripts/verify-result.sh
```

**Voiceover:**
> "The audit artifact is verified using DocTrust's own verification tooling."

**What to capture:**
- `verify-ruleset: PASS`
- `verify-audit: PASS` (2 human reviews verified, artifact hash verified)

---

## Scene 8 — Closing Statement (15 seconds)

**Voiceover or text overlay:**

> "The official MCP Inspector, an independent open-source agent, and an independent MCP client each connected to the public DocTrust MCP implementation through standard MCP stdio. All three obtained results from the same pinned public DocTrust revision, without Hermes."

**End with:**

> "This run did not use Hermes."

---

## Post-Recording Checklist

- [ ] Evidence files captured in `evidence/` directory
- [ ] All version pins recorded in `evidence/versions.json`
- [ ] No fabricated data — all results are from real DocTrust evaluation
- [ ] No Hermes process was present during recording

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `doctrust-mcp` not found | Run `./scripts/setup.sh` first |
| Inspector doesn't open | Check Node.js version (>= 22.19.0); try `npx @modelcontextprotocol/inspector --cli` |
| Goose doesn't start | Verify `goose --version` shows v1.48.0 |
| Goose doesn't discover tools | Check that DocTrust binary works: `./bin/doctrust-mcp --help` |
| `verify-audit` fails | Ensure snapshot root is `demo/shipment_release/` (not repo root) |
| Go version mismatch | Read `go.mod` from DocTrust; install matching version |

---

## Credibility Claims

Each component proves exactly one thing. Do not cross-apply:

| Component | Proves |
|---|---|
| MCP Inspector (web UI) | Visual tool discovery and protocol interaction |
| Goose (interactive) | Independent agent interoperability |
| Deterministic MCP client | Complete tools/list + 5 DocTrust tools invocation |
| verify-audit / verify-ruleset | Integrity of DocTrust artifacts |
