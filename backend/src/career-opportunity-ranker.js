/**
 * Evidence-aware career discovery on top of the existing trained Go occupation model.
 * Rank is an ordering signal, never an eligibility, hiring probability or qualification.
 * Only source-supported applicant skills and sourced role titles/Go evidence enter here.
 */
const safeText = value => String(value ?? '').toLowerCase()
  .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
  .replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();

const portableSkills = Object.freeze([
  { phrases: ['customer service', 'customer relations', 'client service'], fields: ['sales_retail', 'hospitality_food', 'personal_services', 'office_administration'] },
  { phrases: ['cash handling', 'cashiering', 'cash register'], fields: ['sales_retail', 'hospitality_food'] },
  { phrases: ['inventory', 'stock keeping', 'stock handling', 'stock management'], fields: ['logistics_warehouse', 'sales_retail', 'manufacturing_operations'] },
  { phrases: ['microsoft excel', 'ms excel', 'spreadsheet', 'data entry', 'data encoding'], fields: ['office_administration', 'data_services', 'accounting_finance', 'logistics_warehouse'] },
  { phrases: ['food preparation', 'food handling', 'food safety', 'cooking'], fields: ['hospitality_food', 'manufacturing_operations'] },
  { phrases: ['cleaning', 'housekeeping', 'sanitation'], fields: ['facility_services', 'hospitality_food'] },
  { phrases: ['welding', 'fabrication', 'smaw'], fields: ['construction_trades', 'manufacturing_craft'] },
  { phrases: ['electrical wiring', 'electrical repair', 'electrician'], fields: ['electrical_trades', 'technical_services'] },
  { phrases: ['equipment maintenance', 'machine operator'], fields: ['manufacturing_operations', 'technical_services', 'manufacturing_craft'] },
  { phrases: ['sales', 'retail sales', 'selling'], fields: ['sales_retail', 'hospitality_food'] },
  { phrases: ['driving', 'driver', 'route planning'], fields: ['driving_transport', 'logistics_warehouse'] },
]);
function hasPhrase(text, phrase) {
  const content = ' ' + safeText(text) + ' ';
  const token = ' ' + safeText(phrase) + ' ';
  const index = content.indexOf(token);
  if (index < 0) return false;
  // Negated qualifications are not evidence. Incomplete source facts must not
  // silently become transferable skills from the text surrounding a keyword.
  const before = content.slice(Math.max(0, index - 55), index);
  return !/(?:\b(?:no|not|without|never|lacks?|untrained in)\s*|\bno\s+(?:prior\s+)?(?:experience|background|training)\s+(?:in|with)\s*)$/.test(before);
}
const isStarterRole = title =>
  /(?:^|\s)(?:trainee|apprentice|intern|internship|helper)(?:\s|$)/.test(safeText(title));
const limitedList = value => Array.isArray(value) ? value.filter(x => typeof x === 'string').slice(0, 20) : [];

export function enrichCareerOpportunities(applicant, jobs, rows) {
  const applicantFields = new Set((applicant?.occupationCategories || [])
    .map(row => String(row?.field || ''))
    .filter(Boolean));
  const trustedSkills = limitedList(applicant?.skills).map(safeText).filter(Boolean);
  const bridgeFields = new Map();
  for (const skill of trustedSkills) {
    for (const bridge of portableSkills) {
      if (!bridge.phrases.some(phrase => hasPhrase(skill, phrase))) continue;
      for (const field of bridge.fields) {
        if (!bridgeFields.has(field)) bridgeFields.set(field, new Set());
        // Emit a standard skill label, never raw applicant-entered text.
        bridgeFields.get(field).add(bridge.phrases[0]);
      }
    }
  }
  const jobIndex = new Map(jobs.map(job => [String(job?._id ?? job?.id), job]));
  return rows.map(row => {
    const job = jobIndex.get(String(row.jobId));
    if (!job) return row;
    const title = String(job.title || '').split(/\s+[—–-]\s+/)[0];
    const roleFields = limitedList(row.occupationFieldsToExplore)
      .concat(limitedList(row.matchedOccupationFields));
    const directFields = limitedList(row.matchedOccupationFields)
      .filter(field => applicantFields.has(field));
    const transferSkills = [...new Set(roleFields.flatMap(field =>
      [...(bridgeFields.get(field) || [])]))];
    const jobTitleClues = limitedList(row.matchedTitleClues);
    const roleSkills = limitedList(row.matchedSkills);
    const gaps = limitedList(row.missingMandatory);
    const starterTitle = isStarterRole(title);
    const recognizedSkills = bridgeFields.size > 0 || applicantFields.size > 0;
    const recordedWorkHistory = Number(applicant?.yearsExperience || 0) > 0;
    const direct = directFields.length > 0;
    const transferable = transferSkills.length > 0;
    const verifiedRoleEvidence = row.assessmentBasis === 'role_attributed_requirements' &&
      Number(row.roleCriteriaCount || 0) > 0 &&
      ['medium', 'moderate'].includes(row.confidence);
    // A stated, attributable unmet requirement is a warning, not a rejection.
    const needsRequirementReview = gaps.length > 0 && verifiedRoleEvidence;
    // Keep trainee/helper roles visible for newcomers, but avoid suggesting
    // unrelated beginner work to people with documented career skills.
    const starterBoost = !starterTitle ? 0
      : !recognizedSkills && !recordedWorkHistory ? 24
      : direct || transferable ? 12 : 0;
    const signals = [];
    if (direct) signals.push('saved_career_field');
    if (transferable) signals.push('transferable_skills');
    if (jobTitleClues.length) signals.push('job_title_skills');
    if (roleSkills.length && verifiedRoleEvidence) signals.push('documented_role_skills');
    if (verifiedRoleEvidence) signals.push('employer_criteria_attributed');
    if (starterBoost > 0) signals.push('training_or_helper_title');
    if (needsRequirementReview) signals.push('employer_requirement_review');
    if (!verifiedRoleEvidence) signals.push('requirements_unverified');
    let rank = (direct ? 50 : 0) +
      Math.min(30, transferSkills.length * 14) +
      Math.min(18, jobTitleClues.length * 9) +
      (verifiedRoleEvidence ? (Math.min(18, roleSkills.length * 9) + 6) : 0) +
      starterBoost;
    if (needsRequirementReview) rank = Math.max(0, rank - 30);
    rank = Math.min(100, Math.max(0, rank));
    const pathway = needsRequirementReview ? 'review_requirements'
      : direct ? 'related_career_field'
      : transferable ? 'transferable_skills'
      : starterTitle && starterBoost > 0 ? 'training_pathway'
      : 'explore';
    return { ...row, opportunityRank: rank, opportunityPathway: pathway,
      opportunitySignals: signals,
      // Limited supported skill signals, not a list of employer requirements.
      opportunitySkillClues: transferSkills.slice(0, 4) };
  });
}
