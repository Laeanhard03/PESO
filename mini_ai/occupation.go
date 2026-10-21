package main

import (
	"encoding/json"
	"errors"
	"math"
	"os"
)

// Broad occupational affinity labels are separate from employer qualifications.
type OccupationTaxonomy struct {
	Taxonomy    string
	MajorGroups map[string]string
	Fields      []struct {
		Code            string
		IscoMajorGroups []string
		Terms           []string
	}
}
type OccupationTrainingReport struct {
	Taxonomy        string
	MajorGroups     int
	Fields          int
	TrainingPairs   int
	ValidationPairs int
	TestPairs       int
	TestF1          float64
	TestAccuracy    float64
	BaselineTestF1  float64
	LeakageChecked  bool
	Limits          []string
}
type occupationExample struct {
	family, split string
	x             [4]float64
	y             float64
}

func occupationContains(items []string, wanted string) bool {
	for _, v := range items {
		if v == wanted {
			return true
		}
	}
	return false
}
func sharedMajor(a, b []OccupationCategory) bool {
	for _, x := range a {
		for _, y := range b {
			if x.IscoMajorGroup != "" && x.IscoMajorGroup == y.IscoMajorGroup {
				return true
			}
		}
	}
	return false
}
func occupationFeatures(a Applicant, j Job, evidence float64) ([]float64, []string, []string) {
	matches, explore := []string{}, []string{}
	for _, wanted := range j.OccupationCategories {
		if wanted.Field == "" {
			continue
		}
		found := false
		for _, owned := range a.OccupationCategories {
			if owned.Field == wanted.Field {
				found = true
				break
			}
		}
		if found {
			matches = append(matches, wanted.Field)
		} else {
			explore = append(explore, wanted.Field)
		}
	}
	exact, major, coverage := 0.0, 0.0, 0.0
	if len(matches) > 0 {
		exact = 1
	}
	if sharedMajor(a.OccupationCategories, j.OccupationCategories) {
		major = 1
	}
	if len(j.OccupationCategories) > 0 {
		coverage = float64(len(matches)) / float64(len(j.OccupationCategories))
	}
	if evidence < 0 {
		evidence = 0
	}
	if evidence > 1 {
		evidence = 1
	}
	return []float64{exact, major, coverage, evidence}, unique(matches), unique(explore)
}
func occupationProb(m Model, f []float64) float64 {
	z := m.OccupationBias
	for i, v := range f {
		if i < len(m.OccupationWeights) {
			z += m.OccupationWeights[i] * v
		}
	}
	return sigmoid(z)
}
func occupationDataset(catalog OccupationTaxonomy) ([]occupationExample, error) {
	if len(catalog.MajorGroups) != 10 || len(catalog.Fields) < 10 {
		return nil, errors.New("occupation catalog must have all 10 ISCO major groups")
	}
	covered := map[string]bool{}
	for _, f := range catalog.Fields {
		for _, group := range f.IscoMajorGroups {
			covered[group] = true
		}
	}
	if len(covered) != 10 {
		return nil, errors.New("occupation catalog misses an ISCO major group")
	}
	out := []occupationExample{}
	for i, source := range catalog.Fields {
		if source.Code == "" || len(source.IscoMajorGroups) == 0 || len(source.Terms) == 0 {
			return nil, errors.New("invalid occupation catalog field")
		}
		split := hashSplit("occupation-family:"+source.Code, 20261021)
		add := func(index int, coverage, evidence float64) {
			dest := catalog.Fields[index]
			same := i == index
			major := false
			for _, code := range source.IscoMajorGroups {
				if occupationContains(dest.IscoMajorGroups, code) {
					major = true
					break
				}
			}
			x := [4]float64{0, 0, 0, evidence}
			if same {
				x[0] = 1
				x[2] = coverage
			}
			if major {
				x[1] = 1
			}
			y := 0.0
			if same {
				y = 1
			}
			out = append(out, occupationExample{family: source.Code, split: split, x: x, y: y})
		}
		add(i, 1, 1)
		add(i, 0.5, 0.7)
		add(i, 0.25, 0.4)
		near, far := 0, 0
		for k := 1; k < len(catalog.Fields); k++ {
			candidate := (i + k) % len(catalog.Fields)
			sameGroup := false
			for _, code := range source.IscoMajorGroups {
				if occupationContains(catalog.Fields[candidate].IscoMajorGroups, code) {
					sameGroup = true
					break
				}
			}
			if sameGroup && near < 3 {
				add(candidate, 0.2, 1)
				near++
			}
			if !sameGroup && far < 3 {
				add(candidate, 0.2, 1)
				far++
			}
		}
		if near+far < 3 {
			return nil, errors.New("insufficient negative occupation examples")
		}
	}
	return out, nil
}
func fitOccupationModel(data []occupationExample) ([]float64, float64) {
	weights := []float64{0, 0, 0, 0}
	bias := 0.0
	n := 0.0
	for _, example := range data {
		if example.split == "train" {
			n++
		}
	}
	if n == 0 {
		return weights, bias
	}
	for epoch := 0; epoch < 400; epoch++ {
		grad := []float64{0, 0, 0, 0}
		biasGrad := 0.0
		for _, example := range data {
			if example.split != "train" {
				continue
			}
			z := bias
			for k, v := range example.x {
				z += weights[k] * v
			}
			delta := sigmoid(z) - example.y
			biasGrad += delta
			for k, v := range example.x {
				grad[k] += delta * v
			}
		}
		lr := 1.1 / math.Sqrt(1+float64(epoch)*0.025)
		bias -= lr * biasGrad / n
		for k := range weights {
			weights[k] -= lr * (grad[k]/n + 0.0008*weights[k])
		}
	}
	return weights, bias
}
func measureOccupation(data []occupationExample, split string, weights []float64, bias float64, baseline bool) (float64, float64, int) {
	tp, fp, fn, correct, n := 0, 0, 0, 0, 0
	for _, example := range data {
		if example.split != split {
			continue
		}
		n++
		score := 0.0
		if baseline {
			score = 0.25*example.x[1] + 0.6*example.x[0]
		} else {
			score = bias
			for k, v := range example.x {
				score += weights[k] * v
			}
			score = sigmoid(score)
		}
		predicted := score >= 0.5
		actual := example.y == 1
		if predicted == actual {
			correct++
		}
		if predicted && actual {
			tp++
		}
		if predicted && !actual {
			fp++
		}
		if !predicted && actual {
			fn++
		}
	}
	accuracy, f1 := 0.0, 0.0
	if n > 0 {
		accuracy = float64(correct) / float64(n)
	}
	if 2*tp+fp+fn > 0 {
		f1 = float64(2*tp) / float64(2*tp+fp+fn)
	}
	return f1, accuracy, n
}
func trainOccupationModel(taxonomyPath string) (Model, OccupationTrainingReport, error) {
	var model Model
	var report OccupationTrainingReport
	raw, err := os.ReadFile(taxonomyPath)
	if err != nil {
		return model, report, err
	}
	var catalog OccupationTaxonomy
	if err = json.Unmarshal(raw, &catalog); err != nil {
		return model, report, err
	}
	samples, err := occupationDataset(catalog)
	if err != nil {
		return model, report, err
	}
	seen := map[string]string{}
	for _, sample := range samples {
		if old, exists := seen[sample.family]; exists && old != sample.split {
			return model, report, errors.New("occupation family leaked across held-out splits")
		}
		seen[sample.family] = sample.split
	}
	w, b := fitOccupationModel(samples)
	testF1, testAccuracy, testCount := measureOccupation(samples, "test", w, b, false)
	baseline, _, _ := measureOccupation(samples, "test", w, b, true)
	valF1, _, valCount := measureOccupation(samples, "validation", w, b, false)
	if testCount < 5 || valCount < 5 || testF1 < baseline || valF1 < 0.7 {
		return model, report, errors.New("new occupation matcher failed held-out validation")
	}
	model = Model{Version: "peso-mini-ai-v1", Seed: 20261021, Features: featureNames,
		Weights: make([]float64, len(featureNames)), Threshold: 0.5,
		OccupationWeights: w, OccupationBias: b, TrainedPairs: len(samples),
		Source: "ISCO-08 synthetic occupation affinity, not hiring labels"}
	report = OccupationTrainingReport{Taxonomy: catalog.Taxonomy, MajorGroups: len(catalog.MajorGroups),
		Fields: len(catalog.Fields), TestF1: testF1, TestAccuracy: testAccuracy,
		BaselineTestF1: baseline, LeakageChecked: true,
		Limits: []string{
			"Synthetic category identity tests are not evidence of real hiring accuracy.",
			"Shared major occupation group alone is not proof of comparable specialist qualifications.",
			"Unknown job titles require verification; missing employer requirements are never invented.",
		}}
	for _, example := range samples {
		switch example.split {
		case "train":
			report.TrainingPairs++
		case "validation":
			report.ValidationPairs++
		case "test":
			report.TestPairs++
		}
	}
	return model, report, nil
}
