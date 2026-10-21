# PESO Mini-AI — Controlled retraining and evidence review gates (2026-10-20)

## Decision for this iteration: RETAIN the existing trained model

The live, read-only job audit found 81 parent notices and 244 provenance-linked role cards (including 16 individual JCRCC positions). Each of the 81 notices has at least one exact source-linked role. However, 55 roles carry nonempty unattributed qualification lists, and additional roles can have `unattributed_notice` scope even when the raw list is empty. **Neither condition establishes a verified role-specific mandatory requirement.** Do not manufacture labels from these fields.

Production model `mini_ai/data/model_v1.json` remains unchanged. A baseline copy is stored in `mini_ai/data/experiments_20261020/model_v1_baseline.json`. Confirm both SHA-256 hashes match before comparison or rollback. No newly trained model was promoted or configured.

## What the existing diagnostic actually measures

Run from `mini_ai`:

```powershell
go run ./tools/offlineeval -baseline data/experiments_20261020/model_v1_baseline.json -data data/v1/synthetic_pairs_v1.jsonl -report ../docs/MINI_AI_HELDOUT_DIAGNOSTIC_2026-10-20.json
```

This is an explicitly **synthetic rubric** diagnostic. It refuses non-synthetic examples and cross-split applicant/source-family leakage. It checks F1, precision, recall, false positives, false negatives, Brier, 10-bin expected calibration error, NDCG@5 and top-1 ranking by held-out fictional applicant ID. The numeric calibration figures are relative to generated rubric targets, not actual hiring-probability reliability or the UI's low/medium confidence categories. Source-specific mandatory-gap correctness cannot be measured from this pair dataset.

Use `-candidate path/to/isolated_model.json` to compare a candidate *on the exact same frozen held-out rows*. That option does not certify the candidate's training provenance and **never changes the runtime model**. Any comparison is ineligible for promotion unless the candidate's training families and applicant identities are proven disjoint from the held-out set and the labels have been independently reviewed.

## Data-review protocol required before any meaningful retrain

1. **Review real source notices first.** Have PESO/employer subject matter reviewers inspect official PDF pages and confirm that each role is present and currently open. Record the exact source document, page, role fingerprint, role title, and evidence excerpts in a private restricted audit system.
2. **For each named role**, classify each requirement as `mandatory`, `preferred`, `shared_explicitly_across_roles`, `unattributed`, `excluded_protected`, or `unknown`. Do not copy an unprefixed employer requirement to every position. Distinguish licensing/training from generic skill text.
3. **Review applicant qualifications independently**, on an explicitly consented, de-identified sample. Annotate `supported`, `missing`, or `not_assessable` for each role requirement, including evidence of absence versus missing documentation. Do not invent a negative label when information is simply absent.
4. **Two independent reviewers** should evaluate ambiguous labels with adjudication. Avoid using a previous AI score as an annotation suggestion; this would make an evaluation circular.
5. Keep **source notice families, mirror PDFs, employers where relevant, and applicant identities separate across train, validation, and test**, with a strictly frozen evaluation corpus. Historical expired roles cannot be treated as live availability.
6. **Keep protected characteristics out of all features, mandatory-gap labels, rankings and score attribution.** Continue metamorphic protected-criteria invariance tests; document exclusions for human review.
7. Record reviewed ranking groups (one applicant and multiple eligible positions) and independently assessed relative relevance. Actual application or hiring decisions should not be assumed to be unbiased ground truth because outcomes are selectively observed.

## Candidate experiment and release gates

- First identify a documented baseline error class (e.g. false missing NC II on a verified role, failure to recognize a substantiated skill, incorrectly high confidence with absent role requirements, source-family alias leakage).
- Change only the code or training examples responsible for that failure; never replace confirmed source-review gaps with synthetic qualifications.
- Use the **identical frozen held-out annotations** for baseline and challenger and report paired F1/precision/recall, per-requirement mandatory-gap false-positive and false-negative rates, confidence risk-coverage and calibration, and ranking NDCG@3/5 with group-level confidence intervals. Include `not_assessable` abstention rate rather than silently omitting it.
- Reject the candidate if it increases unsupported mandatory gaps, degrades calibration or ranking, introduces protected-attribute effects, breaks provenance linkage, or has unresolved leakage. Favor model retention when improvements are small or based solely on synthetic labels.
- Do not automatically deploy. Require signed PESO source review, reproducible model/data checksums, QA sign-off, an authenticated end-to-end user journey, version-pinned rollout and a rollback plan.

## Research framing

Relevant methods informed, but do not replace, this project's evaluation design:

- Guo et al. (ICML 2017), *On Calibration of Modern Neural Networks*: calibration requires independent labels; https://proceedings.mlr.press/v70/guo17a.html
- Cañamares, Castells & Moffat (2020), *Offline evaluation options for recommender systems*: ranking results depend strongly on split, score handling, and evaluation protocol; https://doi.org/10.1007/s10791-020-09371-3
- *The Selective Labels Problem*: observed decisions need not provide unbiased outcome truth; https://pmc.ncbi.nlm.nih.gov/articles/PMC5958915/

**Disposition:** Improve role-source evidence first, obtain human-reviewed applicant-role labels, then run a controlled challenger experiment. Current training set cannot establish hiring accuracy, missing mandatory accuracy or trustworthy real-world score calibration.
