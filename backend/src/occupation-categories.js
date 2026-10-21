/**
 * ISCO-08 major groups with broad occupational fields for global matching.
 * This is an ontology of non-mandatory skill domains, NOT an employer's hiring
 * criteria. Source: ILO ISCO-08; local PH titles can map into the same groups.
 */
export const ISCO_MAJOR_GROUPS = Object.freeze({
  '0': 'Armed Forces Occupations',
  '1': 'Managers',
  '2': 'Professionals',
  '3': 'Technicians and Associate Professionals',
  '4': 'Clerical Support Workers',
  '5': 'Service and Sales Workers',
  '6': 'Skilled Agricultural, Forestry and Fishery Workers',
  '7': 'Craft and Related Trades Workers',
  '8': 'Plant and Machine Operators, and Assemblers',
  '9': 'Elementary Occupations',
});

// Each field works across many individual job titles and qualification levels.
// Distinct roles can share fields while remaining separate occupations.
const rows = [
  ['management', '1', 'manager|management|supervisor|team leader|director|operations head|project lead|officer in charge|branch oic|coordinator|leadman|line leader'],
  ['engineering', '2,3', 'engineer|engineering|architect|surveyor|civil design|mechanical design|technical drawing'],
  ['science_research', '2,3', 'scientist|research|laboratory|chemist|biology|physics|statistician|geologist'],
  ['healthcare', '2,3,5', 'nurs|patient care|healthcare|medical|clinical|hospital|pharmacy|pharmacist|veterinary|veterinarian|midwi|dental'],
  ['education', '2,3', 'teach|instruct|tutor|educat|classroom|professor|lecturer|school'],
  ['software_technology', '2,3', 'programming|software|coding|developer|database|computer technician|it support|network administration|web development|cybersecurity|i.t.|network technician|wifi technician|fiber optic|network support'],
  ['accounting_finance', '2,3,4', 'accounting|bookkeeping|bookkeeper|finance|auditing|auditor|audit|payroll|financial analysis|taxation|cost control|financial analyst|fixed asset|collection|collector|telecollector|repossessor'],
  ['law_social', '2,3', 'lawyer|legal|paralegal|social work|counseling|community outreach|social worker'],
  ['creative_media', '2,3,5', 'graphic design|editing video|photography|photographer|designer|illustrat|journalism|media production|digital art|social media|3d imaging|visualization'],
  ['office_administration', '4', 'office|clerical|clerk|admin|administrat|secretary|filing|records|executive assistant|operations assistant|business department|document processing|ms excel|microsoft excel|spreadsheet'],
  ['data_services', '4,3', 'data entry|data encoding|encoder|typing|data analyst|data processing|database entry'],
  ['sales_retail', '5,1', 'retail|sales|selling|merchandis|promodiser|store attendant|cashier|customer service|customer|marketing associate|marketing|promoter|brand associate|account executive|account specialist|field representative|business development|business dev|cash handling'],
  ['hospitality_food', '5,9', 'restaurant|hotel|hospitality|food service|cook|chef|kitchen|waiter|waitress|barista|food preparation|fryer|steward'],
  ['personal_services', '5', 'caregiver|beauty advisor|hairdresser|salon|personal care|fitness trainer|cosmetology'],
  ['protection_service', '5,0', 'security guard|police|firefighter|protection services|armed forces|military|soldier|cctv|surveillance operator'],
  ['agriculture', '6,9', 'agricultur|farmer|crop|horticultur|livestock|farm work|plant nursery|poultry|gamefowl|animal raising'],
  ['fishery_forestry', '6', 'fishery|fishing|forestry|logging|aquaculture|fish farming'],
  ['construction_trades', '7,9', 'construction|masonry|mason|carpenter|welding|welder|plumbing|plumber|steel fixer|bricklay|scaffolder|scaffold|rigger|rigging|painter|concrete|pumpcrete|vibro|subcontractor|subcon'],
  ['electrical_trades', '7,3', 'electrician|electrical wiring|electrical installation|electrical repair|electronics technician|lineman|power line|electrical technician|elevator|escalator|generator|gen-set|foc splicer|splicer'],
  ['automotive_repair', '7,3', 'mechanic|auto repair|vehicle repair|automotive|auto electrician|diesel engine|auto painter'],
  ['manufacturing_craft', '7,8', 'machinist|machining|fabrication|metal work|textile|furniture making|woodwork|tailoring'],
  ['manufacturing_operations', '8,9', 'machine operator|production operator|machine operators|production|qc analyst|quality control|quality assurance|assembly|factory|manufacturing|plant operation|production line|repacker'],
  ['driving_transport', '8', 'driver|driving|truck|bus operator|delivery rider|transport|fleet|motorcycle courier|forklift|bulldozer|backhoe|excavator|crane operator|heavy equipment|motorcycle rider'],
  ['logistics_warehouse', '4,8,9', 'warehouse|logistics|inventory|stock keeper|stockman|packing|dispatch|shipping|supply chain|bagger|replenisher|refiller|stock custodian|stockkeeper'],
  ['facility_services', '9', 'cleaning|cleaner|housekeeping|janitor|utility worker|utility staff|utilityman|facility maintenance|building maintenance|building attendant'],
  ['general_labor', '9', 'helper|laborer|labourer|labor|manual handling|general worker|site assistant|pahinante|delivery crew|bagger'],
  ['environment_safety', '3,2', 'safety officer|safety inspector|occupational safety|industrial hygiene|environmental management|pollution control|ehs|hse|osh'],
  ['human_resources', '2,4', 'recruitment|human resources|hr staff|staffing|employee relations'],
  ['technical_services', '3,7', 'technician|technical support|field service|technical coordinator|product specialist|technical specialist|maintenance technician|tsd technician|technical operations'],
  ['hvac_refrigeration', '3,7', 'refrigeration|aircon|air conditioning|hvac|cooling system|chiller technician'],
];
export const CAREER_FIELDS = Object.freeze(Object.fromEntries(rows.map(([code, majors, terms]) => [
  code, Object.freeze({ code, iscoMajorGroups: Object.freeze(majors.split(',')),
    terms: Object.freeze(terms.split('|')) }),
])));
export const OCCUPATION_TAXONOMY = 'ISCO-08-broad-fields';

