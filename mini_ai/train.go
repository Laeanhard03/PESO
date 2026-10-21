package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"math/rand"
	"os"
	"sort"
	"strings"
	"time"
)

type Model struct {
	Version           string    `json:"version"`
	Seed              int64     `json:"seed"`
	TrainedAt         string    `json:"trainedAt"`
	Features          []string  `json:"features"`
	Weights           []float64 `json:"weights"`
	Bias              float64   `json:"bias"`
	Threshold         float64   `json:"threshold"`
	TrainedPairs      int       `json:"trainedPairs"`
	Source            string    `json:"source"`
	OccupationWeights []float64 `json:"occupationWeights,omitempty"`
	OccupationBias    float64   `json:"occupationBias,omitempty"`
}
type Metrics struct {
	Count            int     `json:"count"`
	TruePositive     int     `json:"tp"`
	FalsePositive    int     `json:"fp"`
	TrueNegative     int     `json:"tn"`
	FalseNegative    int     `json:"fn"`
	Precision        float64 `json:"precision"`
	Recall           float64 `json:"recall"`
	F1               float64 `json:"f1"`
	Accuracy         float64 `json:"accuracy"`
	UncertainSkipped int     `json:"uncertainSkipped"`
}
type Evaluation struct {
	Version                   string             `json:"version"`
	BaselineValidation        Metrics            `json:"baselineValidation"`
	BaselineTest              Metrics            `json:"baselineTest"`
	LearnedTraining           Metrics            `json:"learnedTraining"`
	LearnedValidation         Metrics            `json:"learnedValidation"`
	LearnedTest               Metrics            `json:"learnedTest"`
	ByCategory                map[string]Metrics `json:"byCategory"`
	LearningCurve             []map[string]any   `json:"learningCurve"`
	FalsePositiveExamples     []string           `json:"falsePositiveExamples"`
	FalseNegativeExamples     []string           `json:"falseNegativeExamples"`
	InferenceMeanMicroseconds float64            `json:"inferenceMeanMicroseconds"`
	ModelBytes                int                `json:"modelBytes"`
	DataLimitations           []string           `json:"dataLimitations"`
	LeakageAudit              map[string]int     `json:"leakageAudit"`
}

