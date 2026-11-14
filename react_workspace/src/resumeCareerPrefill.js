export function buildResumeCareerPrefillUpdates(draft = {}, touched = {}, choices = {}) {
  const updates = {};
  for (const key of ['education', 'experience', 'skillsStage']) {
    if (touched[key] === true) continue;
    const allowed = Array.isArray(choices[key]) ? choices[key] : [];
    updates[key] = allowed.includes(draft[key]) ? draft[key] : '';
  }
  if (touched.skills !== true) {
    updates.skills = typeof draft.skills === 'string' ? draft.skills : '';
  }
  return updates;
}
