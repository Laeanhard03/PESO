# PESO React NSRP and Resume Responsive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the React NSRP and resume-builder experiences usable at phone, tablet, laptop, and desktop sizes without changing their Flutter integration or degrading resume PDF/export geometry.

**Architecture:** Reuse the existing React 19/Vite/Tailwind stack and responsive utility classes. Separate the fixed-size resume document canvas used for rendering/export from the scaled visual preview container, and adapt the surrounding toolbar/editor layout with CSS and utility classes.

**Tech Stack:** React 19, Vite 8, Tailwind CSS 4, existing `html-to-image`/jsPDF export code, ESLint and Vite production build.

**Spec:** `docs/superpowers/specs/2026-10-16-peso-responsive-ui-desktop-launcher-design.md`

## Global Constraints
- Compact width is below 600 logical/CSS pixels, medium is 600–1023, and expanded is 1024 and above.
- Preserve React-to-Flutter bridge payload shape, sender/source checks, NSRP/resume callback behavior, and the existing Firebase/backend integration.
- Keep the resume document canvas at 794×1123 CSS pixels for print/PDF rendering; only the viewport preview may be scaled.
- Do not add dependencies, change user data flows, deploy services, edit credentials, commit, or push unless separately approved.
- The React workspace is hosted at `http://localhost:5173` inside Flutter; preserve its existing paths and origin assumptions.

## Review Focus
- Narrow viewport around 320–390 px, including long toolbar labels: Task 1 must verify no page-level horizontal overflow.
- Medium tablet split editor/preview layout: Task 1 verifies controls remain reachable.
- Resume canvas scaling versus export dimensions: Task 2 tests preview bounds and unchanged 794×1123 node dimensions before/after export.
- Long names and optional profile sections: Task 2 verifies no clipped text/overlap in the preview.
- Browser reload/deep-link to `/resume`: Task 3 verifies both the root form and resume route still load.

---

### Task 1: Responsive NSRP form and shared editor chrome

**Files:**
- Modify: `react_workspace/src/App.jsx`
- Modify only if needed: `react_workspace/src/App.css` and/or `react_workspace/src/index.css`

**Interfaces:** Preserve current exported/component behavior and `sendToFlutter(payload)` contract from `src/flutterBridge.js`.

- [ ] **Step 1: Capture baseline behavior.** Use the current Vite run/preview only if already available; otherwise use a temporary local server only after implementation is authorized. Record the NSRP form at 390×844, 768×1024, and 1440×900, noting page scroll width and primary action reachability.
- [ ] **Step 2: Define measurable failures.** At each viewport verify `document.documentElement.scrollWidth <= window.innerWidth` except for intentionally scoped inner scroll areas; record any existing overflow/clipped fields before changes.
- [ ] **Step 3: Make the form adaptive.** Replace fixed-width outer wrappers and non-wrapping toolbars with responsive width/max-width, flex wrapping, and compact stacking; ensure form content remains scrollable and controls do not become unreachable at 320–390 px.
- [ ] **Step 4: Run lint and production build.** Run `npm run lint` and `npm run build` from `react_workspace`. Expected: both pass.
- [ ] **Step 5: Verify at all three viewport widths.** Reopen/reload the root form and exercise form completion; expected: no page-level horizontal overflow, clear action access, and unchanged bridge payload keys/source.

### Task 2: Resume editor responsive preview without export drift

**Files:**
- Modify: `react_workspace/src/ResumeApp.jsx`
- Modify if needed: `react_workspace/src/App.css` or `index.css` (coordinate shared CSS edits with Task 1 before applying).

**Interfaces:** Preserve current resume state, export controls, element ID `resume-node`, html-to-image/jsPDF pipeline, and bridge message contract.

- [ ] **Step 1: Add/check dimension assertions around the export boundary.** Identify where the current code queries `#resume-node` and passes dimensions to html-to-image/jsPDF. Pin the invariant that the document node remains 794×1123 CSS pixels before and after visual preview resizing/export.
- [ ] **Step 2: Implement preview scaling outside the document node.** Add a viewport-aware wrapper that scales the visible A4 canvas to fit available width. Maintain a measured placeholder height so the next toolbar/editor section does not overlap the transformed preview. Do not set the export node width to `100%` or shrink the underlying PDF canvas.
- [ ] **Step 3: Adapt the editor/control panel.** At compact widths stack or collapse editing controls above/below the preview; at medium widths use two columns only when both meet their minimum widths; at expanded widths keep the editing area and preview side by side. Make header actions wrap rather than exceed the viewport.
- [ ] **Step 4: Verify the regression.** With long sample name, optional sections, and a portrait, check canvas dimensions remain 794×1123, the preview fits 390×844 and 768×1024, and PDF/image export still reports the original page aspect/dimensions without cropping.
- [ ] **Step 5: Run `npm run lint` and `npm run build`.** Expected: zero lint errors/build failures; preserve the existing non-blocking bundle-size advisory if it remains.

### Task 3: Integration and acceptance

**Files:** Any responsive CSS from Tasks 1–2; no bridge protocol changes.

- [ ] **Step 1: Exercise direct Vite routes.** Confirm `/` and `/resume` reload directly when served by Vite; both should return the intended React experience rather than a missing page.
- [ ] **Step 2: Exercise the Flutter host path.** With the Flutter web host and Vite available, open the NSRP and resume screens through Flutter; verify iframe/WebView dimensions respond on compact and wide widths.
- [ ] **Step 3: Verify bridge completion.** Use a non-sensitive test fixture to complete each flow; check the Flutter side receives the same `source`, `kind`, and data fields as before.
- [ ] **Step 4: Run final `npm run lint` and `npm run build`.** Expected: both pass after all shared CSS edits.
- [ ] **Step 5: Check Git scope.** Run `git diff --check` and inspect `git status`; report exact changes and avoid commit/push.

## Completion Gate
Both React experiences must render cleanly at 390×844, 768×1024, and 1440×900; the resume preview must fit the viewport while the export node stays 794×1123 CSS pixels; Vite/lint/build and the existing Flutter bridge completion flow must pass. The Windows launcher lifecycle is validated in the companion plan.
