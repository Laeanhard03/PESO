package main

import (
	"reflect"
	"strings"
	"testing"
)

func TestProtectedAgeGenderVariantsNeverInfluenceModel(t *testing.T) {
	baseline := Job{
		ID: "verified-role", Title: "Sales Associate — Example", Company: "Example",
		AiListingKind: "role", RequirementScope: "explicit_role", SourceRoleCount: 2,
		SourceURL:    "https://montalban.gov.ph/sample.pdf",
		Requirements: []string{"Sales Associate: Required communication skills", "Driver: Must hold driver's license"},
	}
	a := Applicant{Skills: []string{"communication"}, EducationLevel: "Bachelor's Degree", YearsExperience: 3}
	weights := make([]float64, len(featureNames))
	for i := range weights {
		weights[i] = float64(i+1) / 20
	}
	m := Model{Version: "test-trained-model", Features: featureNames, Weights: weights, Threshold: 0.5}
	baseFeatures, _, _, _, _ := features(a, baseline)
	baseLabel, _ := rubric(a, baseline)
	baseResult := predictOne(m, a, baseline)
	variants := []string{
		"MALE NOT MORE THAN 35 YRS OLD.",
		"FEMALE NOT MORE THAN 35 YRS. OLD.",
		"Male Applicant", "Female applicant only", "M/F",
		"Preferred gender: woman", "Sex: male", "Marital status: single",
		"Must be aged 21 to 35", "Applicant must be at least 18 years old",
		"ONLY 25 YEARS OLD", "Below age 40", "Religion: any",
	}
	for _, phrase := range variants {
		t.Run(phrase, func(t *testing.T) {
			j := baseline
			j.Requirements = append(append([]string{}, baseline.Requirements...), phrase)
			gotFeatures, _, _, _, _ := features(a, j)
			gotLabel, _ := rubric(a, j)
			gotResult := predictOne(m, a, j)
			if !reflect.DeepEqual(gotFeatures, baseFeatures) || gotLabel != baseLabel {
				t.Fatalf("protected phrase contaminated features/labels: %q", phrase)
			}
			if gotResult.Score != baseResult.Score || gotResult.Confidence != baseResult.Confidence ||
				gotResult.Readiness != baseResult.Readiness || !reflect.DeepEqual(gotResult.MissingMandatory, baseResult.MissingMandatory) {
				t.Fatalf("protected phrase contaminated score/confidence/readiness: %q", phrase)
			}
			if len(gotResult.ExcludedRequirements) != 1 || gotResult.ExcludedRequirements[0] != phrase {
				t.Fatalf("protected phrase not excluded with provenance: %+v", gotResult.ExcludedRequirements)
			}
			if !strings.Contains(strings.Join(gotResult.NeedsReview, " "), "excluded") {
				t.Fatalf("human review was not signaled for %q", phrase)
			}
		})
	}
}

func TestMultiRoleAttributionAndLegitimateRequirements(t *testing.T) {
	a := Job{Title: "Sales Associate — Example", AiListingKind: "role", RequirementScope: "explicit_role", SourceRoleCount: 2,
		Requirements: []string{
			"Sales Associate: Required sales and customer service",
			"Driver: Must have driver's license", "WITH 2 YEARS OF EXPERIENCE",
			"MALE NOT MORE THAN 35 YRS OLD.",
		},
	}
	accepted, excluded, unattributed := reviewedRequirements(a)
	if !reflect.DeepEqual(accepted, []string{"Required sales and customer service"}) ||
		len(excluded) != 1 || len(unattributed) != 2 {
		t.Fatalf("cross-role/ambiguous qualification was accepted: %v %v %v", accepted, excluded, unattributed)
	}
	inferred := inferredJob(a)
	if !reflect.DeepEqual(inferred.RequiredSkills, []string{"customer_service", "sales"}) ||
		len(inferred.RequiredLicenses) != 0 {
		t.Fatalf("unrelated driver's license leaked into Sales role: %+v", inferred)
	}
	legacy := a
	legacy.RequirementScope = ""
	legacy.Requirements = []string{"Must have driver's license", "At least high school graduate"}
	accepted, _, _ = reviewedRequirements(legacy)
	if len(accepted) != 0 {
		t.Fatalf("unscoped legacy notice qualifications must not be mandatory: %v", accepted)
	}
	one := Job{Title: "Driver — Example", AiListingKind: "role", RequirementScope: "single_role", SourceRoleCount: 1,
		Requirements: []string{"Must hold driver's license", "At least high school graduate", "At least 2 years driving experience"}}
	ok := safeRequirements(one)
	if len(ok) != 3 || !reflect.DeepEqual(inferredJob(one).RequiredLicenses, []string{"driver_license"}) {
		t.Fatalf("legitimate single-role requirements were suppressed: %v", ok)
	}
}

