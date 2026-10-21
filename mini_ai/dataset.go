package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

type DataMeta struct {
	Version                 string         `json:"version"`
	Seed                    int64          `json:"seed"`
	SourceJobs              int            `json:"sourceJobs"`
	Jobs                    int            `json:"syntheticJobs"`
	Applicants              int            `json:"syntheticApplicants"`
	Pairs                   int            `json:"syntheticPairs"`
	Categories              map[string]int `json:"categories"`
	Labels                  map[string]int `json:"labels"`
	Splits                  map[string]int `json:"splits"`
	LeakageCheck            string         `json:"leakageCheck"`
	LeakageAudit            map[string]int `json:"leakageAudit"`
	UniqueSourceRoles       int            `json:"uniqueSourceRoles"`
	DeduplicatedSourceRoles int            `json:"deduplicatedSourceRoles"`
	Rubric                  string         `json:"rubric"`
}

func saveJSON(path string, v any) error {
	if e := os.MkdirAll(filepath.Dir(path), 0755); e != nil {
		return e
	}
	data, e := json.MarshalIndent(v, "", "  ")
	if e != nil {
		return e
	}
	return os.WriteFile(path, append(data, '\n'), 0644)
}
func saveJSONL[T any](path string, items []T) error {
	if e := os.MkdirAll(filepath.Dir(path), 0755); e != nil {
		return e
	}
	f, e := os.Create(path)
	if e != nil {
		return e
	}
	defer f.Close()
	w := bufio.NewWriter(f)
	for _, v := range items {
		if _, e = w.Write(append(mustJson(v), '\n')); e != nil {
			return e
		}
	}
	return w.Flush()
}
func loadJSONL[T any](path string) ([]T, error) {
	f, e := os.Open(path)
	if e != nil {
		return nil, e
	}
	defer f.Close()
	var out []T
	s := bufio.NewScanner(f)
	s.Buffer(make([]byte, 8192), 2*1024*1024)
	for s.Scan() {
		var v T
		if e = json.Unmarshal(s.Bytes(), &v); e != nil {
			return nil, e
		}
		out = append(out, v)
	}
	return out, s.Err()
}
func choose(r *rand.Rand, items []string) string {
	if len(items) == 0 {
		return ""
	}
	return items[r.Intn(len(items))]
}
func randomSkill(r *rand.Rand, code string) string {
	aliases := skillAliases[code]
	if len(aliases) == 0 {
		return code
	}
	if r.Intn(5) == 0 {
		return code
	}
	return aliases[r.Intn(len(aliases))]
}