function canonical(text) {
  return String(text ?? '').normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
}
function includesTerm(text, term) {
  const termText = canonical(term);
  const full = ' ' + canonical(text) + ' ';
  if (termText.length < 3) return false;
  // Word starts cover ordinary inflections ("nurs" -> nurse/nursing,
  // "teach" -> teacher/teaching) without matching inside unrelated words.
  return canonical(text).split(/\s+/).some(part =>
    part === termText || (termText.length >= 4 && part.startsWith(termText))) ||
    full.includes(' ' + termText + ' ');
}
function supportsField(text, field) {
  return field.terms.some(term => includesTerm(text, term));
}
const UNSAFE = /\b(?:male|female|gender|sex|marital|religion|birth|disability|age|years old|nationality|ethnicity|pregnan)\b/i;
function safeQuote(quote, sourceText) {
  const text = canonical(quote), source = canonical(sourceText);
  return text.length >= 4 && text.length <= 220 && source.length > 0 &&
    source.includes(text) && !UNSAFE.test(quote);
}

/**
 * Gemini can propose occupational CATEGORIES ONLY with a supporting verbatim
 * excerpt. Unsupported, protected, mismatched group/field or invented excerpts
 * have no influence on matching. Categories do not create credentials.
 */
export function verifyOccupationCategories(proposals, sourceText) {
  const output = [];
  const seen = new Set();
  for (const candidate of (Array.isArray(proposals) ? proposals : []).slice(0, 12)) {
    if (!candidate || typeof candidate !== 'object') continue;
    const field = CAREER_FIELDS[String(candidate.field || '')];
    const quote = String(candidate.evidenceQuote || '').trim().slice(0, 220);
    if (!field || !safeQuote(quote, sourceText) || !supportsField(quote, field)) continue;
    const proposedMajor = String(candidate.iscoMajorGroup ?? '').trim();
    const major = field.iscoMajorGroups.includes(proposedMajor)
      ? proposedMajor : field.iscoMajorGroups[0];
    if (seen.has(field.code)) continue;
    seen.add(field.code);
    output.push({ field: field.code, iscoMajorGroup: major, evidenceQuote: quote,
      provenance: 'source_corroborated_gemini_category' });
    if (output.length >= 5) break;
  }
  return output;
}

/**
 * Conservative occupation tags from independently source-supported skills and
 * roles. Only used during resume/NSRP absorption, never per-job reclassification
 * or to upgrade unsupported AI-only qualifications.
 */
export function deriveCategoriesFromVerifiedFacts(skills, title = '') {
  const known = [...(Array.isArray(skills) ? skills : []), title]
    .filter(x => typeof x === 'string' && x.length <= 180);
  const scored = Object.values(CAREER_FIELDS).map(field => ({
    field, hits: known.filter(value => supportsField(value, field)).length,
    proof: known.find(value => supportsField(value, field)) || '',
  })).filter(item => item.hits > 0)
    .sort((a,b) => b.hits - a.hits || a.field.code.localeCompare(b.field.code));
  return scored.slice(0, 5).map(item => ({
    field: item.field.code,
    iscoMajorGroup: item.field.iscoMajorGroups[0],
    evidenceQuote: item.proof,
    provenance: 'derived_from_verified_intake_facts',
  }));
}

/** A new job can be categorized locally from its title, with no Gemini call. */
export function classifyJobOccupation(title) {
  const cleaned = String(title || '').split(' — ')[0].slice(0, 160);
  const categories = deriveCategoriesFromVerifiedFacts([], cleaned);
  return categories.map(x => ({ field: x.field, iscoMajorGroup: x.iscoMajorGroup }));
}