func TestMirrorIdentityIndependentOfSourceIDAndUrlHost(t *testing.T) {
	a := Job{Title: "Driver — Example Corp", Company: "Example Corp",
		PublicPdfSourceID: "montalban-walk-in-official", SourceFingerprint: "official-id",
		ParentFingerprint: "official-parent", SourcePageStart: 8, SourcePageEnd: 8,
		SourceURL: "https://montalban.gov.ph/wp-content/uploads/2020/07/RECRUITMENT.PDF"}
	b := a
	b.SourceURL = "http://dev.montalban.gov.ph/wp-content/uploads/2020/07/recruitment.pdf?version=999"
	b.PublicPdfSourceID = "montalban-walk-in-development"
	b.SourceFingerprint = "mirror-id"
	b.ParentFingerprint = "mirror-parent"
	if roleFamily(a) != roleFamily(b) || roleTemplateIdentity(a) != roleTemplateIdentity(b) ||
		hashSplit(roleFamily(a), 20261020) != hashSplit(roleFamily(b), 20261020) {
		t.Fatal("official and development mirrors should be assigned the exact same split family")
	}
}

func TestTrainRejectsCrossSplitFamilyOrApplicant(t *testing.T) {
	for _, kind := range []string{"family", "applicant"} {
		pairs := []Pair{
			{ApplicantID: "app-a", JobFamily: "canonical-notice", Split: "train"},
			{ApplicantID: "app-b", JobFamily: "different-notice", Split: "test"},
		}
		if kind == "family" {
			pairs[1].JobFamily = pairs[0].JobFamily
		}
		if kind == "applicant" {
			pairs[1].ApplicantID = pairs[0].ApplicantID
		}
		if _, _, err := trainEval(pairs, 42); err == nil || !strings.Contains(err.Error(), "leakage") {
			t.Fatalf("expected %s split leakage rejection, got %v", kind, err)
		}
	}
}

func TestConfidenceAcrossUnrelatedRealJobFamilies(t *testing.T) {
	m := Model{Version: "test", Features: featureNames, Weights: make([]float64, len(featureNames)), Threshold: 0.5}
	cases := []struct{ title, requirement, skill string }{
		{"Welder", "Welder: Required welding skills", "welding"},
		{"Sales Associate", "Sales Associate: Required sales skills", "sales"},
		{"Office Clerk", "Office Clerk: Must know MS Office", "MS Office"},
		{"Driver", "Driver: Must have driving experience", "driving"},
		{"Nurse", "Nurse: Required patient care skills", "patient care"},
		{"Teacher", "Teacher: Required teaching experience", "teaching"},
		{"Programmer", "Programmer: Must know programming", "programming"},
		{"Safety Officer", "Safety Officer: Required occupational safety training", "occupational safety"},
	}
	for _, tc := range cases {
		t.Run(tc.title, func(t *testing.T) {
			a := Applicant{Skills: []string{tc.skill}, EducationLevel: "Bachelor's Degree", YearsExperience: 2}
			j := Job{ID: "verified", Title: tc.title, AiListingKind: "role",
				RequirementScope: "explicit_role", SourceRoleCount: 2,
				Requirements: []string{tc.requirement},
				SourceURL:    "https://example.org/official-notice.pdf"}
			got := predictOne(m, a, j)
			if got.Confidence == "low" {
				t.Fatalf("verified %s role with applicant evidence was incorrectly suppressed: %+v", tc.title, got)
			}
			unverified := j
			unverified.RequirementScope = ""
			unverified.Requirements = []string{"General qualifications to be confirmed"}
			if x := predictOne(m, a, unverified); x.Confidence != "low" {
				t.Fatalf("unverified role requirements must not produce confident alignment: %+v", x)
			}
			blank := predictOne(m, Applicant{Incomplete: true}, j)
			if blank.Confidence != "low" {
				t.Fatalf("empty applicant cannot yield confident alignment: %+v", blank)
			}
		})
	}
}

