# Adaptive job requirements — integration checkpoint (2026-10-20)

## Objective
Adapt to newly posted jobs using the existing Gemini PDF extraction and existing saved Go Mini-AI, without retraining after every job or inventing mandatory criteria.

## Concurrent development boundary
Another ChatGPT session is working on translation, profile images, applicant Excel integration, Flutter animations, qualification editing and Gemini key-pool health. This pass deliberately did **not** edit those subsystems, `backend/server.js`, `backend/src/gemini-provider.js`, `gemini-key-rotator.js`, the Flutter project, or any Go training/model files. No repo reset, staging, commit, service restart, live data mutation, or actual Gemini request was performed.

## Implemented files
- **NEW** `backend/src/role-requirement-evidence.js`: validates optional `listings[].roleRequirements[]` fields (role, requirement, kind, evidenceQuote, page). Exact role identity, exact page, quote starting with the role, explicitly stated mandatory/preferred language, absence of demographic/negated claims, and independent local PDF text corroboration are all required for a requirement to be promoted. Untrusted Gemini-supplied verified/status flags are ignored by the ingestion normalizer.
- **NEW** `backend/src/role-requirement-evidence.test.js`: new-job Go inference, source verification, malformed/forged status handling, cross-role bleed, wrong page, protected criteria, ambiguous or negated mandatory rules, request count and source extractor caching.
- `backend/src/gemini-public-pdf-reader.js`: bounded optional role-requirements instruction in the existing batch prompt. The normalized output retains proposals with status. Local PDF.js text is independently extracted **only when proposals exist**; parsed once per PDF, best effort, text-accessible PDFs up to 40 pages. Scanned/large/unextractable PDFs fall back to `needs_source_review` without interrupting registration, job display or Gemini extraction, and without extra Gemini requests.
- `backend/src/public-pdf-ai-listings.js`: correlates proposals to individual role cards and passes only source-text-corroborated requirements through existing Go-compatible `Role: requirement required/preferred` strings. Unverified proposals remain in review metadata/unattributed list, never mandatory gaps. Records explicitly state `independentlyValidatedByEmployer: false`. Existing notices still cannot be scored as aggregate roles.

## Existing behavior preserved
- Admin-created jobs already provide a structured, dynamic Go inference input; a newly posted manual job is not automatically sent to Gemini. Matching remains possible with the existing learned Go model.
- Legacy notice-wide requirements are not copied to every role; multi-role parent fingerprint grouping remains unchanged.
- Existing Firebase auth, quota/key selection, Flutter profile data handling, applicant-editable source data, Go parameters/features/training, and protected-criteria safeguards are untouched by this task.
- Current source-ingestion caching skips unchanged PDFs; fresh/newly changed PDFs are handled on the next successful source sync. This pass deliberately did not force resync.

## Verification
- `npm run check` in `backend/`: **201/201 passed**, exit 0.
- Focused reader/importer/mini-AI/new-evidence tests previously: **39/39 passed**, exit 0; expanded tests including guard cases now included in full run.
- Node syntax checks for new helper, reader and importer: exit 0 each.
- `go test -count=1 ./...` in `mini_ai/`: PASS, exit 0.
- Production Go model SHA-256 remains `C7F34B0DEAEBE793331273927A275341DAB441BE562EE131250282C5902E41EB`, identical to `mini_ai/data/experiments_20261020/model_v1_baseline.json`.
- No live applicant or real employer qualifications used as training labels; all new job scenarios are in-memory QA fixtures.

## Deployment and truthfulness
- **Not yet deployed into the existing Node process.** The backend is being edited by another session; a normal restart also triggers public PDF re-publication and could write live Mongo records. Coordinate a controlled rollout after the other session finishes; never silently restart it in parallel.
- **Authenticated Gemini 3.8 -> PDF parse -> local quote verification -> live Go -> Flutter browser** remains unverified. No real Gemini request was spent here, and no API keys or user PII were accessed.
- If the PDF is a scan, too long for local text verification, or its mandatory condition is ambiguous, the new requirement stays under source review. A human PDF/employer review is still required for authoritative hiring qualification criteria; model scores remain advisory.
- Current free-tier rates must be read from the actual Google AI Studio project, not inferred or hardcoded. Gemini 3.7 Flash is deprecated and currently routed to 3.8 Flash according to official Google documentation.

## Future acceptance
1. On a controlled authenticated account, create a real admin test posting using its true, human-confirmed requirements (no synthetic job inserted into live collection), check that Go returns selected job ID and visible review notes without retraining.
2. On an authorized newly updated source PDF, verify Gemini actually emits optional `roleRequirements`; inspect exact PDF pages independently and confirm only corroborated lines are promoted, with ambiguous/scan cases held for review.
3. Confirm the existing Flutter readiness card hides low-confidence scores and never blocks Apply Through PESO.
4. If future reviewed examples demonstrate systematic errors, only then run the frozen-heldout candidate comparison and require a manual promotion decision.
