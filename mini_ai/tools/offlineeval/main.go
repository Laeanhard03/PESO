// Offline diagnostic only. Frozen synthetic rubric labels are NOT hiring truth.
// Usage: go run ./tools/offlineeval -model data/model_v1.json -data data/v1/synthetic_pairs_v1.jsonl
package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math"
	"os"
	"sort"
)

type pair struct {
	ApplicantID string    `json:"applicantId"`
	JobFamily   string    `json:"jobFamily"`
	Split       string    `json:"split"`
	Target      int       `json:"target"`
	Features    []float64 `json:"features"`
	IsSynthetic bool      `json:"isSynthetic"`
}
type model struct {
	Version   string    `json:"version"`
	Features  []string  `json:"features"`
	Weights   []float64 `json:"weights"`
	Bias      float64   `json:"bias"`
	Threshold float64   `json:"threshold"`
	Source    string    `json:"source"`
}
type prediction struct {
	probability float64
	target      int
}
type metrics struct {
	ModelVersion         string  `json:"modelVersion"`
	Evaluated            int     `json:"evaluated"`
	UncertainSkipped     int     `json:"uncertainSkipped"`
	TP                   int     `json:"tp"`
	FP                   int     `json:"fp"`
	TN                   int     `json:"tn"`
	FN                   int     `json:"fn"`
	F1                   float64 `json:"f1"`
	Precision            float64 `json:"precision"`
	Recall               float64 `json:"recall"`
	Accuracy             float64 `json:"accuracy"`
	SyntheticBrier       float64 `json:"syntheticRubricBrier"`
	SyntheticECE10       float64 `json:"syntheticRubricECE10"`
	SyntheticNDCG5       float64 `json:"syntheticRubricNDCGAt5"`
	SyntheticTop1HitRate float64 `json:"syntheticRubricTop1HitRate"`
	RankingGroups        int     `json:"rankingGroupsWithPositiveAndNegative"`
}

