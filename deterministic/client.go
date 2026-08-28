// Package main implements a thin deterministic MCP client that exercises all five
// DocTrust tools through standard MCP stdio. It does NOT reimplement any DocTrust
// logic — it only makes MCP calls and records what DocTrust returns.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func main() {
	doctrustBin := flag.String("doctrust-bin", "doctrust-mcp", "path to doctrust-mcp binary")
	snapshotRoot := flag.String("snapshot-root", "", "DocTrust snapshot root (absolute path)")
	domain := flag.String("domain", "shipment_release", "compliance domain")
	snapshotPath := flag.String("snapshot-path", "", "evidence snapshot path relative to snapshot-root")
	evidenceDir := flag.String("evidence-dir", "evidence/deterministic", "directory to write evidence files")
	rulesetsDir := flag.String("rulesets-dir", "", "path to rulesets directory (default: <snapshot-root>/rulesets)")
	flag.Parse()

	if *snapshotRoot == "" {
		log.Fatal("--snapshot-root is required")
	}
	if *snapshotPath == "" {
		log.Fatal("--snapshot-path is required")
	}

	// Resolve rulesets directory.
	rDir := *rulesetsDir
	if rDir == "" {
		rDir = filepath.Join(*snapshotRoot, "rulesets")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := os.MkdirAll(*evidenceDir, 0o755); err != nil {
		log.Fatalf("create evidence dir: %v", err)
	}

	// Build the command to spawn DocTrust via stdio.
	// Set Dir to snapshotRoot so DocTrust can find its rulesets/ directory.
	cmd := exec.CommandContext(ctx, *doctrustBin,
		"--domain", *domain,
		"--snapshot-root", *snapshotRoot,
		"--rulesets-dir", rDir,
	)
	cmd.Dir = *snapshotRoot

	client := mcp.NewClient(&mcp.Implementation{
		Name:    "doctrust-deterministic-client",
		Version: "v1.0.0",
	}, nil)

	transport := &mcp.CommandTransport{Command: cmd}
	session, err := client.Connect(ctx, transport, nil)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer session.Close()

	fmt.Println("=== MCP Connection ===")
	fmt.Printf("Connected to DocTrust via stdio\n")
	fmt.Printf("Domain: %s\n", *domain)
	fmt.Printf("Snapshot root: %s\n", *snapshotRoot)
	fmt.Printf("Snapshot path: %s\n", *snapshotPath)
	fmt.Println()

	// --- Step 1: tools/list ---
	fmt.Println("=== tools/list ===")
	toolsResult, err := session.ListTools(ctx, nil)
	if err != nil {
		log.Fatalf("ListTools: %v", err)
	}
	writeEvidence(*evidenceDir, "01_tools_list.json", toolsResult)
	fmt.Printf("Discovered %d tools:\n", len(toolsResult.Tools))
	for _, tool := range toolsResult.Tools {
		fmt.Printf("  - %s: %s\n", tool.Name, tool.Description)
	}
	fmt.Println()

	// --- Step 2: get_ruleset ---
	fmt.Println("=== get_ruleset ===")
	rulesetRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "get_ruleset",
	})
	if err != nil {
		log.Fatalf("CallTool(get_ruleset): %v", err)
	}
	writeToolResult(*evidenceDir, "02_get_ruleset.json", rulesetRes)
	printToolResult("get_ruleset", rulesetRes)
	fmt.Println()

	// --- Step 3: evaluate_case ---
	fmt.Println("=== evaluate_case ===")
	evalRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "evaluate_case",
		Arguments: map[string]any{
			"snapshot_path": *snapshotPath,
		},
	})
	if err != nil {
		log.Fatalf("CallTool(evaluate_case): %v", err)
	}
	writeToolResult(*evidenceDir, "03_evaluate_case.json", evalRes)
	printToolResult("evaluate_case", evalRes)

	// Extract case_id from evaluate_case result for subsequent calls.
	caseID := extractCaseID(evalRes)
	if caseID == "" {
		log.Fatal("could not extract case_id from evaluate_case result")
	}
	fmt.Printf("  case_id: %s\n", caseID)
	fmt.Println()

	// --- Step 4: get_findings ---
	fmt.Println("=== get_findings ===")
	findingsRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "get_findings",
		Arguments: map[string]any{
			"case_id": caseID,
		},
	})
	if err != nil {
		log.Fatalf("CallTool(get_findings): %v", err)
	}
	writeToolResult(*evidenceDir, "04_get_findings.json", findingsRes)
	printToolResult("get_findings", findingsRes)
	fmt.Println()

	// --- Step 5: get_evidence (for each finding) ---
	findingCount := extractFindingCount(findingsRes)
	for i := 0; i < findingCount; i++ {
		fmt.Printf("=== get_evidence (finding %d) ===\n", i)
		evidenceRes, err := session.CallTool(ctx, &mcp.CallToolParams{
			Name: "get_evidence",
			Arguments: map[string]any{
				"case_id":       caseID,
				"finding_index": i,
			},
		})
		if err != nil {
			log.Fatalf("CallTool(get_evidence, finding %d): %v", i, err)
		}
		writeToolResult(*evidenceDir, fmt.Sprintf("05_get_evidence_%d.json", i), evidenceRes)
		printToolResult(fmt.Sprintf("get_evidence[%d]", i), evidenceRes)
		fmt.Println()
	}

	// --- Step 6: get_audit_artifact ---
	fmt.Println("=== get_audit_artifact ===")
	auditRes, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "get_audit_artifact",
		Arguments: map[string]any{
			"case_id": caseID,
		},
	})
	if err != nil {
		log.Fatalf("CallTool(get_audit_artifact): %v", err)
	}
	writeToolResult(*evidenceDir, "06_get_audit_artifact.json", auditRes)
	printToolResult("get_audit_artifact", auditRes)
	fmt.Println()

	fmt.Println("=== Done ===")
	fmt.Printf("Evidence written to: %s\n", *evidenceDir)
}

