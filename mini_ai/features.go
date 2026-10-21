package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

type OccupationCategory struct {
	Field          string `json:"field"`
	IscoMajorGroup string `json:"iscoMajorGroup"`
}

type Job struct {
	ID                       string               `json:"id"`
	Title                    string               `json:"title"`
	Company                  string               `json:"company"`
	Location                 string               `json:"location,omitempty"`
	Salary                   string               `json:"salary,omitempty"`
	EmploymentType           string               `json:"employmentType,omitempty"`
	Description              string               `json:"description"`
	Requirements             []string             `json:"requirements"`
	Category                 string               `json:"category"`
	SourceFingerprint        string               `json:"sourceFingerprint,omitempty"`
	SourceTemplateID         string               `json:"sourceTemplateId,omitempty"`
	PublicPdfSourceID        string               `json:"publicPdfSourceId,omitempty"`
	SourceURL                string               `json:"sourceUrl,omitempty"`
	SourceDocumentHash       string               `json:"sourceDocumentHash,omitempty"`
	SourceTitle              string               `json:"sourceTitle,omitempty"`
	SourcePageStart          int                  `json:"sourcePageStart,omitempty"`
	SourcePageEnd            int                  `json:"sourcePageEnd,omitempty"`
	ParentFingerprint        string               `json:"parentFingerprint,omitempty"`
	AiListingKind            string               `json:"aiListingKind,omitempty"`
	RequirementScope         string               `json:"requirementScope,omitempty"`
	SourceRoleCount          int                  `json:"sourceRoleCount,omitempty"`
	UnattributedRequirements []string             `json:"unattributedRequirements,omitempty"`
	RequiredSkills           []string             `json:"requiredSkills,omitempty"`
	PreferredSkills          []string             `json:"preferredSkills,omitempty"`
	RequiredLicenses         []string             `json:"requiredLicenses,omitempty"`
	RequiredEducation        string               `json:"requiredEducation,omitempty"`
	MinExperienceYears       int                  `json:"minExperienceYears,omitempty"`
	Family                   string               `json:"family,omitempty"`
	Split                    string               `json:"split,omitempty"`
	IsSynthetic              bool                 `json:"isSynthetic"`
	OccupationCategories     []OccupationCategory `json:"occupationCategories,omitempty"`
}

type Applicant struct {
	ID                   string               `json:"id"`
	Skills               []string             `json:"skills"`
	EducationLevel       string               `json:"educationLevel,omitempty"`
	YearsExperience      int                  `json:"yearsExperience"`
	Certifications       []string             `json:"certifications,omitempty"`
	Licenses             []string             `json:"licenses,omitempty"`
	ProfessionalTitle    string               `json:"professionalTitle,omitempty"`
	EmploymentStatus     string               `json:"employmentStatus,omitempty"`
	ResumeText           string               `json:"resumeText,omitempty"`
	Incomplete           bool                 `json:"incomplete,omitempty"`
	AffinityJobID        string               `json:"affinityJobId,omitempty"`
	Split                string               `json:"split,omitempty"`
	IsSynthetic          bool                 `json:"isSynthetic"`
	OccupationCategories []OccupationCategory `json:"occupationCategories,omitempty"`
}

type Pair struct {
	ApplicantID string    `json:"applicantId"`
	JobID       string    `json:"jobId"`
	JobCategory string    `json:"jobCategory"`
	JobFamily   string    `json:"jobFamily"`
	Split       string    `json:"split"`
	Features    []float64 `json:"features"`
	Target      int       `json:"target"`
	Label       string    `json:"label"`
	Scenario    string    `json:"scenario"`
	IsSynthetic bool      `json:"isSynthetic"`
}

type Snapshot struct {
	SchemaVersion int    `json:"schemaVersion"`
	Kind          string `json:"kind"`
	Total         int    `json:"total"`
	Records       []Job  `json:"records"`
}