func TestProtectedCompositePreservesOnlySeparatedQualifications(t *testing.T) {
	model := Model{Version: "test", Features: featureNames,
		Weights: make([]float64, len(featureNames)), Threshold: 0.5}
	examples := []struct {
		title, demographicLine string
		clean                  []string
		skills                 []string
	}{
		{
			title:           "Branch Manager",
			demographicLine: "Branch Manager: Male or Female Applicant, Graduate of any 4-year course, With supervisory and sales experience",
			clean:           []string{"Branch Manager: Graduate of any 4-year course", "Branch Manager: With supervisory and sales experience"},
			skills:          []string{"supervision", "sales"},
		},
		{
			title:           "Field Collector",
			demographicLine: "Field Collector: Male Applicant; At least High School Graduate; Must have a Professional Driver's License; Required collections skills",
			clean:           []string{"Field Collector: At least High School Graduate", "Field Collector: Must have a Professional Driver's License", "Field Collector: Required collections skills"},
			skills:          []string{"collections", "driving"},
		},
	}
	for _, tc := range examples {
		t.Run(tc.title, func(t *testing.T) {
			role := Job{ID: "composite", Title: tc.title + " — Example", AiListingKind: "role",
				RequirementScope: "explicit_role", SourceRoleCount: 3,
				Requirements: []string{tc.demographicLine}}
			control := role
			control.Requirements = tc.clean
			safe, excluded, _ := reviewedRequirements(role)
			controlSafe, _, _ := reviewedRequirements(control)
			if !reflect.DeepEqual(safe, controlSafe) {
				t.Fatalf("legitimate clauses were not retained: %v != %v", safe, controlSafe)
			}
			if len(excluded) != 1 || !protectedRequirement(excluded[0]) {
				t.Fatalf("demographic clause must be excluded independently: %v", excluded)
			}
			a := Applicant{Skills: tc.skills, EducationLevel: "Bachelor's degree", YearsExperience: 3}
			f1, _, _, _, _ := features(a, role)
			f2, _, _, _, _ := features(a, control)
			if !reflect.DeepEqual(f1, f2) {
				t.Fatalf("demographic fragment changed machine-learning features: %v vs %v", f1, f2)
			}
			got, baseline := predictOne(model, a, role), predictOne(model, a, control)
			if got.Score != baseline.Score || got.Confidence != baseline.Confidence ||
				got.Readiness != baseline.Readiness ||
				!reflect.DeepEqual(got.MissingMandatory, baseline.MissingMandatory) {
				t.Fatalf("demographic fragment changed evaluation")
			}
		})
	}
	unsplittable := Job{Title: "Driver — Example", AiListingKind: "role",
		RequirementScope: "explicit_role", SourceRoleCount: 2,
		Requirements: []string{"Driver: Male applicant must have a driver's license"}}
	safe, excluded, _ := reviewedRequirements(unsplittable)
	if len(safe) != 0 || len(excluded) != 1 {
		t.Fatalf("unseparated demographics and qualifications must fail closed: %v, %v", safe, excluded)
	}
}

func TestTitleOnlyGuidanceIsNotPromotedToMandatoryRequirements(t *testing.T) {
	m := Model{Version: "test", Features: featureNames, Weights: make([]float64, len(featureNames)), Threshold: 0.5}
	job := Job{ID: "title-only", Title: "Safety Officer — Example",
		AiListingKind: "role", RequirementScope: "unattributed_notice", SourceRoleCount: 4,
		Requirements: []string{"General notice qualification is not attributed to the role"}}
	a := Applicant{Skills: []string{"occupational safety"}, EducationLevel: "Senior High School"}
	got := predictOne(m, a, job)
	if got.AssessmentBasis != "job_title_clues_only" || got.Confidence != "low" {
		t.Fatalf("unattributed criteria cannot support numerical confidence: %+v", got)
	}
	if !reflect.DeepEqual(got.MatchedTitleClues, []string{"safety"}) ||
		len(got.MissingMandatory) > 0 || got.RoleCriteriaCount != 0 {
		t.Fatalf("title clues must not become mandatory gaps: %+v", got)
	}
	other := predictOne(m, a, Job{ID: "unknown", Title: "Unfamiliar Specialist", AiListingKind: "role"})
	if other.AssessmentBasis != "job_details_unverified" ||
		len(other.MatchedTitleClues)+len(other.SkillsToExplore) != 0 || other.Confidence != "low" {
		t.Fatalf("unrecognized job must remain explicit about missing evidence: %+v", other)
	}
}