func loadModel(path string) (model, string, error) {
	raw, e := os.ReadFile(path)
	if e != nil {
		return model{}, "", e
	}
	var m model
	if e = json.Unmarshal(raw, &m); e != nil {
		return m, "", e
	}
	if len(m.Features) == 0 || len(m.Weights) != len(m.Features) || m.Threshold <= 0 || m.Threshold >= 1 {
		return m, "", errors.New("invalid model artifact")
	}
	hash := sha256.Sum256(raw)
	return m, hex.EncodeToString(hash[:]), nil
}
func loadPairs(path string) ([]pair, string, error) {
	f, e := os.Open(path)
	if e != nil {
		return nil, "", e
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 8192), 1<<20)
	all := []pair{}
	digest := sha256.New()
	applicantSplit := map[string]string{}
	familySplit := map[string]string{}
	for scanner.Scan() {
		line := append([]byte{}, scanner.Bytes()...)
		digest.Write(line)
		digest.Write([]byte("\n"))
		var p pair
		if e = json.Unmarshal(line, &p); e != nil {
			return nil, "", e
		}
		if p.Split != "train" && p.Split != "validation" && p.Split != "test" {
			return nil, "", errors.New("invalid split")
		}
		if p.ApplicantID == "" || p.JobFamily == "" {
			return nil, "", errors.New("missing leakage-audit identities")
		}
		if p.Target != -1 && p.Target != 0 && p.Target != 1 {
			return nil, "", errors.New("invalid label")
		}
		if !p.IsSynthetic {
			return nil, "", errors.New("real applicants/labels require separate human-review protocol; this diagnostic accepts synthetic fixtures only")
		}
		if previous, ok := applicantSplit[p.ApplicantID]; ok && previous != p.Split {
			return nil, "", errors.New("applicant cross-split leakage")
		}
		if previous, ok := familySplit[p.JobFamily]; ok && previous != p.Split {
			return nil, "", errors.New("source-family cross-split leakage")
		}
		applicantSplit[p.ApplicantID] = p.Split
		familySplit[p.JobFamily] = p.Split
		all = append(all, p)
	}
	if e = scanner.Err(); e != nil {
		return nil, "", e
	}
	if len(all) == 0 {
		return nil, "", errors.New("no evaluation rows")
	}
	return all, hex.EncodeToString(digest.Sum(nil)), nil
}
func probability(m model, x []float64) float64 {
	z := m.Bias
	for i, v := range x {
		z += m.Weights[i] * v
	}
	if z > 30 {
		return 1
	}
	if z < -30 {
		return 0
	}
	return 1 / (1 + math.Exp(-z))
}
func division(n, d float64) float64 {
	if d == 0 {
		return 0
	}
	return n / d
}
func discounted(rows []prediction) float64 {
	result := 0.0
	for i := 0; i < len(rows) && i < 5; i++ {
		result += float64(rows[i].target) / math.Log2(float64(i)+2)
	}
	return result
}
func evaluate(m model, all []pair) (metrics, error) {
	result := metrics{ModelVersion: m.Version}
	groups := map[string][]prediction{}
	brier := 0.0
	var binCount [10]int
	var binProbability [10]float64
	var binLabel [10]float64
	for _, p := range all {
		if p.Split != "test" {
			continue
		}
		if p.Target < 0 {
			result.UncertainSkipped++
			continue
		}
		if len(p.Features) != len(m.Features) {
			return result, errors.New("incompatible feature vector length")
		}
		prob := probability(m, p.Features)
		if math.IsNaN(prob) || math.IsInf(prob, 0) {
			return result, errors.New("invalid model probability")
		}
		yes := prob >= m.Threshold
		if yes && p.Target == 1 {
			result.TP++
		} else if yes {
			result.FP++
		} else if p.Target == 1 {
			result.FN++
		} else {
			result.TN++
		}
		diff := prob - float64(p.Target)
		brier += diff * diff
		bin := int(math.Min(9, math.Floor(prob*10)))
		binCount[bin]++
		binProbability[bin] += prob
		binLabel[bin] += float64(p.Target)
		groups[p.ApplicantID] = append(groups[p.ApplicantID], prediction{prob, p.Target})
		result.Evaluated++
	}
	if result.Evaluated == 0 {
		return result, errors.New("no held-out labeled test rows")
	}
	result.Precision = division(float64(result.TP), float64(result.TP+result.FP))
	result.Recall = division(float64(result.TP), float64(result.TP+result.FN))
	result.F1 = division(2*result.Precision*result.Recall, result.Precision+result.Recall)
	result.Accuracy = division(float64(result.TP+result.TN), float64(result.Evaluated))
	result.SyntheticBrier = brier / float64(result.Evaluated)
	for i, n := range binCount {
		if n > 0 {
			result.SyntheticECE10 += float64(n) / float64(result.Evaluated) *
				math.Abs(binProbability[i]/float64(n)-binLabel[i]/float64(n))
		}
	}
	ndcg := 0.0
	top1 := 0.0
	for _, g := range groups {
		positives := 0
		for _, p := range g {
			if p.target == 1 {
				positives++
			}
		}
		if len(g) < 2 || positives == 0 || positives == len(g) {
			continue
		}
		ideal := append([]prediction{}, g...)
		sort.Slice(ideal, func(i, j int) bool { return ideal[i].target > ideal[j].target })
		sort.SliceStable(g, func(i, j int) bool { return g[i].probability > g[j].probability })
		ndcg += division(discounted(g), discounted(ideal))
		if g[0].target == 1 {
			top1++
		}
		result.RankingGroups++
	}
	result.SyntheticNDCG5 = division(ndcg, float64(result.RankingGroups))
	result.SyntheticTop1HitRate = division(top1, float64(result.RankingGroups))
	return result, nil
}
func main() {
	data := flag.String("data", "data/v1/synthetic_pairs_v1.jsonl", "frozen held-out pair dataset")
	baseline := flag.String("baseline", "data/model_v1.json", "existing production baseline model")
	candidate := flag.String("candidate", "", "optional offline candidate; must be independently validated")
	output := flag.String("report", "", "optional JSON report path")
	flag.Parse()
	all, dataHash, e := loadPairs(*data)
	if e != nil {
		panic(e)
	}
	mainModel, baseHash, e := loadModel(*baseline)
	if e != nil {
		panic(e)
	}
	base, e := evaluate(mainModel, all)
	if e != nil {
		panic(e)
	}
	report := map[string]any{
		"evaluationType":    "synthetic_rubric_diagnostic_not_hiring_accuracy",
		"heldOutDataSha256": dataHash, "baselineModelSha256": baseHash,
		"sameHeldOutEvaluation": true, "baseline": base,
		"realApplicantLabels": 0, "humanReviewedRoleRequirements": 0,
		"promotionEligible":        false,
		"limitation":               "Synthetic labels cannot validate real qualification gaps, real-world probability calibration or hiring job-ranking quality. Do not deploy from these metrics.",
		"missingMandatoryAccuracy": "NOT_MEASURABLE: needs independently verified role-specific mandatory requirement and applicant-evidence annotations",
		"confidenceCalibration":    "Brier and ECE are proxies against synthetic rubric labels, not reliability of the displayed confidence categories",
	}
	if *candidate != "" {
		candidateModel, candidateHash, err := loadModel(*candidate)
		if err != nil {
			panic(err)
		}
		if len(mainModel.Features) != len(candidateModel.Features) {
			panic("candidate feature schema differs")
		}
		for i, key := range mainModel.Features {
			if candidateModel.Features[i] != key {
				panic("candidate feature order differs")
			}
		}
		met, err := evaluate(candidateModel, all)
		if err != nil {
			panic(err)
		}
		report["candidateModelSha256"] = candidateHash
		report["candidate"] = met
		report["deltaF1"] = met.F1 - base.F1
		report["deltaSyntheticECE"] = met.SyntheticECE10 - base.SyntheticECE10
		report["deltaSyntheticNDCG5"] = met.SyntheticNDCG5 - base.SyntheticNDCG5
		report["candidateLeakageProvenance"] = "UNKNOWN unless candidate training data/train-family manifest independently audited"
	}
	raw, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		panic(err)
	}
	if *output != "" {
		if err = os.WriteFile(*output, append(raw, '\n'), 0600); err != nil {
			panic(err)
		}
	}
	fmt.Println(string(raw))
}
