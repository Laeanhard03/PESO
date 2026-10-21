# PESO Windows App-Mode Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe double-click Windows entry point that opens PESO JobKonek in an Edge app-mode window and manages only the exact local Flutter Web + Vite processes required for its embedded React forms.

**Architecture:** Keep orchestration separate from reusable process/port validation. The launcher starts/reuses Flutter Web on loopback port 5237 and React/Vite on loopback port 5173, waits for both to answer, then opens Edge with `--app=http://127.0.0.1:5237`. Save safe launch metadata under the current user's LocalAppData so subsequent runs can verify prior child identities. Fail closed on unknown port owners; never broadly kill processes.

**Tech Stack:** PowerShell 5.1+ (Windows), Flutter 3.47.1, Node/npm and existing Vite scripts, Microsoft Edge app mode; no new packages.

**Spec:** `docs/superpowers/specs/2026-10-16-peso-responsive-ui-desktop-launcher-design.md`

## Global Constraints
- Only loopback services are allowed by default; chosen ports are Flutter 5237 and Vite 5173 with strict-port behavior.
- Reuse a process only after its exact project root, command line/process ancestry, service role, and port have been verified.
- If a chosen port belongs to an unknown process, report it and stop without killing or adopting it.
- Never read/write/log secrets, `.env`, credential files, Firebase configuration, global Git settings, MCP/tunnel/watchdog state, or unrelated processes.
- Do not invoke the existing `dev.bat`; it has unrelated global/config/service side effects.
- Do not install dependencies, deploy services, commit, or push.
- This is an Edge app-mode web wrapper, not a native Windows executable. The current environment lacks the Visual Studio Desktop development with C++ workload.

## Review Focus
- Port 5173/5237 occupied by an unrelated process: Task 1 must fail closed and preserve it.
- Stale PID / PID reuse from old launcher state: Task 1 must reject mismatched command lines and ancestry.
- Flutter or Vite startup timeout: Task 2 must not open Edge until both services are ready and must report the correct failure.
- Repeated launch: Task 2 must reuse verified services and avoid duplicate app windows.
- Edge unavailable or closed after launch: Task 2 must report a meaningful error and preserve service ownership state without terminating unknown browser processes.

---

### Task 1: Process/port ownership core and no-side-effect tests

**Files:**
- Create: `scripts/peso_desktop_launcher_core.psm1`
- Create: `scripts/tests/peso_desktop_launcher_tests.ps1`

**Interfaces:**
- Export `Test-PesoCommandLineIdentity([string]$CommandLine, [string]$ProjectRoot, [ValidateSet('flutter','vite','edge')][string]$Service, [int]$Port)` returning a boolean.
- Export `Test-PesoEndpoint([string]$Uri, [int]$TimeoutSeconds = 2)` returning a boolean without following untrusted redirects.
- Export `Get-PesoListenerOwner([int]$Port)` returning listener PID and process metadata (or null when no listener exists).
- Export `Test-PesoRecordedProcess([int]$ProcessId, [string]$ProjectRoot, [string]$Service, [int]$Port, [string]$StatePath)` verifying both current command-line/ancestor identity and saved launch metadata, never trusting PID alone.

