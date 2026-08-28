package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func TestExtractText_TextContent(t *testing.T) {
	res := &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: `{"status":"REVIEW"}`},
		},
	}
	got := extractText(res)
	if got != `{"status":"REVIEW"}` {
		t.Fatalf("extractText = %q, want %q", got, `{"status":"REVIEW"}`)
	}
}

func TestExtractText_Empty(t *testing.T) {
	res := &mcp.CallToolResult{}
	got := extractText(res)
	if got != "" {
		t.Fatalf("extractText = %q, want empty", got)
	}
}

func TestExtractCaseID(t *testing.T) {
	res := &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: `{"case_id":"shipment_e067246b18486d8b","status":"REVIEW"}`},
		},
	}
	got := extractCaseID(res)
	if got != "shipment_e067246b18486d8b" {
		t.Fatalf("extractCaseID = %q, want %q", got, "shipment_e067246b18486d8b")
	}
}

func TestExtractCaseID_Empty(t *testing.T) {
	res := &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: `{"status":"REVIEW"}`},
		},
	}
	got := extractCaseID(res)
	if got != "" {
		t.Fatalf("extractCaseID = %q, want empty", got)
	}
}

func TestExtractFindingCount(t *testing.T) {
	res := &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: `{"findings":[{"index":0},{"index":1}]}`},
		},
	}
	got := extractFindingCount(res)
	if got != 2 {
		t.Fatalf("extractFindingCount = %d, want 2", got)
	}
}

func TestExtractFindingCount_Empty(t *testing.T) {
	res := &mcp.CallToolResult{}
	got := extractFindingCount(res)
	if got != 0 {
		t.Fatalf("extractFindingCount = %d, want 0", got)
	}
}

func TestWriteEvidence(t *testing.T) {
	dir := t.TempDir()
	data := map[string]any{"test": true}
	writeEvidence(dir, "test.json", data)

	path := filepath.Join(dir, "test.json")
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read evidence file: %v", err)
	}

	var got map[string]any
	if err := json.Unmarshal(content, &got); err != nil {
		t.Fatalf("parse evidence file: %v", err)
	}
	if got["test"] != true {
		t.Fatalf("evidence content = %v, want test=true", got)
	}
}

func TestPrintToolResult_Error(t *testing.T) {
	res := &mcp.CallToolResult{
		IsError: true,
		Content: []mcp.Content{
			&mcp.TextContent{Text: "something went wrong"},
		},
	}
	// Should not panic.
	printToolResult("test_tool", res)
}

func TestPrintToolResult_NilContent(t *testing.T) {
	res := &mcp.CallToolResult{}
	// Should not panic.
	printToolResult("test_tool", res)
}