// writeEvidence writes an arbitrary JSON-marshaled value to the evidence directory.
func writeEvidence(dir, filename string, v any) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		log.Printf("warning: marshal %s: %v", filename, err)
		return
	}
	path := filepath.Join(dir, filename)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		log.Printf("warning: write %s: %v", path, err)
	}
}

// writeToolResult extracts the text content from a CallToolResult and writes it.
func writeToolResult(dir, filename string, res *mcp.CallToolResult) {
	text := extractText(res)
	if text == "" {
		return
	}
	path := filepath.Join(dir, filename)
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		log.Printf("warning: write %s: %v", path, err)
	}
}

// extractText returns the text content from the first TextContent in the result.
func extractText(res *mcp.CallToolResult) string {
	if len(res.Content) == 0 {
		return ""
	}
	tc, ok := res.Content[0].(*mcp.TextContent)
	if !ok {
		return fmt.Sprintf("[unexpected content type: %T]", res.Content[0])
	}
	return tc.Text
}

// printToolResult prints a tool result in a readable format.
func printToolResult(name string, res *mcp.CallToolResult) {
	if res.IsError {
		fmt.Printf("  ERROR: %s\n", extractText(res))
		return
	}
	text := extractText(res)
	if text == "" {
		fmt.Printf("  (empty result)\n")
		return
	}
	// Pretty-print the JSON if possible.
	var pretty map[string]any
	if err := json.Unmarshal([]byte(text), &pretty); err == nil {
		data, _ := json.MarshalIndent(pretty, "  ", "  ")
		fmt.Printf("  %s\n", string(data))
	} else {
		fmt.Printf("  %s\n", text)
	}
}

// extractCaseID extracts the case_id field from a tool result's text content.
func extractCaseID(res *mcp.CallToolResult) string {
	text := extractText(res)
	var out struct {
		CaseID string `json:"case_id"`
	}
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		return ""
	}
	return out.CaseID
}

// extractFindingCount extracts the number of findings from a get_findings result.
func extractFindingCount(res *mcp.CallToolResult) int {
	text := extractText(res)
	var out struct {
		Findings []json.RawMessage `json:"findings"`
	}
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		return 0
	}
	return len(out.Findings)
}