- [ ] **Step 1: Write self-contained failing tests** for matching Flutter/Vite/Edge command lines, foreign project roots, wrong ports, reused/stale PIDs, missing listeners, and unknown-listener rejection. Do not require Pester or install any dependency; use PowerShell assertions in the test script.
- [ ] **Step 2: Run the test script** with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/peso_desktop_launcher_tests.ps1`. Expected initially: assertions fail because the exported functions do not exist.
- [ ] **Step 3: Implement the pure identity/endpoint/owner helpers** in the module. Keep port-owner lookup read-only; it must never terminate a process.
- [ ] **Step 4: Rerun the test script.** Expected: all pure identity and fail-closed assertions pass; no app service or browser is started during this suite.

### Task 2: Desktop launcher and owned child runners

**Files:**
- Create: `launch_peso_desktop.bat`
- Create: `scripts/launch_peso_desktop.ps1`
- Create: `scripts/run_peso_desktop_service.ps1`
- Modify only if needed: project README section documenting the app-mode command (coordinate with other doc edits first).

**Interfaces:** `launch_peso_desktop.bat` resolves its own directory and invokes `scripts/launch_peso_desktop.ps1`; the orchestrator calls the core functions from Task 1. The child runner accepts only `-Service vite` or `-Service flutter` and derives all working directories from the project root.

- [ ] **Step 1: Add launch validation tests** for missing Flutter/npm/Edge executables and unavailable project directories; each case should return a clear error before spawning processes.
- [ ] **Step 2: Implement bounded preflight.** Resolve project root from the script location, verify `react_workspace\node_modules\.bin\vite.cmd` exists without running `npm install`, locate Flutter/npm/Edge, choose ports 5237/5173, read safe launcher metadata, and inspect both ports.
- [ ] **Step 3: Implement exact service launch/reuse.** Start the child runner hidden for Flutter Web at `127.0.0.1:5237` and Vite at `127.0.0.1:5173` using `--strictPort`. Reuse only verified project-owned instances. Store only project root, service kind, PID, port, and start time in a LocalAppData JSON state file; never persist environment variables or secrets.
- [ ] **Step 4: Implement bounded readiness waits.** Poll each expected localhost URL with a fixed deadline. If a listener belongs to an unknown owner or readiness times out, stop launching further UI steps and print the exact host/port and recovery guidance. Do not terminate broad process-name matches; any cleanup may target only a just-created child whose command line and parent still match this launcher.
- [ ] **Step 5: Open Edge app mode once ready.** Use the verified Edge executable and `--app=http://127.0.0.1:5237`; reuse an existing matching app-mode process only when its current identity is verified. Never select or close a normal user browser window by title alone.
- [ ] **Step 6: Run launcher unit/self-tests** and static PowerShell parser validation. Expected: no syntax errors; test suite covers foreign ports, timeouts, and missing executables.
- [ ] **Step 7: Run one controlled integration smoke test** after explicit execution approval: cold start, wait for both ready URLs, open the app window, run the launcher again and confirm no duplicate owned servers/app window, then verify an unknown test port is reported without killing the listener.
- [ ] **Step 8: Verify embedded routes** from the launched application: open the NSRP form and resume route, confirm the Flutter root and Vite route load, and confirm all listeners remain loopback-only.

### Task 3: Documentation and final lifecycle acceptance

**Files:** `launch_peso_desktop.bat`, `scripts/launch_peso_desktop.ps1`, `scripts/run_peso_desktop_service.ps1`, `scripts/peso_desktop_launcher_core.psm1`, tests, and the minimal README section if changed.

- [ ] **Step 1: Document the launch command**, expected ports, prerequisites, how to interpret a port-conflict error, and the fact that Edge app mode is not a native EXE.
- [ ] **Step 2: Validate repeated launch** with existing verified services and verify the same child PIDs remain in use.
- [ ] **Step 3: Validate unowned process preservation** by placing a harmless test listener on a test port; expected: explicit conflict result and the test listener remains alive.
- [ ] **Step 4: Validate readiness timeout** using a controlled test fixture; expected: no Edge app window is opened before both services are ready.
- [ ] **Step 5: Run final PowerShell parser checks and self-tests** and review `git diff --check`.
- [ ] **Step 6: Review status and pre-existing worktree diffs** including `watcher.ps1`; do not alter its current user edits, do not call `dev.bat`, and do not commit/push.

## Completion Gate
The app-mode window opens only after Flutter Web and Vite have each been confirmed on their expected loopback ports; repeated calls do not create duplicate owned services; unknown process listeners are never killed or adopted; the NSRP/resume routes work; and all launcher self-tests and parser checks pass. A native EXE remains blocked until the C++ toolchain and a compatible native embedded-React strategy are available.