func sigmoid(v float64) float64 {
	if v > 30 {
		return 1
	}
	if v < -30 {
		return 0
	}
	return 1 / (1 + math.Exp(-v))
}
func modelProb(m Model, x []float64) float64 {
	z := m.Bias
	for i, v := range x {
		if i < len(m.Weights) {
			z += m.Weights[i] * v
		}
	}
	return sigmoid(z)
}
func baselineProb(x []float64) float64 {
	// Intentionally basic, transparent qualification coverage comparator.
	if len(x) < 11 {
		return 0
	}
	return 0.45*x[0] + 0.20*x[1] + 0.15*x[3] + 0.10*x[4] + 0.10*x[5] - 0.30*x[2]
}
func scored(rows []Pair, predict func([]float64) bool) Metrics {
	m := Metrics{}
	for _, p := range rows {
		if p.Target < 0 {
			m.UncertainSkipped++
			continue
		}
		m.Count++
		yes := predict(p.Features)
		if yes && p.Target == 1 {
			m.TruePositive++
		} else if yes {
			m.FalsePositive++
		} else if p.Target == 1 {
			m.FalseNegative++
		} else {
			m.TrueNegative++
		}
	}
	if m.TruePositive+m.FalsePositive > 0 {
		m.Precision = float64(m.TruePositive) / float64(m.TruePositive+m.FalsePositive)
	}
	if m.TruePositive+m.FalseNegative > 0 {
		m.Recall = float64(m.TruePositive) / float64(m.TruePositive+m.FalseNegative)
	}
	if m.Precision+m.Recall > 0 {
		m.F1 = 2 * m.Precision * m.Recall / (m.Precision + m.Recall)
	}
	if m.Count > 0 {
		m.Accuracy = float64(m.TruePositive+m.TrueNegative) / float64(m.Count)
	}
	return m
}
func fit(rows []Pair, seed int64, epochs int) Model {
	r := rand.New(rand.NewSource(seed))
	train := []Pair{}
	for _, p := range rows {
		if p.Target >= 0 && len(p.Features) == len(featureNames) {
			train = append(train, p)
		}
	}
	m := Model{Version: "peso-mini-ai-v1", Seed: seed, Features: append([]string{}, featureNames...),
		Weights: make([]float64, len(featureNames)), Threshold: 0.5, TrainedPairs: len(train),
		Source: "synthetic-only applicant-job pairs; never validated hiring outcomes"}
	if len(train) == 0 {
		return m
	}
	for epoch := 0; epoch < epochs; epoch++ {
		r.Shuffle(len(train), func(i, j int) { train[i], train[j] = train[j], train[i] })
		lr := 0.18 / (1 + 0.07*float64(epoch))
		for _, p := range train {
			err := float64(p.Target) - modelProb(m, p.Features)
			m.Bias += lr * err
			for k, v := range p.Features {
				m.Weights[k] += lr * (err*v - 0.0008*m.Weights[k])
			}
		}
	}
	return m
}
func chooseThreshold(m Model, valid []Pair) float64 {
	best := 0.5
	bestF1 := -1.0
	bestBalanced := -1.0
	for t := 0.25; t <= 0.801; t += 0.025 {
		metric := scored(valid, func(x []float64) bool { return modelProb(m, x) >= t })
		balanced := metric.Recall
		if metric.F1 > bestF1+1e-9 || (math.Abs(metric.F1-bestF1) < 1e-9 && balanced > bestBalanced) {
			best = t
			bestF1 = metric.F1
			bestBalanced = balanced
		}
	}
	return best
}
func subsetTrain(rows []Pair, limit int) []Pair {
	tr := []Pair{}
	for _, p := range rows {
		if p.Split == "train" && p.Target >= 0 {
			tr = append(tr, p)
		}
	}
	sort.Slice(tr, func(i, j int) bool {
		return shortHash(tr[i].ApplicantID+tr[i].JobID) < shortHash(tr[j].ApplicantID+tr[j].JobID)
	})
	if limit > 0 && limit < len(tr) {
		tr = tr[:limit]
	}
	return tr
}
func trainEval(pairs []Pair, seed int64) (Model, Evaluation, error) {
	// Independent pre-training audit: never accept mislabeled cross-split
	// applicant or canonical job families, even from an external JSONL file.
	applicantSplit := map[string]string{}
	familySplit := map[string]string{}
	for _, row := range pairs {
		if row.ApplicantID != "" {
			if prior, exists := applicantSplit[row.ApplicantID]; exists && prior != row.Split {
				return Model{}, Evaluation{}, errors.New("training data applicant identity leakage")
			}
			applicantSplit[row.ApplicantID] = row.Split
		}
		if row.JobFamily != "" {
			if prior, exists := familySplit[row.JobFamily]; exists && prior != row.Split {
				return Model{}, Evaluation{}, errors.New("training data canonical family leakage")
			}
			familySplit[row.JobFamily] = row.Split
		}
	}
	tr := subsetTrain(pairs, 0)
	valid, test := []Pair{}, []Pair{}
	for _, p := range pairs {
		if len(p.Features) != len(featureNames) {
			return Model{}, Evaluation{}, errors.New("invalid feature dimensions")
		}
		if p.Split == "validation" {
			valid = append(valid, p)
		}
		if p.Split == "test" {
			test = append(test, p)
		}
	}
	if len(tr) < 30 || len(valid) < 20 || len(test) < 20 {
		return Model{}, Evaluation{}, fmt.Errorf("insufficient split sizes: train %d val %d test %d", len(tr), len(valid), len(test))
	}
	m := fit(tr, seed, 42)
	m.Threshold = chooseThreshold(m, valid)
	eval := Evaluation{Version: m.Version, ByCategory: map[string]Metrics{},
		LeakageAudit: map[string]int{"distinctApplicantIDs": len(applicantSplit),
			"distinctCanonicalNoticeFamilies": len(familySplit), "applicantCrossSplitOverlaps": 0,
			"noticeFamilyCrossSplitOverlaps": 0}, DataLimitations: []string{
			"All targets are synthetic rubric labels; scores are alignment indicators, NOT employment probabilities.",
			"No reviewed real applicant-job decisions were available or used.",
			"Historical government PDF vacancies may be stale; employer requirements need human verification.",
			"Legacy multi-role notice qualifications without explicit role attribution are excluded from mandatory criteria.",
			"Mirror URL families are canonicalized and role templates deduplicated before splitting.",
			"Protected characteristics and names are excluded from features; extraction and source bias remain possible.",
		}}
	eval.BaselineValidation = scored(valid, func(x []float64) bool { return baselineProb(x) >= 0.72 })
	eval.BaselineTest = scored(test, func(x []float64) bool { return baselineProb(x) >= 0.72 })
	yes := func(x []float64) bool { return modelProb(m, x) >= m.Threshold }
	eval.LearnedTraining = scored(tr, yes)
	eval.LearnedValidation = scored(valid, yes)
	eval.LearnedTest = scored(test, yes)
	groups := map[string][]Pair{}
	for _, p := range test {
		groups[p.JobCategory] = append(groups[p.JobCategory], p)
	}
	for cat, group := range groups {
		eval.ByCategory[cat] = scored(group, yes)
	}
	for _, p := range test {
		if p.Target < 0 {
			continue
		}
		y := yes(p.Features)
		if y && p.Target == 0 && len(eval.FalsePositiveExamples) < 8 {
			eval.FalsePositiveExamples = append(eval.FalsePositiveExamples, p.ApplicantID+" | "+p.JobID)
		}
		if !y && p.Target == 1 && len(eval.FalseNegativeExamples) < 8 {
			eval.FalseNegativeExamples = append(eval.FalseNegativeExamples, p.ApplicantID+" | "+p.JobID)
		}
	}
	for _, fraction := range []float64{0.2, 0.5, 1.0} {
		n := int(float64(len(tr)) * fraction)
		candidate := fit(tr[:n], seed, 42)
		candidate.Threshold = chooseThreshold(candidate, valid)
		val := scored(valid, func(x []float64) bool { return modelProb(candidate, x) >= candidate.Threshold })
		te := scored(test, func(x []float64) bool { return modelProb(candidate, x) >= candidate.Threshold })
		eval.LearningCurve = append(eval.LearningCurve, map[string]any{"fraction": fraction, "trainingExamples": n, "validationF1": val.F1, "testF1": te.F1})
	}
	// Only the test data is held out from training and threshold selection. Learning
	// curve test metrics are diagnostic, never fed back into model selection.
	var examples [][]float64
	for k := 0; k < 5000; k++ {
		examples = append(examples, tr[k%len(tr)].Features)
	}
	start := time.Now()
	for _, x := range examples {
		_ = modelProb(m, x)
	}
	eval.InferenceMeanMicroseconds = float64(time.Since(start).Nanoseconds()) / 1000 / float64(len(examples))
	m.TrainedAt = time.Now().UTC().Format(time.RFC3339)
	eval.ModelBytes = len(mustJson(m))
	return m, eval, nil
}
func loadModel(file string) (Model, error) {
	data, e := os.ReadFile(file)
	if e != nil {
		return Model{}, e
	}
	var m Model
	if e = json.Unmarshal(data, &m); e != nil {
		return m, e
	}
	if len(m.Weights) != len(featureNames) || m.Version == "" {
		return m, errors.New("incompatible model artifact")
	}
	return m, nil
}
func predictOne(m Model, a Applicant, j Job) Result {
	roleCriteria, excluded, unattributed := reviewedRequirements(j)
	// Title clues are non-mandatory orientation, never invented employer criteria.
	// They remain visible even when unreliable numeric alignment is suppressed.
	titleSkills := skillsFromText(strings.Split(j.Title, " — ")[0])
	applicantSkills := canonicalSkills(append(append([]string{}, a.Skills...), skillsFromText(a.ResumeText)...))
	matchedTitleClues, skillsToExplore := intersect(titleSkills, applicantSkills)
	assessmentBasis := "role_attributed_requirements"
	if len(roleCriteria) == 0 && !j.IsSynthetic {
		assessmentBasis = "job_title_clues_only"
		if len(j.OccupationCategories) > 0 {
			assessmentBasis = "occupation_category_clues_only"
		} else if len(titleSkills) == 0 {
			assessmentBasis = "job_details_unverified"
		}
	}
	f, matched, missing, pref, _ := features(a, j)
	occupationF, matchedFields, fieldsToExplore := occupationFeatures(a, j, f[9])
	j = inferredJob(j)
	missingMandatory := append([]string{}, missing...)
	for _, l := range j.RequiredLicenses {
		if !hasLicense(a, l) {
			missingMandatory = append(missingMandatory, "Verify required license: "+l)
		}
	}
	if j.RequiredEducation != "" && educationRank(a.EducationLevel) < educationRank(j.RequiredEducation) {
		missingMandatory = append(missingMandatory, "Verify education requirement: "+j.RequiredEducation)
	}
	if a.YearsExperience < j.MinExperienceYears {
		missingMandatory = append(missingMandatory, fmt.Sprintf("Verify %d year(s) related experience", j.MinExperienceYears))
	}
	review := []string{}
	if len(safeRequirements(j)) == 0 && !j.IsSynthetic {
		review = append(review, "The listing has incomplete or unverified qualification details")
	}
	if len(unattributed) > 0 {
		review = append(review, "Notice-level qualifications are not attributed to this role; human source review required")
	}
	if !j.IsSynthetic && len(j.RequiredSkills) == 0 {
		review = append(review, "Employer has not confirmed all role-specific mandatory skills")
	}
	if a.Incomplete || len(a.Skills) == 0 {
		review = append(review, "Applicant skills/profile are incomplete or unverified")
	}
	if j.SourceURL != "" && !j.IsSynthetic {
		review = append(review, "Confirm historical PDF listing is still open with PESO")
	}
	// Review notices are not interchangeable with insufficient matching evidence.
	// Historical vacancy checks and non-mandatory information requests must not
	// suppress an otherwise usable role-specific comparison across all jobs.
	// Only independently attributable role criteria and applicant evidence can
	// support confidence. Never infer mandatory criteria from the job title.
	roleAttributedCriteria := len(roleCriteria) > 0 || j.IsSynthetic
	applicantEvidence := len(a.Skills) > 0 || len(a.Certifications) > 0 ||
		len(a.Licenses) > 0 || strings.TrimSpace(a.EducationLevel) != "" ||
		strings.TrimSpace(a.ProfessionalTitle) != "" || a.YearsExperience > 0
	confidence := "medium"
	if !roleAttributedCriteria || !applicantEvidence || (a.Incomplete && f[9] < 0.55) {
		confidence = "low"
	} else if f[9] >= 0.9 && !a.Incomplete && len(unattributed) == 0 {
		confidence = "moderate"
	}
	// A promoted occupation model replaces the previous synthetic role-weight
	// knowledge; legacy weights remain only for compatibility with unit tests.
	probability := modelProb(m, f)
	if len(m.OccupationWeights) == 4 {
		probability = occupationProb(m, occupationF)
	}
	score := int(math.Round(100 * probability))
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	readiness := "Some relevant experience or training to build on"
	if len(m.OccupationWeights) == 4 {
		readiness = "Occupational similarity to explore"
		if probability >= m.Threshold {
			readiness = "Strong occupation-category similarity to review"
		}
	} else if probability >= m.Threshold {
		readiness = "Strong qualification alignment to review"
	}
	if confidence == "low" {
		readiness = "More information needed for a reliable review"
	}
	contributions := map[string]float64{}
	if len(m.OccupationWeights) == 4 {
		for idx, name := range []string{"same_career_field", "shared_isco_major_group", "field_coverage", "occupation_evidence_quality"} {
			contributions[name] = math.Round(1000*m.OccupationWeights[idx]*occupationF[idx]) / 1000
		}
	} else {
		for idx, name := range m.Features {
			contributions[name] = math.Round(1000*m.Weights[idx]*f[idx]) / 1000
		}
	}
	if len(excluded) > 0 {
		// Informational provenance only: excluded criteria do not affect score,
		// readiness, confidence, features, target labels or ranking.
		review = append(review, "Protected or demographic criteria excluded from matching; needs human source review")
	}
	return Result{JobID: j.ID, Score: score, ModelVersion: m.Version, Readiness: readiness, Confidence: confidence,
		AssessmentBasis: assessmentBasis, RoleCriteriaCount: len(roleCriteria),
		OccupationTaxonomy: "ISCO-08", MatchedOccupationFields: matchedFields,
		OccupationFieldsToExplore: fieldsToExplore,
		MatchedTitleClues:         matchedTitleClues, SkillsToExplore: skillsToExplore,
		MatchedSkills: matched, MissingSkills: missing, MatchedPreferred: pref, MissingMandatory: unique(missingMandatory),
		NeedsReview: unique(review), ExcludedRequirements: excluded, FeatureContributions: contributions, SourceURL: j.SourceURL, SourcePageStart: j.SourcePageStart}
}
