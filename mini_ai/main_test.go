package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRoleSpecificRequirementsAndProtected(t *testing.T) {
	j := Job{Title: "Sales Associate — Example", AiListingKind: "role",
		Requirements: []string{"Sales Associate: Good communication and selling skills", "Driver: With Driver's License", "Sales Associate: Male Applicant", "Role-specific qualifications differ; consult source PDF."}}
	req := safeRequirements(j)
	if len(req) != 1 || req[0] != "Good communication and selling skills" {
		t.Fatalf("role/protected filtering failed: %v", req)
	}
}
func TestEvidenceDoesNotMakeSourceTitleMandatory(t *testing.T) {
	j := inferredJob(Job{Title: "Driver — Example", AiListingKind: "role",
		Requirements: []string{"Male applicant", "Confirm current availability, location, schedule and requirements with PESO Montalban before applying."}})
	if len(j.RequiredSkills) > 0 || len(j.RequiredLicenses) > 0 {
		t.Fatalf("unverified requirement invented: %+v", j)
	}
}
func TestLearnedParametersAndInference(t *testing.T) {
	pairs := []Pair{}
	for i := 0; i < 200; i++ {
		yes := i%2 == 0
		x := []float64{0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0}
		if yes {
			x = []float64{1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1}
		}
		target := 0
		if yes {
			target = 1
		}
		pairs = append(pairs, Pair{Features: x, Target: target, Split: "train"})
	}
	m := fit(pairs, 42, 30)
	if len(m.Weights) != len(featureNames) || modelProb(m, pairs[0].Features) <= modelProb(m, pairs[1].Features) {
		t.Fatal("model did not learn")
	}
	a := Applicant{Skills: []string{"Sales", "Good communication"}, EducationLevel: "Bachelor's Degree", YearsExperience: 2}
	j := Job{ID: "j1", IsSynthetic: true, RequiredSkills: []string{"sales", "communication"}, Title: "Sales Associate"}
	got := predictOne(m, a, j)
	if len(got.MatchedSkills) != 2 || len(got.MissingMandatory) != 0 {
		t.Fatalf("invalid explanation: %+v", got)
	}
}
func TestDatasetReproducibleAndSplitIsolated(t *testing.T) {
	fixture := Snapshot{SchemaVersion: 1}
	for i := 0; i < 100; i++ {
		fixture.Records = append(fixture.Records, Job{ID: "s", SourceFingerprint: "template-" + string(rune(65+i)),
			ParentFingerprint: "family-" + string(rune(65+i)), PublicPdfSourceID: "montalban-walk-in-official",
			Title: "Sales Associate — Example", Company: "Example", SourceURL: "https://montalban.gov.ph/sample.pdf",
			SourcePageStart: i + 1, SourcePageEnd: i + 1,
			AiListingKind: "role", Category: "walk_in_application",
			Requirements: []string{"Sales Associate: Good selling skills"}})
	}
	fixture.Records = append(fixture.Records, Job{ID: "mirror-copy", SourceFingerprint: "different-mirror-fingerprint",
		ParentFingerprint: "different-source-notice", PublicPdfSourceID: "montalban-walk-in-development",
		Title: "Sales Associate — Example", Company: "Example",
		SourceURL: "https://dev.montalban.gov.ph/sample.pdf?cache=1", SourcePageStart: 1, SourcePageEnd: 1,
		AiListingKind: "role", Category: "walk_in_application",
		Requirements: []string{"Sales Associate: Good selling skills"}})
	dir := t.TempDir()
	src := filepath.Join(dir, "sources.json")
	if err := saveJSON(src, fixture); err != nil {
		t.Fatal(err)
	}
	m, err := generateData(src, filepath.Join(dir, "dataset"), 42, 200, 400, 1000, 0.2)
	if err != nil {
		t.Fatal(err)
	}
	if m.Pairs != 1000 || m.Jobs != 200 || m.LeakageCheck == "" ||
		m.SourceJobs != 101 || m.UniqueSourceRoles != 100 || m.DeduplicatedSourceRoles != 1 {
		t.Fatalf("invalid manifest %+v", m)
	}
	data, err := os.ReadFile(filepath.Join(dir, "dataset", "synthetic_pairs_v1.jsonl"))
	if err != nil || len(data) == 0 {
		t.Fatal("missing pairs")
	}
}
