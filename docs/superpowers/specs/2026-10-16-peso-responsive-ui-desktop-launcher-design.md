# PESO JobKonek Responsive UI and Desktop Launcher — Design

**Date:** 2026-10-16  
**Workspace:** `C:\Users\Admin\Desktop\Prototype`  
**Status:** Design approved on the live board (user message #6607: “approved b”); this document is awaiting separate user review.  
**Implementation status:** Not started. This document is not permission to edit product code, install dependencies, build or start services, or modify project configuration.

## 1. Goal and acceptance intent

Modernize the existing Flutter + React PESO JobKonek application so its screens can adapt across phone, tablet, laptop, and wide desktop windows without horizontal overflow or unusably dense controls. Provide a predictable Windows desktop entry point that opens the application in an app-style browser window while the machine lacks the Visual Studio C++ workload required for Flutter's native Windows build.

Preserve the existing features and security rules. This effort is UI/layout and local launch experience work, not a backend migration or deployment.

## 2. Verified baseline and constraints

- The active VS Code project is `C:\Users\Admin\Desktop\Prototype`.
- The Flutter project has 17 Dart UI files spread among the landing page, login/registration, user pages, administrator pages, reusable form/resume/AI views, and an example page.
- The current app embeds the React NSRP and resume builder from `http://localhost:5173`; a launcher that only starts Flutter would leave those flows unavailable.
- Existing Windows runner scaffolding is present. Flutter 3.47.1 and Edge/Chrome are installed. `flutter doctor -v` reports that Visual Studio and its “Desktop development with C++” workload are missing. A native Windows executable is therefore not currently buildable in this environment.
- `dev.bat` has unrelated setup side effects: creating local placeholder files, setting global Git `safe.directory` to a wildcard, installing/syncing dependencies, and starting Vite and a watcher. It must not be used as the default user-facing launch command.
- The existing working tree contains user changes. Current observed changes include edits to `lib/peso_ui/Admin/admin_ui.dart`, `lib/peso_ui/Admin/admin_user_management_section.dart`, `test/widget_test.dart`, `watcher.ps1`, and untracked `capstonedocumentation.md`. Preserve them; inspect the latest diff and hashes before any shared-file edit.

## 3. Responsive layout system

Introduce a small shared responsive-layout utility for consistent breakpoints and reusable constrained content. Decisions must use the available logical width from `LayoutBuilder` (or the nearest available constraints), not a global screen-size guess, so dialogs, side panels, and resized desktop windows adapt correctly.

Initial breakpoints:
- **Compact:** below 600 logical pixels.
- **Medium:** 600–1023 logical pixels.
- **Expanded:** 1024 logical pixels and above.

These are starting points; validate against actual widget behavior and tune only with evidence.

Shared rules:
- Keep reading/form content comfortably constrained on large windows rather than stretching paragraphs and input fields across the full desktop.
- On compact widths, use a single-column layout, safe-area-aware insets, wrap/stack action rows, and maintain scroll access to every control. Avoid fixed horizontal widths that exceed constraints.
- Respect keyboard insets and avoid obscuring text fields, submit actions, or focused errors when the on-screen keyboard appears.
- On medium and expanded widths, use two-column layouts only when each child has adequate minimum width. Collapse to a single column before overflow.
- Make dialogs and bottom sheets width-aware and scrollable on small devices; apply an explicit max width on desktop.
- Use flexible text, sensible line heights, tappable controls, and accessible labels; do not rely on horizontal clipping as a responsive strategy.
- Preserve deliberate horizontal carousels/tables only where they serve a clear purpose; bound and label their scroll behavior.
- Preserve existing colors/branding, loading/error states, animations, data contracts, routes, and actions unless a layout change requires a local adaptation.

### Flutter UI surfaces in scope

All 17 existing UI files are in the design scope; do not assume shared layout fixes alone prove each screen works:

1. `lib/peso_ui/Landingpage/landingpage_ui.dart`
2. `lib/peso_ui/Login_register_pages/auth_ui.dart`
3. `lib/peso_ui/Login_register_pages/login_ui.dart`
4. `lib/peso_ui/Login_register_pages/register_ui.dart`
5. `lib/peso_ui/User/user_ui.dart`
6. `lib/peso_ui/User/user_account_tab.dart`
7. `lib/peso_ui/User/user_ai_profile_tab.dart`
8. `lib/peso_ui/User/user_job_feed_tab.dart`
9. `lib/peso_ui/User/user_outcomes_tab.dart`
10. `lib/peso_ui/User/user_settings_tab.dart`
11. `lib/peso_ui/Admin/admin_ui.dart`
12. `lib/peso_ui/Admin/admin_user_management_section.dart`
13. `lib/peso_ui/Reusable_Designs/reusable_ui.dart`
14. `lib/peso_ui/Reusable_Designs/ai_processing_ui.dart`
15. `lib/peso_ui/Reusable_Designs/pesoform_ui.dart`
16. `lib/peso_ui/Reusable_Designs/resumebuilder_ui.dart`
17. `lib/peso_ui/exampage_ui.dart`

Navigation should adapt to available width: a compact/drawer or bottom-navigation pattern where the existing navigation supports it, and a rail or persistent navigation panel on sufficiently wide layouts. Avoid rewriting the application's route and authentication structure merely to change navigation presentation.

## 4. React resume and NSRP layout

The React workspace is embedded by Flutter and also supports standalone Vite development. Apply responsive layout rules to both user-facing experiences in `react_workspace/src/App.jsx`, `ResumeApp.jsx`, and the relevant CSS.

- Make toolbars/actions wrap or stack at compact widths; use concise overflow-safe labels and sufficiently large tap targets.
- The resume-editor preview has a fixed A4-style canvas (observed as 794 by 1123 CSS pixels). Keep that document/canvas size for print/PDF capture and exported output. Scale the visible preview to fit the viewport instead of shrinking the underlying export canvas and degrading export geometry.
- Keep the editor usable on narrow screens: separate or collapse editor controls and preview as appropriate, and prevent the main page from gaining accidental horizontal overflow.
- Preserve existing React-to-Flutter bridge payload formats and source validation. Do not weaken message-origin checks or change data synchronization semantics for responsive reasons.
- Verify both the Flutter-hosted embedding and standalone React build/render path.

## 5. Windows desktop launch experience — recommended Option B

Because the native C++ toolchain is missing, implement a local Windows launcher that opens the web experience in Edge app mode. Treat this as an interim desktop entry point, not a native executable and not a production deployment.

The launcher should start or reuse only the exact project-owned web processes it needs:
- Flutter's web-server target for the Flutter shell, at an explicitly configured loopback port.
- The React/Vite workspace at `localhost:5173`, required by the embedded NSRP and resume forms.
- Microsoft Edge in app mode pointing to the local Flutter URL.

Exact port choices and host mode should be finalized after checking the current React bridge/origin-validation code and a clean local smoke run. Do not expose development servers to the LAN: bind to loopback unless there is an independently approved reason to do otherwise.

Launcher safety and reliability requirements:
- Resolve the project root from the launch script location instead of assuming the current shell directory.
- Check the chosen ports before startup. Reuse a process only after verifying that its executable/command line maps to this exact project root and expected script/port.
- If a port is occupied by an unknown process, fail with a useful explanation rather than killing or adopting it.
- Avoid opening duplicate Vite, Flutter, or Edge windows on repeated launches. Track only child processes launched by this launcher; never terminate processes by broad name.
- Start dependencies in order, wait for local readiness with bounded timeouts, then open Edge app mode. Show useful error diagnostics if Flutter, Node/npm, built React dependencies, or Edge are unavailable.
- Do not generate, read, log, or change secrets, `.env`, credential files, Firebase configuration, Git global settings, tunnel settings, watchdogs, MCP servers, or unrelated services.
- Do not run package installation, mutate dependencies, deploy backend services, or silently invoke the existing side-effecting `dev.bat`.
- Keep a separate explicit development-stack workflow only if needed. The user-facing launcher must not trigger global setup changes.
- Document the distinction between app-mode web launch and a true Windows EXE. A native packaging follow-up requires the Visual Studio C++ workload and a tested Windows-compatible strategy for embedded React forms; it is out of scope for this first launch path.

## 6. Data, auth, and non-goals

Must preserve:
- Firebase initialization behavior and sign-in/sign-up flows.
- The Admin Firebase verification and custom-claim gate; no layout or debug shortcut may unlock the Admin dashboard.
- Existing Firestore/Storage profile and artifact actions, their validation, and their per-user security assumptions.
- React message bridge schemas, resume/NSRP submission flows, image caching, and backend request semantics.
- Existing user changes and untracked documentation in the current Git worktree.

Explicitly out of scope:
- Firebase/Google Cloud deployments, Admin custom-claim changes, real account edits/deletes, or live data migrations.
- API key/credential rotation or other secret changes.
- MCP, tunnel, watchdog, collaboration board, or agent-control changes.
- Installing Visual Studio, Android Studio, or new global tools; building a native EXE before the required toolchain and bridge compatibility are available.
- Replacing the UI framework, rewriting the app architecture, or replacing real backend flows with mocks.

## 7. Validation and completion criteria

Before implementation is called complete:
1. Add/adjust widget tests to exercise representative routes at 360×800, 768×1024, and 1366×900 logical pixels where meaningful.
2. Assert key controls remain visible/reachable and test for layout exceptions/RenderFlex overflow after settling frames. Keep the Admin security-gate test intact and passing.
3. Run `flutter analyze --no-fatal-infos` and `flutter test`; report remaining info-level lints separately.
4. Run `flutter build web --release --no-wasm-dry-run` and verify its output without including local secret material.
5. Run React lint and production build; verify NSRP and resume routes/toolbar/preview behavior at compact and wide widths.
6. Run PowerShell parser validation and launcher-specific smoke checks: repeated launch, process reuse, unknown-port conflict, startup timeout, Edge opening, and safe failure without cleanup of unowned processes.
7. Validate the integrated launch path that the local Flutter page loads and both React form routes are available at the expected URL.
8. Re-check `git status`, `git diff --check`, and hashes of pre-existing dirty files. Explain exact files changed; preserve unrelated diffs. Do not commit/push unless separately authorized.
9. Mark native Windows EXE build as blocked until Visual Studio/C++ tools are installed; do not represent Edge app mode as a native executable.
10. Keep online Firebase, Storage, Functions/Gemini, and real identity/backend verification separate from local UI success.

## 8. Risks and mitigations

- **Embedded React availability:** If Vite is not started or its port is wrong, NSRP/resume forms fail. The launcher must gate Edge startup on both services being ready.
- **Unsafe port reuse:** Another app may occupy a selected port. Verify process identity and fail closed on unknown owners.
- **Responsive changes causing form regressions:** Make layout changes in focused units and add viewport tests before broad edits.
- **Canvas export drift:** Keep the resume document's export dimensions invariant; scale only the on-screen preview.
- **User changes overwritten:** Inspect and preserve existing dirty diffs before modifying affected files; use short write windows and re-read the board before writes.
- **Native build expectations:** Be clear that the interim launcher is Edge app mode; native EXE remains a separate, toolchain-dependent step.

## 9. Spec self-review

- **Scope completeness:** Covers all 17 identified Flutter UI files, the embedded React resume/NSRP experiences, the Windows app-mode launch path, validation, and exclusions.
- **Consistency:** Responsive behavior uses available-width constraints; native packaging is explicitly deferred because the required Visual Studio C++ workload is missing.
- **Security boundary:** Retains Firebase/Admin gates and backend contracts; launch logic avoids secrets and unrelated services, verifies process identity, and fails closed on unknown ports.
- **Testability:** Defines Flutter viewport sizes, layout overflow checks, React build/render checks, and launcher lifecycle cases.
- **Placeholders:** No unresolved TODO/TBD placeholders remain in the design.
- **Approval boundary:** User approval of Option B authorized writing this spec only. Implementation planning and all product-code changes require the user to review and approve this written spec first.