type Result struct {
	JobID                     string             `json:"jobId"`
	Score                     int                `json:"score"`
	ModelVersion              string             `json:"modelVersion"`
	Readiness                 string             `json:"readiness"`
	Confidence                string             `json:"confidence"`
	AssessmentBasis           string             `json:"assessmentBasis"`
	RoleCriteriaCount         int                `json:"roleCriteriaCount"`
	OccupationTaxonomy        string             `json:"occupationTaxonomy,omitempty"`
	MatchedOccupationFields   []string           `json:"matchedOccupationFields"`
	OccupationFieldsToExplore []string           `json:"occupationFieldsToExplore"`
	MatchedTitleClues         []string           `json:"matchedTitleClues"`
	SkillsToExplore           []string           `json:"skillsToExplore"`
	MatchedSkills             []string           `json:"matchedSkills"`
	MissingSkills             []string           `json:"missingSkills"`
	MatchedPreferred          []string           `json:"matchedPreferred"`
	MissingMandatory          []string           `json:"missingMandatory"`
	NeedsReview               []string           `json:"needsReview"`
	ExcludedRequirements      []string           `json:"excludedRequirements"`
	FeatureContributions      map[string]float64 `json:"featureContributions"`
	SourceURL                 string             `json:"sourceUrl,omitempty"`
	SourcePageStart           int                `json:"sourcePageStart,omitempty"`
}

