package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testPairs(t *testing.T, rows ...pair) string {
	t.Helper()
	location := filepath.Join(t.TempDir(), "pairs.jsonl")
	f, e := os.Create(location)
	if e != nil {
		t.Fatal(e)
	}
	for _, row := range rows {
		line, e := json.Marshal(row)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = f.Write(append(line, '\n')); e != nil {
			t.Fatal(e)
		}
	}
	if e = f.Close(); e != nil {
		t.Fatal(e)
	}
	return location
}
func TestRejectCrossSplitApplicantAndSourceFamily(t *testing.T) {
	a := pair{ApplicantID: "a", JobFamily: "familyA", Split: "train", Target: 1, Features: []float64{1}, IsSynthetic: true}
	b := pair{ApplicantID: "a", JobFamily: "familyB", Split: "test", Target: 1, Features: []float64{1}, IsSynthetic: true}
	if _, _, e := loadPairs(testPairs(t, a, b)); e == nil || !strings.Contains(e.Error(), "applicant") {
		t.Fatalf("expected applicant leakage, got %v", e)
	}
	b.ApplicantID = "b"
	b.JobFamily = "familyA"
	if _, _, e := loadPairs(testPairs(t, a, b)); e == nil || !strings.Contains(e.Error(), "family") {
		t.Fatalf("expected family leakage, got %v", e)
	}
}
func TestRejectNonSyntheticUnreviewedLabels(t *testing.T) {
	row := pair{ApplicantID: "private", JobFamily: "family", Split: "test", Target: 1, Features: []float64{1}, IsSynthetic: false}
	if _, _, e := loadPairs(testPairs(t, row)); e == nil || !strings.Contains(e.Error(), "human-review") {
		t.Fatalf("expected source label gate, got %v", e)
	}
}
func TestHeldOutEvaluationKeepsUncertainSeparate(t *testing.T) {
	m := model{Version: "fixture", Features: []string{"coverage"}, Weights: []float64{5}, Bias: -2, Threshold: 0.5}
	all := []pair{
		{ApplicantID: "a", JobFamily: "f", Split: "test", Target: 1, Features: []float64{1}, IsSynthetic: true},
		{ApplicantID: "a", JobFamily: "f", Split: "test", Target: 0, Features: []float64{0}, IsSynthetic: true},
		{ApplicantID: "a", JobFamily: "f", Split: "test", Target: -1, Features: []float64{0.5}, IsSynthetic: true},
	}
	score, e := evaluate(m, all)
	if e != nil {
		t.Fatal(e)
	}
	if score.Evaluated != 2 || score.UncertainSkipped != 1 || score.F1 != 1 || score.RankingGroups != 1 || score.SyntheticNDCG5 != 1 {
		t.Fatalf("unexpected heldout audit %+v", score)
	}
}
