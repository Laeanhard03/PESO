package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"runtime"
	"sort"
	"time"
)

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("commands: train-occupation | generate | train | predict | benchmark")
	}
	switch args[0] {
	case "train-occupation":
		f := flag.NewFlagSet("train-occupation", flag.ContinueOnError)
		catalog := f.String("taxonomy", "data/occupation_taxonomy.json", "global occupation taxonomy training catalog")
		out := f.String("model", "data/model_v1.json", "active trained model artifact, replaced in place")
		report := f.String("report", "data/evaluation_v1.json", "validation report, updated in place")
		if e := f.Parse(args[1:]); e != nil {
			return e
		}
		model, evaluation, e := trainOccupationModel(*catalog)
		if e != nil {
			return e
		}
		if e = saveJSON(*out, model); e != nil {
			return e
		}
		if e = saveJSON(*report, evaluation); e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{
			"trainedFields": evaluation.Fields, "majorGroups": evaluation.MajorGroups,
			"heldOutF1": evaluation.TestF1, "testPairs": evaluation.TestPairs,
			"model": *out, "report": *report,
		})
	case "generate":
		// Historical role-specific synthetic data is no longer part of the
		// supported matching workflow. Retain test helpers but do not silently
		// generate obsolete training artifacts on a live prototype.
		return errors.New("retired synthetic job-pair generator disabled; use the ISCO-08 occupation catalog")
	case "train":
		// The previous synthetic job-pair classifier has been deliberately
		// retired. Never allow a legacy CLI script to overwrite the active
		// occupation model with the old frozen weights.
		return errors.New("retired synthetic job-pair trainer disabled; use train-occupation")
	case "predict":
		f := flag.NewFlagSet("predict", flag.ContinueOnError)
		modelPath := f.String("model", "data/model_v1.json", "model artifact")
		if e := f.Parse(args[1:]); e != nil {
			return e
		}
		m, e := loadModel(*modelPath)
		if e != nil {
			return e
		}
		raw, e := io.ReadAll(io.LimitReader(os.Stdin, 6*1024*1024+1))
		if e != nil {
			return e
		}
		if len(raw) > 6*1024*1024 {
			return errors.New("inference request too large")
		}
		var q struct {
			Applicant Applicant `json:"applicant"`
			Jobs      []Job     `json:"jobs"`
		}
		if e = json.Unmarshal(raw, &q); e != nil {
			return errors.New("invalid inference JSON")
		}
		if len(q.Jobs) == 0 || len(q.Jobs) > 1000 {
			return errors.New("provide 1 to 1000 jobs")
		}
		if len(q.Applicant.Skills) > 100 {
			return errors.New("too many skills")
		}
		results := make([]Result, 0, len(q.Jobs))
		for _, j := range q.Jobs {
			if len(j.Title) > 160 || len(j.Requirements) > 100 {
				return errors.New("invalid job fields")
			}
			results = append(results, predictOne(m, q.Applicant, j))
		}
		sort.SliceStable(results, func(i, j int) bool { return results[i].Score > results[j].Score })
		if len(results) > 30 {
			results = results[:30]
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]any{
			"ok": true, "modelVersion": m.Version, "results": results,
			"disclaimer": "Synthetic-trained qualification alignment, not a hiring decision or employment probability."})
	case "benchmark":
		f := flag.NewFlagSet("benchmark", flag.ContinueOnError)
		modelPath := f.String("model", "data/model_v1.json", "model artifact")
		count := f.Int("count", 50000, "predictions")
		if e := f.Parse(args[1:]); e != nil {
			return e
		}
		m, e := loadModel(*modelPath)
		if e != nil {
			return e
		}
		x := []float64{1, 0.5, 0, 1, 1, 1, 0.7, 0.8, 1, 1, 0.5}
		if *count < 1 || *count > 10000000 {
			return errors.New("invalid benchmark count")
		}
		runtime.GC()
		var before, after runtime.MemStats
		runtime.ReadMemStats(&before)
		start := time.Now()
		sum := 0.0
		for i := 0; i < *count; i++ {
			sum += modelProb(m, x)
		}
		duration := time.Since(start)
		runtime.ReadMemStats(&after)
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"count": *count,
			"meanMicroseconds":        float64(duration.Nanoseconds()) / float64(*count) / 1000,
			"totalMilliseconds":       float64(duration.Nanoseconds()) / 1e6,
			"heapAllocatedBytesDelta": int64(after.TotalAlloc) - int64(before.TotalAlloc), "checksum": sum})
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}
func main() {
	if e := run(os.Args[1:]); e != nil {
		fmt.Fprintln(os.Stderr, "mini_ai:", e)
		os.Exit(1)
	}
}