var skillAliases = map[string][]string{
	"sales":                  {"sales", "selling", "retail sales", "promodiser"},
	"communication":          {"communication", "customer communication", "verbal and written"},
	"customer_service":       {"customer service", "customer assistant", "front desk", "client service"},
	"cash_handling":          {"cashier", "cash handling", "cashiering", "cash register"},
	"inventory":              {"inventory", "stock keeping", "stock custodian", "stockman"},
	"office_tools":           {"ms office", "microsoft office", "excel", "spreadsheet", "word processing"},
	"data_entry":             {"data entry", "encoder", "typing", "filing"},
	"accounting":             {"accounting", "bookkeeping", "accounts payable", "finance", "auditing"},
	"driving":                {"driving", "driver", "delivery", "rider"},
	"vehicle_repair":         {"mechanic", "automotive repair", "vehicle repair", "maintenance of vehicles"},
	"electricity":            {"electrician", "electrical", "wiring", "electrical installation"},
	"welding":                {"welder", "welding", "smaw"},
	"construction":           {"construction", "carpentry", "masonry", "building works"},
	"heavy_equipment":        {"heavy equipment", "excavator", "bulldozer", "forklift", "backhoe", "equipment operator"},
	"warehouse":              {"warehouse", "warehousing", "packing", "picking"},
	"logistics":              {"logistics", "dispatch", "route planning", "delivery operations"},
	"safety":                 {"occupational safety", "ehs", "osh", "workplace safety", "safety officer", "safety staff", "hse"},
	"food_service":           {"cook", "chef", "kitchen", "food handling", "fryer"},
	"healthcare":             {"nurse", "nursing", "patient care", "medical"},
	"teaching":               {"teacher", "teaching", "tutoring", "instruction"},
	"programming":            {"programming", "developer", "software", "coding"},
	"information_technology": {"ict", "information technology", "computer technician", "it support", "networking"},
	"graphic_design":         {"graphic design", "photography", "adobe", "layout"},
	"collections":            {"collection officer", "collector", "debt collection", "microfinance", "field collection"},
	"administration":         {"administrative", "admin assistant", "office admin", "secretarial", "clerk"},
	"supervision":            {"supervisor", "manager", "team leader", "supervisory", "branch manager"},
	"machinery":              {"machine operator", "production line", "industrial machine", "manufacturing", "assembly"},
	"security":               {"security officer", "guard", "security procedures"},
	"marketing":              {"marketing", "market research", "brand management"},
	"legal":                  {"paralegal", "legal research", "legal assistant"},
}
var allSkills = func() []string {
	out := make([]string, 0, len(skillAliases))
	for k := range skillAliases {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}()
var featureNames = []string{"mandatory_coverage", "preferred_coverage", "missing_mandatory", "experience_fit", "education_fit", "license_fit", "title_alignment", "transferable_coverage", "profile_completeness", "evidence_quality", "experience_depth"}

func normalized(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	for _, ch := range []string{"-", "_", "/", "–", "—", ",", ":", "(", ")", ".", ";", "\n", "\t"} {
		s = strings.ReplaceAll(s, ch, " ")
	}
	return " " + strings.Join(strings.Fields(s), " ") + " "
}
func containsPhrase(text, term string) bool {
	t := normalized(text)
	p := normalized(term)
	return strings.Contains(t, p)
}
func canonicalSkills(items []string) []string {
	seen := map[string]bool{}
	for _, item := range items {
		k := strings.TrimSpace(strings.ToLower(item))
		if _, ok := skillAliases[k]; ok {
			seen[k] = true
			continue
		}
		for key, aliases := range skillAliases {
			for _, term := range aliases {
				if containsPhrase(item, term) {
					seen[key] = true
					break
				}
			}
		}
	}
	out := []string{}
	for k := range seen {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
func skillsFromText(text string) []string { return canonicalSkills([]string{text}) }
func unique(in []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, x := range in {
		x = strings.TrimSpace(x)
		if x != "" && !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	sort.Strings(out)
	return out
}
func intersect(want, have []string) (matched, missing []string) {
	has := map[string]bool{}
	for _, x := range canonicalSkills(have) {
		has[x] = true
	}
	for _, x := range canonicalSkills(want) {
		if has[x] {
			matched = append(matched, x)
		} else {
			missing = append(missing, x)
		}
	}
	if matched == nil {
		matched = []string{}
	}
	if missing == nil {
		missing = []string{}
	}
	return
}
func proportion(matched, missing []string) float64 {
	if len(matched)+len(missing) == 0 {
		return 1
	}
	return float64(len(matched)) / float64(len(matched)+len(missing))
}
func educationRank(s string) int {
	t := normalized(s)
	switch {
	case strings.Contains(t, "postgraduate") || strings.Contains(t, "master") || strings.Contains(t, "doctorate"):
		return 5
	case strings.Contains(t, "bachelor") || strings.Contains(t, "college graduate") || strings.Contains(t, "4 year") || strings.Contains(t, "college degree"):
		return 4
	case strings.Contains(t, "college") || strings.Contains(t, "associate"):
		return 3
	case strings.Contains(t, "vocational") || strings.Contains(t, "techvoc") || strings.Contains(t, "tesda"):
		return 2
	case strings.Contains(t, "high school") || strings.Contains(t, "senior high") || strings.Contains(t, "grade 10"):
		return 1
	default:
		return 0
	}
}

// Protected and demographic criteria are provenance/review data only. They never
// enter inference features, synthetic labels, model scores or confidence.
var protectedRequirementPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)\b(?:male|female|men|women|man|woman|boys?|girls?|ladies|gentlemen|gender|sex|marital|civil status|religion|age|aged|birthdate|date of birth|pregnan\w*|pwd|person with disability)\b`),
	regexp.MustCompile(`(?i)\b(?:[0-9]{1,2}\s*(?:years?|yrs?)\s*old|m\s*/\s*f|f\s*/\s*m|must\s+be\s+single|single\s+applicant)\b`),
}

func protectedRequirement(raw string) bool {
	for _, pattern := range protectedRequirementPatterns {
		if pattern.MatchString(raw) {
			return true
		}
	}
	return false
}
func reviewedRequirements(j Job) (accepted, excluded, unattributed []string) {
	role := strings.TrimSpace(strings.Split(j.Title, " — ")[0])
	// Old importer records had no scope metadata and copied every notice-wide
	// requirement to every role. Fail closed unless explicitly role-attributed.
	singleRole := j.AiListingKind == "role" && j.RequirementScope == "single_role" && j.SourceRoleCount == 1
	for _, raw := range j.Requirements {
		t := strings.TrimSpace(raw)
		if t == "" {
			continue
		}
		lower := strings.ToLower(t)
		if strings.Contains(lower, "confirm current availability") ||
			strings.Contains(lower, "role-specific qualifications differ") ||
			strings.Contains(lower, "insurance") || strings.Contains(lower, "performance bonus") ||
			strings.Contains(lower, "hmo after") || strings.Contains(lower, "direct hire") {
			continue
		}
		if j.AiListingKind == "notice" {
			if protectedRequirement(t) {
				excluded = append(excluded, t)
			} else {
				unattributed = append(unattributed, t)
			}
			continue
		}
		if j.AiListingKind == "role" {
			explicit := false
			if idx := strings.Index(t, ":"); idx > 0 && idx < 85 {
				prefix := strings.TrimSpace(t[:idx])
				if normalized(prefix) == normalized(role) {
					explicit = true
					t = strings.TrimSpace(t[idx+1:])
				} else if !singleRole {
					if protectedRequirement(t) {
						excluded = append(excluded, t)
					} else {
						unattributed = append(unattributed, t)
					}
					continue
				}
			}
			if !explicit && !singleRole {
				if protectedRequirement(t) {
					excluded = append(excluded, t)
				} else {
					unattributed = append(unattributed, t)
				}
				continue
			}
		}
		if !protectedRequirement(t) {
			accepted = append(accepted, t)
			continue
		}
		// A role-specific source line may combine a protected criterion with
		// independently separable, legitimate qualifications. Drop ONLY clauses
		// that mention protected traits, and never infer meaning across clauses.
		// Without a clear comma/semicolon boundary, exclude the entire phrase.
		for _, clause := range strings.FieldsFunc(t, func(r rune) bool {
			return r == ',' || r == ';'
		}) {
			clause = strings.TrimSpace(clause)
			if clause == "" {
				continue
			}
			if protectedRequirement(clause) {
				excluded = append(excluded, clause)
			} else {
				accepted = append(accepted, clause)
			}
		}
	}
	for _, raw := range j.UnattributedRequirements {
		if protectedRequirement(raw) {
			excluded = append(excluded, raw)
		} else if strings.TrimSpace(raw) != "" {
			unattributed = append(unattributed, raw)
		}
	}
	return unique(accepted), unique(excluded), unique(unattributed)
}
func safeRequirements(j Job) []string {
	safe, _, _ := reviewedRequirements(j)
	return safe
}
func inferredJob(j Job) Job {
	if j.IsSynthetic {
		j.RequiredSkills = canonicalSkills(j.RequiredSkills)
		j.PreferredSkills = canonicalSkills(j.PreferredSkills)
		return j
	}
	reqs := safeRequirements(j)
	needed := []string{}
	preferred := []string{}
	license := []string{}
	titleSkills := skillsFromText(strings.Split(j.Title, " — ")[0])
	for _, r := range reqs {
		low := strings.ToLower(r)
		found := skillsFromText(r)
		if strings.Contains(low, "plus") || strings.Contains(low, "preferred") || strings.Contains(low, "advantage") {
			preferred = append(preferred, found...)
		} else if strings.Contains(low, "required") || strings.Contains(low, "with ") || strings.Contains(low, "must") || strings.Contains(low, "at least") {
			needed = append(needed, found...)
		}
		if (strings.Contains(low, "driver") || strings.Contains(low, "driving")) && strings.Contains(low, "license") {
			license = append(license, "driver_license")
		}
		if strings.Contains(low, "nc ii") && strings.Contains(low, "required") {
			license = append(license, "nc_ii")
		}
		if strings.Contains(low, "high school") {
			j.RequiredEducation = "high_school"
		}
		if strings.Contains(low, "4-year course") || strings.Contains(low, "college graduate") || strings.Contains(low, "bachelor") {
			j.RequiredEducation = "college"
		}
		if strings.Contains(low, "vocational") && j.RequiredEducation == "" {
			j.RequiredEducation = "techvoc"
		}
	}
	// Title skills are relevant but not automatically mandatory: only explicit
	// qualifying language may create a mandatory gap on genuine sourced jobs.
	j.RequiredSkills = unique(needed)
	j.PreferredSkills = unique(append(preferred, titleSkills...))
	j.RequiredLicenses = unique(license)
	if len(reqs) == 0 {
		j.Description = ""
	}
	return j
}
func hasLicense(a Applicant, license string) bool {
	for _, l := range append(append([]string{}, a.Licenses...), a.Certifications...) {
		if strings.EqualFold(l, license) || (license == "driver_license" && containsPhrase(l, "driver")) || (license == "nc_ii" && containsPhrase(l, "nc ii")) {
			return true
		}
	}
	return false
}
func features(a Applicant, j0 Job) ([]float64, []string, []string, []string, []string) {
	j := inferredJob(j0)
	known := canonicalSkills(append(append([]string{}, a.Skills...), skillsFromText(a.ResumeText)...))
	mand, missing := intersect(j.RequiredSkills, known)
	pref, missingPref := intersect(j.PreferredSkills, known)
	fit := 1.0
	if j.MinExperienceYears > 0 {
		fit = math.Min(1, float64(max(0, a.YearsExperience))/float64(j.MinExperienceYears))
	}
	edu := 1.0
	if j.RequiredEducation != "" {
		if educationRank(a.EducationLevel) == 0 {
			edu = 0.5
		} else if educationRank(a.EducationLevel) < educationRank(j.RequiredEducation) {
			edu = 0
		}
	}
	licenseFit := 1.0
	for _, req := range j.RequiredLicenses {
		if !hasLicense(a, req) {
			licenseFit = 0
			break
		}
	}
	titleMatch := 0.0
	if len(known) > 0 {
		x, y := intersect(skillsFromText(j.Title), known)
		titleMatch = proportion(x, y)
	}
	transfer := 0.0
	if len(known) > 0 {
		x, y := intersect(append(j.RequiredSkills, j.PreferredSkills...), known)
		transfer = proportion(x, y)
	}
	completeness := 0.0
	for _, ok := range []bool{len(a.Skills) > 0, a.EducationLevel != "", a.ProfessionalTitle != "", a.YearsExperience > 0 || !a.Incomplete} {
		if ok {
			completeness += 0.25
		}
	}
	evidence := 1.0
	if len(j.RequiredSkills)+len(j.PreferredSkills)+len(safeRequirements(j0)) == 0 {
		evidence = 0.25
	}
	if len(a.Skills) == 0 && a.ResumeText == "" {
		evidence *= 0.5
	}
	if a.Incomplete {
		evidence *= 0.65
	}
	expDepth := math.Min(1, float64(max(0, a.YearsExperience))/6)
	out := []float64{proportion(mand, missing), proportion(pref, missingPref), float64(len(missing)) / float64(max(1, len(j.RequiredSkills))), fit, edu, licenseFit, titleMatch, transfer, completeness, evidence, expDepth}
	return out, mand, missing, pref, missingPref
}
func rubric(a Applicant, j Job) (int, string) {
	x, _, missing, _, _ := features(a, j)
	if a.Incomplete || x[9] < 0.4 {
		return -1, "needs_review"
	}
	if x[0] >= 0.95 && len(missing) == 0 && x[3] >= 1 && x[4] >= 1 && x[5] >= 1 {
		return 1, "strong_or_meets_mandatory"
	}
	return 0, "development_gap"
}
func hashSplit(s string, seed int64) string {
	raw := sha256.Sum256([]byte(fmt.Sprintf("%d|%s", seed, s)))
	v := (int(raw[0])*256 + int(raw[1])) % 100
	if v < 70 {
		return "train"
	}
	if v < 85 {
		return "validation"
	}
	return "test"
}
func shortHash(s string) string { h := sha256.Sum256([]byte(s)); return hex.EncodeToString(h[:])[:12] }
func asNumber(v any) int {
	switch x := v.(type) {
	case float64:
		return int(x)
	case int:
		return x
	case string:
		n, _ := strconv.Atoi(x)
		return n
	}
	return 0
}
func mustJson(v any) []byte {
	b, e := json.Marshal(v)
	if e != nil {
		panic(e)
	}
	return b
}
