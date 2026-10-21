# PESO Flutter Responsive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all 17 existing Flutter UI surfaces responsive at phone, tablet, laptop, and desktop widths while preserving routes, data flows, Firebase authorization, and visual identity.

**Architecture:** Add one shared width classifier/content constraint helper, then adapt existing UI files locally using available `LayoutBuilder` constraints. Add new responsive widget tests instead of overwriting the user's already-modified `test/widget_test.dart`.

**Tech Stack:** Flutter 3.47.1; Dart 3.13.1; Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-10-16-peso-responsive-ui-desktop-launcher-design.md`

## Global Constraints
- Compact is below 600 logical pixels; medium is 600–1023; expanded is 1024 and above.
- Determine layout from the available `LayoutBuilder` width.
- Preserve Firebase initialization/authentication, the Admin verified custom-claim gate, Firestore/Storage flows, React bridge contract, image caching, and existing routes.
- Preserve current user changes and inspect dirty diffs before modifying shared files.
- Do not install dependencies, deploy backend services, alter credentials/configuration, or commit/push.

## Review Focus
- Breakpoints at 599/600 and 1023/1024: Task 1 tests exact boundaries.
- Long text and action labels: Tasks 2 and 4 test no layout exception.
- Keyboard and compact form reachability: Task 2 tests at 360×800.
- Long job cards/tables: Task 3 tests nested scroll and page overflow.
- Admin still blocked without Firebase verification: Task 4 runs the existing security-gate test.

---

### Task 1: Shared responsive primitives

**Files:** Create `lib/peso_ui/Reusable_Designs/responsive_layout.dart`; create `test/responsive_layout_test.dart`.

**Interfaces:** `enum PesoLayoutClass { compact, medium, expanded }`; `PesoLayoutClass classifyPesoWidth(double width)`; and `ResponsiveContent({Key? key, required Widget child, double maxWidth = 1200, EdgeInsetsGeometry padding = const EdgeInsets.all(16)})`, which centers/constrains content without imposing height.

- [ ] **Step 1: Add failing tests** for widths 359, 599, 600, 768, 1023, 1024, and 1440, plus content max-width/padding.
- [ ] **Step 2: Confirm RED** with `flutter test test/responsive_layout_test.dart`; expect missing classifier/widget compile errors.
- [ ] **Step 3: Implement** the named breakpoints, classifier, and content wrapper.
- [ ] **Step 4: Confirm GREEN** with the same focused test; expect every boundary assertion passes.

### Task 2: Landing, authentication, and shared navigation

**Files:** Modify `lib/peso_ui/Landingpage/landingpage_ui.dart`, `lib/peso_ui/Login_register_pages/auth_ui.dart`, `login_ui.dart`, `register_ui.dart`, and `lib/peso_ui/Reusable_Designs/reusable_ui.dart`. Create/extend `test/responsive_ui_test.dart`.

- [ ] **Step 1: Add failing viewport tests** for `LandingPage` at 360×800, 768×1024, 1366×900 and existing auth entry screens at compact/wide sizes. Use devicePixelRatio=1, settle frames, assert primary actions are findable and `tester.takeException()` is null.
- [ ] **Step 2: Run RED** using `flutter test test/responsive_ui_test.dart --plain-name "landing and authentication respond to viewport width"`; capture actual baseline failures.
- [ ] **Step 3: Adapt layouts** to wrap hero/actions, constrain content to available width, and keep sign-in/register forms scrollable with keyboard insets. Change navigation presentation without changing routes/callbacks.
- [ ] **Step 4: Run focused tests and analyze** the five files; expect no overflow or missing primary actions.

### Task 3: User dashboard and tabs

**Files:** Modify `lib/peso_ui/User/user_ui.dart`, `user_account_tab.dart`, `user_ai_profile_tab.dart`, `user_job_feed_tab.dart`, `user_outcomes_tab.dart`, `user_settings_tab.dart`; extend `test/responsive_ui_test.dart`.

- [ ] **Step 1: Add failing tests** for the user shell and individually instantiable tabs at 360×800, 768×1024, 1366×900; assert tabs/actions remain findable and no layout exceptions appear.
- [ ] **Step 2: Run RED** with `flutter test test/responsive_ui_test.dart --plain-name "user screens respond to viewport width"`.
- [ ] **Step 3: Adapt navigation and content** to available width; stack profile/outcome columns when needed, wrap settings/actions, constrain cards, and keep deliberate job-card horizontal scrolling separate from the page scroll.
- [ ] **Step 4: Rerun user tests and analyze all six files**; expect no RenderFlex overflow and stable tab-selection behavior.

### Task 4: Admin and user management

**Files:** Modify `lib/peso_ui/Admin/admin_ui.dart` and `admin_user_management_section.dart`; extend `test/responsive_ui_test.dart` without overwriting existing changes in `test/widget_test.dart`.

- [ ] **Step 1: Add failing tests** for gate controls at 360×800, 768×1024, 1366×900, plus user-management layout at compact and wide widths.
- [ ] **Step 2: Run focused admin tests** and record layout/reachability failures.
- [ ] **Step 3: Adapt dashboard navigation, content/dialog widths, action wrapping, and the table scroll viewport.** Do not change auth claims, privileged calls, role checks, or confirmation behavior.
- [ ] **Step 4: Rerun `flutter test test/responsive_ui_test.dart` and `flutter test test/widget_test.dart --plain-name "Admin dashboard is blocked until Firebase admin verification"`.** Expect responsive tests pass and the gate still blocks unauthorized access.
- [ ] **Step 5: Compare diffs** and preserve pre-existing admin edits.

### Task 5: Reusable AI/forms and example view

**Files:** Modify `lib/peso_ui/Reusable_Designs/ai_processing_ui.dart`, `pesoform_ui.dart`, `resumebuilder_ui.dart`, and `lib/peso_ui/exampage_ui.dart`; extend `test/responsive_ui_test.dart`.

- [ ] **Step 1: Add failing compact/wide tests** for the AI dialog/card and NSRP/resume host scaffold; assert app-bar actions wrap and the embedded view has a nonzero available area.
- [ ] **Step 2: Run focused tests** and record current failures.
- [ ] **Step 3: Adapt forms, dialogs, toolbars, and host widths** while preserving constructor/callback signatures, loading states, URLs, and React bridge payload validation.
- [ ] **Step 4: Rerun tests and analyze the touched widgets**; expect no layout exceptions and no changed callback shape.

### Task 6: Full Flutter acceptance

- [ ] **Step 1: Run** `flutter test`. Expected: all tests pass, including the existing Admin security gate.
- [ ] **Step 2: Run** `flutter analyze --no-fatal-infos`. Expected: zero errors/warnings; report remaining infos.
- [ ] **Step 3: Run** `flutter build web --release --no-wasm-dry-run`; verify expected assets and no bundled local secret material.
- [ ] **Step 4: Run** `git diff --check` and `git status --short --branch`; compare hashes/diffs of pre-existing dirty files. Do not commit or push.
- [ ] **Step 5: Record** actual paths, commands/results, warnings, and blocked cases in a task checkpoint.

## Completion Gate
All 17 Dart UI files must be inspected and adapted or explicitly verified responsive. The entire Flutter test suite and analysis must be recorded, and the Admin security gate must remain intact. React and launcher acceptance are covered by their companion plans.