// Mirror origins, HTTP(S), URL queries and source IDs must not change a
// document's split family. Prefer a verified content hash when available.
func sourceDocumentIdentity(job Job) string {
	if h := strings.ToLower(strings.TrimSpace(job.SourceDocumentHash)); h != "" {
		return "sha256:" + h
	}
	if u, err := url.Parse(strings.TrimSpace(job.SourceURL)); err == nil && u.Host != "" {
		host := strings.ToLower(u.Hostname())
		host = strings.TrimPrefix(strings.TrimPrefix(host, "www."), "dev.")
		cleanPath := strings.ToLower(path.Clean(u.EscapedPath()))
		return "url:" + host + cleanPath
	}
	return "title:" + normalized(job.SourceTitle)
}
func roleFamily(job Job) string {
	return fmt.Sprintf("%s|company:%s|pages:%d-%d",
		sourceDocumentIdentity(job), normalized(job.Company),
		job.SourcePageStart, job.SourcePageEnd)
}
func roleTemplateIdentity(job Job) string {
	role := strings.Split(job.Title, " — ")[0]
	return roleFamily(job) + "|role:" + normalized(role)
}
func requirementSkills(job Job) []string {
	skills := skillsFromText(strings.Split(job.Title, " — ")[0])
	for _, req := range safeRequirements(job) {
		if strings.Contains(strings.ToLower(req), "with ") || strings.Contains(strings.ToLower(req), "skill") ||
			strings.Contains(strings.ToLower(req), "experience") || strings.Contains(strings.ToLower(req), "required") {
			skills = append(skills, skillsFromText(req)...)
		}
	}
	return unique(skills)
}
func makeJob(r *rand.Rand, source Job, index int, lraRate float64, seed int64) Job {
	role := strings.TrimSpace(strings.Split(source.Title, " — ")[0])
	skills := requirementSkills(source)
	if len(skills) == 0 {
		skills = []string{choose(r, allSkills)}
	}
	r.Shuffle(len(skills), func(i, j int) { skills[i], skills[j] = skills[j], skills[i] })
	n := min(len(skills), 1+r.Intn(3))
	reqSkills := append([]string{}, skills[:n]...)
	pref := []string{}
	for _, s := range skills[n:] {
		if r.Intn(3) < 2 {
			pref = append(pref, s)
		}
	}
	if len(pref) == 0 && r.Intn(2) == 0 {
		pref = append(pref, choose(r, allSkills))
	}
	cat := source.Category
	if r.Float64() < lraRate {
		cat = "local_recruitment_activity"
	} else {
		cat = "walk_in_application"
	}
	edus := []string{"", "high_school", "techvoc", "college"}
	edu := edus[r.Intn(len(edus))]
	req := []string{}
	for _, s := range reqSkills {
		req = append(req, "Required skill: "+strings.ReplaceAll(s, "_", " "))
	}
	for _, s := range pref {
		req = append(req, "Preferred: "+strings.ReplaceAll(s, "_", " "))
	}
	if edu != "" {
		req = append(req, "Minimum training/education: "+edu)
	}
	lic := []string{}
	lower := strings.ToLower(role)
	if (strings.Contains(lower, "driver") || strings.Contains(lower, "operator")) && r.Intn(3) < 2 {
		lic = []string{"driver_license"}
		req = append(req, "Driver's license required")
	} else if (strings.Contains(lower, "welder") || strings.Contains(lower, "electrician")) && r.Intn(4) == 0 {
		lic = []string{"nc_ii"}
		req = append(req, "NC II certification required")
	}
	years := r.Intn(5)
	if r.Intn(4) == 0 {
		years = 0
	}
	if years > 0 {
		req = append(req, fmt.Sprintf("At least %d year(s) related experience", years))
	}
	variant := []string{"", " - Training Case", " (entry pathway)", " (experience pathway)", " - Skills Review"}
	suffix := variant[r.Intn(len(variant))]
	title := role + suffix
	company := "Synthetic PESO Training Employer " + fmt.Sprintf("%03d", index%67)
	location := source.Location
	if len(location) > 120 {
		location = "Work location to be verified"
	}
	desc := "SYNTHETIC TRAINING JOB — NOT A REAL VACANCY. Simulated duties for " + role + ". " +
		"Requirements are intentionally varied from a real PDF-sourced job family; they are not employer-confirmed."
	if r.Intn(12) == 0 {
		req = nil
		reqSkills = nil
		pref = nil
		edu = ""
		lic = nil
		desc = "SYNTHETIC INCOMPLETE JOB — requirements not yet verified."
	}
	return Job{ID: fmt.Sprintf("synthetic-job-%06d", index), Title: title, Company: company, Location: location,
		Salary: "Not specified", EmploymentType: source.EmploymentType, Description: desc,
		Requirements: req, Category: cat, SourceFingerprint: "synthetic:" + shortHash(fmt.Sprintf("%d:%d", seed, index)),
		SourceTemplateID: source.SourceFingerprint, PublicPdfSourceID: source.PublicPdfSourceID,
		SourceTitle: source.SourceTitle, SourceURL: source.SourceURL, SourcePageStart: source.SourcePageStart,
		SourcePageEnd: source.SourcePageEnd, RequiredSkills: unique(reqSkills), PreferredSkills: unique(pref),
		RequiredLicenses: lic, RequiredEducation: edu, MinExperienceYears: years,
		Family: roleFamily(source), Split: hashSplit(roleFamily(source), seed), IsSynthetic: true}
}
func makeApplicant(r *rand.Rand, job Job, index int) Applicant {
	scenario := index % 10
	req := append([]string{}, job.RequiredSkills...)
	pref := append([]string{}, job.PreferredSkills...)
	skills := []string{}
	switch scenario {
	case 0, 1, 2:
		skills = append(skills, req...)
		if scenario == 0 {
			skills = append(skills, pref...)
		}
	case 3, 4, 5, 7, 9:
		skills = append(skills, req[:len(req)/2]...)
		if scenario == 9 {
			skills = append(skills, pref...)
		}
	case 6:
		for k := 0; k < 2; k++ {
			skills = append(skills, choose(r, allSkills))
		}
	case 8:
		skills = append(skills, req...)
	}
	if r.Intn(2) == 0 {
		skills = append(skills, choose(r, allSkills))
	}
	for k := range skills {
		skills[k] = randomSkill(r, skills[k])
	}
	level := "Senior High School"
	switch job.RequiredEducation {
	case "college":
		level = "Bachelor's Degree"
	case "techvoc":
		level = "TESDA vocational"
	}
	if scenario == 5 {
		level = "Junior High School"
	}
	if r.Intn(13) == 0 {
		level = ""
	}
	years := job.MinExperienceYears + r.Intn(3)
	if scenario == 8 || scenario == 3 {
		years = max(0, job.MinExperienceYears-1)
	}
	if scenario == 6 {
		years = 0
	}
	lic := []string{}
	if scenario != 4 && scenario != 6 {
		lic = append(lic, job.RequiredLicenses...)
	}
	cert := []string{}
	if r.Intn(5) == 0 {
		cert = []string{"TESDA training"}
	}
	a := Applicant{ID: fmt.Sprintf("synthetic-applicant-%06d", index), Skills: skills, EducationLevel: level,
		YearsExperience: years, Licenses: lic, Certifications: cert, ProfessionalTitle: strings.Split(job.Title, " — ")[0],
		EmploymentStatus: "Looking for work", AffinityJobID: job.ID, Split: job.Split, IsSynthetic: true}
	if scenario == 7 || r.Intn(15) == 0 {
		a.Incomplete = true
		a.EducationLevel = ""
		a.ProfessionalTitle = ""
		a.Skills = skills[:min(len(skills), 1)]
	}
	if r.Intn(2) == 0 && !a.Incomplete {
		a.ResumeText = "Experience with " + strings.Join(a.Skills, ", ") + "; completed " + a.EducationLevel
	}
	return a
}
func generateData(sourcePath, out string, seed int64, jobCount, appCount, pairCount int, lraRate float64) (DataMeta, error) {
	meta := DataMeta{Version: "synthetic-v1", Seed: seed, Categories: map[string]int{}, Labels: map[string]int{},
		Splits: map[string]int{}, LeakageAudit: map[string]int{}, Rubric: "Mandatory skills, licenses, training and experience determine synthetic targets; incomplete/ambiguous evidence gets target -1 (review). Not real hiring decisions."}
	data, e := os.ReadFile(sourcePath)
	if e != nil {
		return meta, e
	}
	var snapshot Snapshot
	if e = json.Unmarshal(data, &snapshot); e != nil {
		return meta, e
	}
	rawSources := []Job{}
	for _, job := range snapshot.Records {
		if job.AiListingKind == "role" && job.Title != "" && job.SourceURL != "" {
			rawSources = append(rawSources, job)
		}
	}
	// Equivalent roles from development/official mirrors are one template even
	// when Mongo ObjectId, sourceFingerprint and source ID all differ.
	byIdentity := map[string]Job{}
	for _, job := range rawSources {
		id := roleTemplateIdentity(job)
		if _, exists := byIdentity[id]; !exists {
			byIdentity[id] = job
		}
	}
	keys := make([]string, 0, len(byIdentity))
	for key := range byIdentity {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	sources := make([]Job, 0, len(keys))
	for _, key := range keys {
		sources = append(sources, byIdentity[key])
	}
	meta.SourceJobs = len(rawSources)
	meta.UniqueSourceRoles = len(sources)
	meta.DeduplicatedSourceRoles = len(rawSources) - len(sources)
	meta.LeakageAudit["rawSourceRoleRows"] = len(rawSources)
	meta.LeakageAudit["uniqueRoleTemplates"] = len(sources)
	meta.LeakageAudit["deduplicatedEquivalentRoles"] = meta.DeduplicatedSourceRoles
	if len(sources) < 15 {
		return meta, errors.New("source snapshot has too few role-specific records")
	}
	if jobCount < 30 || appCount < 50 || pairCount < 100 || lraRate < 0 || lraRate > 1 {
		return meta, errors.New("invalid sizes or category distribution")
	}
	r := rand.New(rand.NewSource(seed))
	jobs := make([]Job, 0, jobCount)
	seen := map[string]bool{}
	for tries := 0; len(jobs) < jobCount && tries < jobCount*50; tries++ {
		src := sources[r.Intn(len(sources))]
		j := makeJob(r, src, len(jobs), lraRate, seed)
		key := shortHash(j.SourceTemplateID + ":" + j.Title + ":" + strings.Join(j.RequiredSkills, ",") + ":" + strings.Join(j.PreferredSkills, ",") +
			":" + j.RequiredEducation + ":" + fmt.Sprint(j.MinExperienceYears) + ":" + strings.Join(j.RequiredLicenses, ",") + ":" + j.Category)
		if seen[key] {
			continue
		}
		seen[key] = true
		jobs = append(jobs, j)
		meta.Categories[j.Category]++
	}
	if len(jobs) < jobCount {
		return meta, errors.New("could not generate unique jobs")
	}
	jobsBySplit := map[string][]Job{}
	for _, j := range jobs {
		jobsBySplit[j.Split] = append(jobsBySplit[j.Split], j)
	}
	for _, split := range []string{"train", "validation", "test"} {
		if len(jobsBySplit[split]) < 5 {
			return meta, fmt.Errorf("too few jobs in %s split", split)
		}
	}
	applicants := make([]Applicant, 0, appCount)
	appsBySplit := map[string][]Applicant{}
	appSeen := map[string]bool{}
	splits := []string{"train", "validation", "test"}
	for k := 0; len(applicants) < appCount && k < appCount*25; k++ {
		split := splits[k%len(splits)]
		if k%10 < 7 {
			split = "train"
		} // about 70/15/15 after adding a second deterministic choice
		if k%20 == 17 {
			split = "validation"
		}
		if k%20 == 19 {
			split = "test"
		}
		candidates := jobsBySplit[split]
		j := candidates[r.Intn(len(candidates))]
		a := makeApplicant(r, j, len(applicants))
		a.Split = split
		key := shortHash(split + ":" + strings.Join(a.Skills, ",") + ":" + a.EducationLevel + ":" + fmt.Sprint(a.YearsExperience) + ":" +
			strings.Join(a.Licenses, ",") + ":" + a.ProfessionalTitle + ":" + a.AffinityJobID + ":" + fmt.Sprint(a.Incomplete))
		if appSeen[key] {
			continue
		}
		appSeen[key] = true
		applicants = append(applicants, a)
		appsBySplit[split] = append(appsBySplit[split], a)
	}
	if len(applicants) < appCount {
		return meta, errors.New("could not generate diverse applicants")
	}
	allJobs := map[string]Job{}
	for _, j := range jobs {
		allJobs[j.ID] = j
	}
	allApps := map[string]Applicant{}
	for _, a := range applicants {
		allApps[a.ID] = a
	}
	pairs := make([]Pair, 0, pairCount)
	pairSeen := map[string]bool{}
	positives := 0
	negatives := 0
	for k := 0; len(pairs) < pairCount && k < pairCount*35; k++ {
		split := splits[k%20%3]
		if k%10 < 7 {
			split = "train"
		} else if k%10 < 9 {
			split = "validation"
		} else {
			split = "test"
		}
		aa := appsBySplit[split]
		jj := jobsBySplit[split]
		a := aa[r.Intn(len(aa))]
		var j Job
		if r.Intn(10) < 7 {
			j = allJobs[a.AffinityJobID]
		} else {
			j = jj[r.Intn(len(jj))]
		}
		if j.Split != split {
			continue
		}
		key := a.ID + "|" + j.ID
		if pairSeen[key] {
			continue
		}
		pairSeen[key] = true
		f, _, _, _, _ := features(a, j)
		target, label := rubric(a, j)
		if target == 1 {
			positives++
		} else if target == 0 {
			negatives++
		}
		pairs = append(pairs, Pair{ApplicantID: a.ID, JobID: j.ID, JobCategory: j.Category, JobFamily: j.Family,
			Split: split, Features: f, Target: target, Label: label, Scenario: fmt.Sprintf("scenario-%d", k%10), IsSynthetic: true})
		meta.Labels[label]++
		meta.Splits[split]++
	}
	if len(pairs) < pairCount {
		return meta, errors.New("could not produce unique pairs")
	}
	if positives < pairCount/20 || negatives < pairCount/20 {
		return meta, fmt.Errorf("labels are unbalanced: %d positive %d negative", positives, negatives)
	}
	// Audit split identity independently from source IDs and mirrored URLs.
	familySplit := map[string]string{}
	roleSplit := map[string]string{}
	for _, j := range jobs {
		if prior, ok := familySplit[j.Family]; ok && prior != j.Split {
			return meta, errors.New("canonical document/notice family split leakage")
		}
		familySplit[j.Family] = j.Split
	}
	for _, src := range sources {
		id := roleTemplateIdentity(src)
		split := hashSplit(roleFamily(src), seed)
		if prior, ok := roleSplit[id]; ok && prior != split {
			return meta, errors.New("canonical mirrored role split leakage")
		}
		roleSplit[id] = split
	}
	for _, p := range pairs {
		if allApps[p.ApplicantID].Split != p.Split || allJobs[p.JobID].Split != p.Split {
			return meta, errors.New("pair split leakage")
		}
	}
	meta.LeakageAudit["uniqueNoticeFamiliesInGeneratedJobs"] = len(familySplit)
	meta.LeakageAudit["mirroredRoleCrossSplitOverlaps"] = 0
	meta.LeakageAudit["noticeFamilyCrossSplitOverlaps"] = 0
	meta.LeakageAudit["applicantCrossSplitOverlaps"] = 0
	meta.LeakageCheck = "PASS: canonical mirror-role, document/notice family, and applicant partitions have 0 cross-split overlaps"
	meta.Jobs = len(jobs)
	meta.Applicants = len(applicants)
	meta.Pairs = len(pairs)
	sort.Slice(jobs, func(i, j int) bool { return jobs[i].ID < jobs[j].ID })
	if e = saveJSONL(filepath.Join(out, "synthetic_jobs_v1.jsonl"), jobs); e != nil {
		return meta, e
	}
	if e = saveJSONL(filepath.Join(out, "synthetic_applicants_v1.jsonl"), applicants); e != nil {
		return meta, e
	}
	if e = saveJSONL(filepath.Join(out, "synthetic_pairs_v1.jsonl"), pairs); e != nil {
		return meta, e
	}
	return meta, saveJSON(filepath.Join(out, "dataset_manifest_v1.json"), meta)
}
