# Conductor — Project Plan

> **Conductor** is a native macOS SwiftUI app that orchestrates your Claude Code sessions: find what's running, decide what's safe to close, recover anything in two clicks.

This document is the **plan of record**. Every chunk has a sprint contract — concrete, testable acceptance criteria written *before* code lands. The evaluator grades each chunk against its contract; that determines merge.

> Read [CLAUDE.md](CLAUDE.md) for *why* and [AGENTS.md](AGENTS.md) for *what*. Read [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md) before authoring a chunk; [docs/EVALUATOR.md](docs/EVALUATOR.md) before evaluating one.

---

## Goal

You run 40+ Claude Code sessions across ~10 repos at any given time. Three concrete pains:

1. **Find** — locating the session you want among 40 tabs.
2. **Decide** — knowing which sessions are safe to close.
3. **Recover** — closing without losing context, with a frictionless way back.

Success criteria: closing 10 sessions in 30 seconds and resuming any one of them in 2 clicks. Once recovery is trivial, "close" stops being a one-way door.

---

## What's known (from the discovery spike)

- Each session is a JSONL at `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl`.
- Live sessions hold a lock file `<uuid>.lock` containing `{pid, sessionId, startedAt, cwd}` — the **pid↔session linchpin**.
- The encoded cwd is reversible.
- `claude --resume <uuid>` from the right cwd resumes any session — works across reboots.
- Terminal.app exposes windows/tabs via AppleScript; we can map `pid → tty → terminal tab`.
- A global `SessionStart` hook can broadcast new-session events (Phase 5).

### Two newly-clarified surfaces (require Phase 0 reverse-engineering)

- **`/rename <name>`** — Claude Code's slash command sets a session-native name. We want to **read** this name everywhere and **set** it programmatically. Where it persists is what Phase 0 has to find.
- **`/rc` / `/remote-control`** — Claude Code's slash command that enables phone-based steering. Per-session boolean. We want to **read** which sessions have it enabled and, if storage allows, **toggle** it.

---

## Features (mapped to pain)

### F1 — Discoverability (find)
- Search across native name (set by `/rename`), tags, repo, branch, first/last user message, files touched.
- Filter chips: by repo / branch / liveness / **remote-control on** / archived.
- Sort by last activity (default), started, repo.
- User-defined tags + flags overlay session metadata (additive, not replacing).

### F2 — Disposability (decide what to close)
Each row carries a **safe-to-close assessment**:
- Liveness: `alive` / `idle` / `terminated`.
- Awaiting user input vs. mid-turn.
- Time since last activity.
- Working tree state (uncommitted-file count in cwd).
- Files touched in this session.
- Open todos in last assistant turn.
- **Remote-control enabled** (a session you might be steering from your phone is implicitly riskier to kill).

Levels: `safe` / `review` / `risky`.

### F3 — Confident close
- "Archive" replaces "close" as the primary affordance.
- One-click resume: opens new Terminal tab in correct cwd, runs `claude --resume <uuid>`.
- "Reopen in same tab" if the original Terminal tab is still alive.
- Full-text search across **active + archived** sessions.
- "Sweep idle ≥7d, no RC" bulk action.

### F4 — Context at a glance (detail pane)
- Native name (from `/rename`) prominent at top.
- Remote-control status badge (with toggle action if Phase 0 confirms writable).
- First user message, last user message, last assistant message.
- Files touched (parsed from tool calls in JSONL).
- Branch / worktree / dirty state.
- Cost (if available).
- Notes (user-editable, persisted in overlay DB).

### F5 — Action surface (per row)

**Native** (drives Claude Code surfaces): Resume · Reopen-in-tab · Jump-to-tab · Rename (drives `/rename`) · Toggle remote control (drives `/rc`).

**Conductor-owned**: Archive · Unarchive · Add tag · Add flag · Add note · Open cwd in Finder.

The split matters: anything that's a real Claude Code concept (name, RC) goes back to Claude Code's storage, not into the overlay. Anything Conductor invents (tags, flags, notes, archive) lives in the overlay.

### F6 — Future (P5)
- `SessionStart` hook → instant new-session toast + dashboard injection.
- Menu bar widget (active count + awaiting-input badge + RC-on count).
- Dock badge for sessions awaiting input.
- "Start new session" launcher.

---

## Domain model (interfaces first)

The Swift translation lives in `Sources/Conductor/Domain/` (Phase 1+). The shape is fixed by the discovery spike:

```swift
public struct SessionView: Sendable {
    public let uuid: String                     // immutable identity

    public let raw: RawSession                  // from disk (FSEvents)
    public let process: ProcessState            // from OS (5s ps poll + .lock FSEvents)
    public let summary: SessionSummary          // tail-only JSONL parse
    public let meta: SessionMeta                // /rename + /rc — Phase 0 finds where
    public let git: GitContext?                 // cached shell-out
    public let terminal: TerminalLocation?      // lazy AppleScript
    public let overlay: UserOverlay             // tags/flags/notes/archive — ours

    public var status: Status                   // derived
    public var safeToClose: SafeToCloseAssessment  // derived
}

public struct RawSession: Sendable {
    public let uuid: String
    public let cwd: String                      // decoded from filename
    public let jsonlPath: String
    public let lockPath: String
    public let startedAt: Date
    public let lastModifiedAt: Date
}

public struct ProcessState: Sendable {
    public let uuid: String
    public let pid: Int32?                      // present iff lock file exists
    public let tty: String?                     // from `ps -o tty=`
    public let liveness: Liveness               // alive/idle/terminated
}

public struct SessionSummary: Sendable {
    public let messageCount: Int
    public let firstUserMessage: String?        // truncated
    public let lastUserMessage: String?
    public let lastAssistantMessage: String?
    public let filesEdited: [String]
    public let hasOpenTodos: Bool
    public let awaitingInput: Bool
    public let totalCost: Double?
    public let modelUsed: String?
}

public struct SessionMeta: Sendable {
    public let name: String?                    // from /rename
    public let remoteControlEnabled: Bool       // from /rc
    public let nameWritable: Bool               // capability flag (Phase 0)
    public let remoteControlWritable: Bool      // capability flag (Phase 0)
}

public struct GitContext: Sendable {
    public let repoUrl: String?
    public let repoName: String?
    public let branch: String?
    public let worktreePath: String
    public let isWorktree: Bool
    public let hasUncommittedChanges: Bool
    public let uncommittedFileCount: Int
}

public struct TerminalLocation: Sendable {
    public let windowId: Int
    public let tabIndex: Int
    public let tty: String
}

public struct UserOverlay: Sendable {
    public let uuid: String
    public let notes: String?
    public let flags: [Flag]
    public let tags: [String]
    public let archivedAt: Date?
    // No customName — names live in SessionMeta, not here.
}

public enum Flag: Sendable, Hashable {
    case important
    case blocked
    case waitingReview
    case cleanupCandidate
    case custom(String)
}

public struct SafeToCloseAssessment: Sendable {
    public enum Level: Sendable { case safe, review, risky }
    public let level: Level
    public let reasons: [String]
}
```

**Principles:**
- The JSONL + sidecars are source of truth. We never copy them.
- Overlay only owns metadata Conductor invents (tags, flags, notes, archive log).
- Native surfaces (`/rename`, `/rc`) are read directly; setters go through whatever channel Phase 0 proves safe.
- Read is always free. Write is gated on Phase 0 capability flags (`nameWritable`, `remoteControlWritable`).
- Domain layer has no I/O. Pure values. Stores own all I/O.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Conductor (SwiftUI)                    │
│ ┌────────────────┐ ┌─────────────┐ ┌──────────────────────┐ │
│ │ Dashboard view │ │ Detail pane │ │ Search / Archive UI  │ │
│ └────────┬───────┘ └─────┬───────┘ └──────────┬───────────┘ │
│          └───────────────┼────────────────────┘             │
│                          ▼                                  │
│ ┌──────────────────────────────────────────────────────────┐│
│ │       SessionRepository (in-memory aggregate; the API)   ││
│ │   composes:                                              ││
│ │   - JSONLStore       (FSEvents, tail-only parse)         ││
│ │   - LockStore        (FSEvents on .lock + 5s ps poll)    ││
│ │   - MetaStore        (reads /rename + /rc state; setter  ││
│ │                       gated on Phase 0 capability flags) ││
│ │   - GitResolver      (cached per cwd, lazy refresh)      ││
│ │   - OverlayStore     (SQLite + FTS5, write-through)      ││
│ │   - TerminalProbe    (osascript, lazy, on-action only)   ││
│ └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                  │                │                  │
                  ▼                ▼                  ▼
      ~/.claude/projects/  ~/.claude/<sidecars?>  Terminal.app
        (read-only)        (read; write iff safe)  (Scripting Bridge)
```

Six stores, one repository, one direction of flow. Each store: single responsibility, clear refresh cadence, no peer deps.

### Stack

- SwiftUI + Swift 5.10+, macOS 14+ (Sonoma).
- SwiftPM (no Xcode project committed).
- GRDB.swift for SQLite (Phase 3+); FTS5 for search (Phase 4).
- XCTest for unit + integration; swift-snapshot-testing for views (Phase 1+).

### Storage

- **Source of truth** — `~/.claude/projects/` (read-only).
- **Native session metadata** — wherever `/rename` and `/rc` write (Phase 0 finds out).
- **Overlay DB** — SQLite via GRDB.swift. Tables: `notes`, `tags`, `flags`, `archive_log`. **No name table** — names live with Claude Code.
- **FTS5** index across cached message text + notes (Phase 4).
- **In-memory** — `SessionRepository` cache, rebuilt on launch from disk + DB.

---

## Phased rollout

Each phase ships independently usable. Each phase has a sprint contract below.

| Phase | Theme | Effort | Key deliverable |
|---|---|---|---|
| **P0** | Confirm + reverse-engineer | ~2h | Capability addendum: where `/rename` and `/rc` persist; what's safe to write |
| **P1** | Read-only MVP | weekend | Domain + 4 stores + dashboard list + detail pane. **First useful day.** |
| **P2** | Resume + jump-to-tab + native actions | weekend | AppleScript bridge; resume; jump-to-tab; native rename + RC toggle (gated). **Closing becomes safe.** |
| **P3** | Overlay DB | weekend | SQLite + GRDB; tags/flags/notes/archive write-through; overlay editor in detail pane |
| **P4** | Archive + FTS | weekend | Archive affordance; FTS5 across active + archived; "sweep idle ≥7d no RC" bulk action. **Nothing is ever lost.** |
| **P5** | Polish | ongoing | Menu bar, dock badge, `SessionStart` hook auto-registration, awaiting-input notifications, "Start new session" launcher |

---

## Phase 0 — Confirm + reverse-engineer

### Sprint contract

**Goal:** Produce a written addendum that pins down (a) the on-disk shape of every field in `RawSession` / `SessionSummary` / `SessionMeta` against real sessions, and (b) where Claude Code persists `/rename` and `/rc` state, so Phase 1 can implement read paths and Phase 2 can decide whether write paths are first-class or roadmap-only.

**Owner:** branch `feat/phase-0-confirm-spike`.

**Estimated effort:** ~2 hours.

#### In scope

1. Run an `inspect_claude_sessions.sh` script (port from the discovery spike or write fresh) that, against the live `~/.claude/projects/`:
    - Lists every session JSONL and its sidecar `.lock` file (if any).
    - Confirms the encoded-cwd → real-path mapping is reversible.
    - Confirms the `.lock` schema (`pid`, `sessionId`, `startedAt`, `cwd`).
    - Confirms `ps -o pid,tty,command` resolves the lock's pid to a live tty.
    - Confirms one AppleScript probe of Terminal.app maps that tty to a window/tab.
2. Two targeted experiments on a throwaway session:
    - **Rename**: snapshot `~/.claude/` → run `/rename phase-0-marker` → snapshot again → diff. Identify which file holds the new name and the schema.
    - **Remote control**: snapshot → run `/rc` (or `/remote-control on`) → snapshot → diff. Same.
3. Decide read strategy + write feasibility for each surface, mapping outcomes to one of the four cases in the **Phase 0 fallback strategy** table below.
4. Commit the addendum as `docs/phase-0-addendum.md` with:
    - The exact file paths and schemas observed.
    - The decided values for `SessionMeta.nameWritable` and `SessionMeta.remoteControlWritable` (Phase 1 ships with these compiled in).
    - Whether Phase 2's "Rename" and "Toggle RC" actions are first-class, keystroke-fallback (case 3), or roadmap-only (case 4).

#### Out of scope

- Any Swift code in `Sources/`. (Phase 0 is a discovery + docs PR.)
- Any Phase 1 store implementations.
- Any change to capability flag values that contradicts the addendum (the addendum is the source of truth).

#### Follow-ups

- `[ ]` File a Linear/issue for any Anthropic-internal surface that must be requested upstream (case 4).

#### Functional checks

- `scripts/inspect_claude_sessions.sh` exists, is executable, and exits 0 on a healthy `~/.claude/projects/`.
- `docs/phase-0-addendum.md` exists, references at least one real session UUID by name, and explicitly answers four questions:
    1. Where does `/rename` persist?
    2. Where does `/rc` persist?
    3. Is `/rename` writable from Conductor without keystroking? (yes / keystroke / no)
    4. Is `/rc` writable from Conductor without keystroking? (yes / keystroke / no)
- The before/after diff snapshots from each experiment are committed under `docs/phase-0-evidence/` (or linked from the addendum).

#### Quality gates

- `scripts/blt-cp` passes (vacuously — no Swift source changes).
- The addendum contains no PII (other users' usernames, etc.) and no secrets.

#### Evaluator pass

The evaluator must:
1. Re-run `scripts/inspect_claude_sessions.sh` on their own `~/.claude/projects/` and paste the first 20 lines of output.
2. Confirm `docs/phase-0-addendum.md` exists and answers the four questions explicitly.
3. Spot-check one session UUID from the addendum against the real `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl` — verify the file exists.
4. For each of `/rename` and `/rc`: read the addendum's claim, then independently inspect the cited file and confirm the claim.
5. Verdict: PASS only if all four are independently confirmed.

#### Anti-self-praise rubric

- ❌ Addendum says "rename appears to write to X" without showing the diff.
- ❌ Capability flag set to `true` without an experiment that wrote successfully.
- ❌ "We confirmed" without a citation to the snapshot diff or session UUID.

---

### Phase 0 fallback strategy

| Outcome | What we do |
|---|---|
| Both names + RC are in plain JSONL meta records, schema obvious | Read + write both directly. F5 is fully native. `nameWritable = remoteControlWritable = true`. |
| State is in a sidecar JSON or central registry | Same as above, file-system bound. Fine. |
| State only exists in a running daemon's memory | Read via FS (latest snapshot), but writes happen by sending keystrokes to the Terminal tab. Functional but uglier. Capability flags `false`; Phase 2 ships keystroke-fallback action. |
| State requires speaking Anthropic's IPC we can't reverse | Read-only. We surface status, can't toggle. Document as roadmap, file feature request upstream. |

In all four cases the dashboard is shippable; only F5's native-action surface narrows.

---

## Phase 1 — Read-only MVP

### Sprint contract

**Goal:** Launch Conductor and see a live, sortable, searchable list of every Claude Code session on disk, with native name and remote-control status visible per row, and a detail pane showing the canonical fields. **First useful day.**

**Owner:** branch `feat/phase-1-read-only-mvp`.

**Estimated effort:** weekend.

#### In scope

1. **Domain types** (`Sources/Conductor/Domain/`): `SessionView`, `RawSession`, `ProcessState`, `SessionSummary`, `SessionMeta`, `GitContext`, `TerminalLocation`, `UserOverlay`, `Flag`, `SafeToCloseAssessment`. Pure values, no I/O. `Sendable`.
2. **Stores** (`Sources/Conductor/Stores/`):
    - `JSONLStore` — enumerates `~/.claude/projects/`, parses each JSONL tail-only into `RawSession` + `SessionSummary`, watches via FSEvents.
    - `LockStore` — reads `.lock` files, polls `ps -o pid,tty=` every 5s, watches via FSEvents on the lock files.
    - `MetaStore` — reads `/rename` and `/rc` state from wherever Phase 0 found them (read-only in Phase 1; capability flags compiled in).
    - `GitResolver` — shells out to `git -C <cwd> status --porcelain` and `git rev-parse --abbrev-ref HEAD`; caches per cwd.
3. **Repository** (`Sources/Conductor/Repository/SessionRepository.swift`): composes the four stores, publishes `[SessionView]` as an `@Observable` aggregate, computes `status` and `safeToClose`.
4. **Views** (`Sources/Conductor/Views/`):
    - `DashboardView` — list view with one row per session: native name (or first-user-message fallback), repo + branch, liveness badge, RC badge, last-activity time, safe-to-close level chip.
    - `DetailPaneView` — fields per the F4 spec.
    - Empty state when `~/.claude/projects/` is empty.
5. **App entry** (`Sources/Conductor/App/`): SwiftUI App with one window, dashboard + detail split, native name in toolbar, search field, sort menu, basic filter chips.

#### Out of scope

- Any **action** that writes to Claude Code (resume, rename setter, RC toggle) — Phase 2.
- Overlay DB (tags, flags, notes, archive) — Phase 3.
- Archive view + FTS — Phase 4.
- Menu bar / dock badge — Phase 5.

#### Follow-ups

- `[ ]` Performance budget pass once we hit 100+ sessions in test fixtures (Phase 2 if it surfaces; backlog otherwise).

#### Functional checks

Unit tests:

- `Tests/ConductorTests/Domain/SafeToCloseTests.swift::testIdleCleanTreeNoRCIsSafe` — rule-by-rule unit test of the assessment.
- `Tests/ConductorTests/Stores/JSONLStoreTests.swift::testParsesRealWorldSession` — fixture JSONL → expected `RawSession` + `SessionSummary`.
- `Tests/ConductorTests/Stores/JSONLStoreTests.swift::testHandlesPartialFinalLine` — JSONL with a half-written final record doesn't crash; previous record still parsed.
- `Tests/ConductorTests/Stores/JSONLStoreTests.swift::testReversesEncodedCwd` — encoded-cwd round-trips.
- `Tests/ConductorTests/Stores/LockStoreTests.swift::testReadsLockSchema` — fixture `.lock` → expected pid/tty/cwd.
- `Tests/ConductorTests/Stores/LockStoreTests.swift::testTerminatedWhenLockGone` — no lock + last-activity > 30s → liveness terminated.
- `Tests/ConductorTests/Stores/MetaStoreTests.swift::testReadsRenameState` — uses fixture path from Phase 0; reads expected name.
- `Tests/ConductorTests/Stores/MetaStoreTests.swift::testReadsRemoteControlState` — same shape.
- `Tests/ConductorTests/Stores/GitResolverTests.swift::testReportsBranchAndDirtyState` — temp-dir git repo with one uncommitted file → `hasUncommittedChanges = true`, `uncommittedFileCount = 1`.

Integration tests (use a fixture `~/.claude/projects/` snapshot under `Tests/Fixtures/`):

- `Tests/ConductorTests/Repository/SessionRepositoryTests.swift::testAggregatesAllStores` — fixture snapshot → repository emits `N` sessions with all fields populated.

Snapshot tests (pinned under `Tests/ConductorTests/Views/__Snapshots__/`):

- `DashboardSnapshotTests.testEmptyState` — empty fixture → "No sessions" empty view.
- `DashboardSnapshotTests.testSingleSessionRow` — one fixture session → row with native name, branch, RC badge.

Architecture tests:

- `Tests/ConductorTests/Architecture/LayeringTests.swift::testDomainHasNoPlatformImports` — files in `Sources/Conductor/Domain/` import only `Foundation` (no `AppKit`, no `Process`, no `SQLite`, no `GRDB`).
- `Tests/ConductorTests/Architecture/LayeringTests.swift::testStoresDoNotImportRepositoryOrViews` — files in `Sources/Conductor/Stores/` do not import `Repository/` or `Views/`.

#### Quality gates

- `scripts/blt-cp` passes (build/format/lint/test all green).
- Coverage on **new** Phase 1 code ≥ 80% (measured via `xcrun llvm-cov` against the Phase 1 file set).
- All files ≤ 300 LOC (warn) or ≤ 600 LOC (hard).
- All public types and functions have `///` doc comments. swift-format's `ValidateDocumentationComments` is enabled in this PR.
- No TODOs in shipped code (filed as follow-ups instead).

#### Evaluator pass

The evaluator must:
1. Clone PR branch fresh, run `./scripts/install-hooks.sh && ./scripts/blt-cp`. Paste output.
2. Run `swift run conductor` (or, once a real `.app` is wired, launch it). Take a screenshot of the dashboard. Confirm it shows real entries from the evaluator's own `~/.claude/projects/`.
3. Pick three sessions from the dashboard. For each: open detail pane, confirm native name, repo, branch, RC badge match what `cat <jsonl> | head` and the addendum-cited rename/rc files say.
4. Touch a session JSONL (`echo >> …`) and confirm the dashboard reflects the new last-activity within ≤ 5s (FSEvents is wired).
5. Run the named tests in isolation: `swift test --filter ConductorTests.Stores.JSONLStoreTests`. Paste the test count.
6. Run `xcrun llvm-cov` for coverage; cite the percentage for Phase 1 files.

Verdict PASS requires all six artifacts cited.

#### Anti-self-praise rubric

- ❌ "Dashboard shows sessions" without a screenshot.
- ❌ "FSEvents works" without the touch-test artifact.
- ❌ "Tests pass" without the count.
- ❌ A `safeToClose` rule asserted but not unit-tested.
- ❌ Domain type that imports `Foundation.FileManager` (would fail the architecture test, but worth calling out).

---

## Phase 2 — Resume + jump-to-tab + native actions

### Sprint contract

**Goal:** Per-row actions become useful. Resume opens a new Terminal tab in the right cwd and runs `claude --resume`. Jump-to-tab focuses an existing Terminal tab if alive. Rename and RC toggle drive Claude Code's own `/rename` and `/rc` (gated on Phase 0 capability flags). **Closing becomes safe** because resume is a click away.

**Owner:** branch `feat/phase-2-actions`.

**Estimated effort:** weekend.

#### In scope

1. **TerminalProbe** (`Sources/Conductor/Platform/TerminalProbe.swift`) — AppleScript bridge that:
    - Lists Terminal windows + tabs and their `tty`s.
    - Maps a given `tty` to `(windowId, tabIndex)` if found.
    - Opens a new tab in a given cwd and runs a given command.
    - Activates Terminal and focuses a given tab by id.
2. **MetaStore writers** (`Sources/Conductor/Stores/MetaStore.swift`) — `setName(_:for:)` and `setRemoteControl(_:for:)`. Behavior depends on Phase 0 outcome:
    - Cases 1 + 2: direct file write (atomic — write-temp-then-rename) with a schema test.
    - Case 3: keystroke fallback via TerminalProbe (`/rename foo` typed into the tab).
    - Case 4: setter is `unavailable` (compile-time `@available(*, unavailable)`) and the action is hidden from UI.
3. **Action surface** (`Sources/Conductor/Views/Actions/`):
    - Resume button — new Terminal tab in cwd, runs `claude --resume <uuid>`.
    - Reopen-in-tab — if `terminal` is non-nil, sends `claude --resume <uuid>` to that tab; otherwise falls back to Resume.
    - Jump-to-tab — focuses the existing Terminal tab.
    - Rename action — gated on `meta.nameWritable`.
    - Toggle RC action — gated on `meta.remoteControlWritable`.
    - "Open cwd in Finder" — `NSWorkspace.shared.activateFileViewerSelecting(_:)`.
4. **Confirm-before-destructive** affordance for any action with a non-trivial side effect (rename, toggle RC); resume/jump-to-tab are non-destructive and don't confirm.

#### Out of scope

- Overlay DB writes (tags, flags, notes, archive) — Phase 3.
- Archive UI — Phase 4.
- Menu bar — Phase 5.

#### Follow-ups

- `[ ]` Telemetry / action log (which actions were taken when) — opt-in, defer to backlog.
- `[ ]` Multi-session bulk actions (Resume all in repo X) — Phase 4 ("sweep" pattern).

#### Functional checks

Unit tests:

- `Tests/ConductorTests/Platform/TerminalProbeTests.swift::testParsesAppleScriptListing` — given a fixture AppleScript output, parses into `[TerminalTab]`.
- `Tests/ConductorTests/Platform/TerminalProbeTests.swift::testEscapesShellArgs` — paths with spaces, quotes, backticks are correctly shell-quoted.
- `Tests/ConductorTests/Stores/MetaStoreWriteTests.swift::testWritesRenameAtomically` (cases 1+2 only) — write succeeds; partial write does not corrupt the file.
- `Tests/ConductorTests/Stores/MetaStoreWriteTests.swift::testKeystrokeFallbackComposesCommand` (case 3 only) — given a session, composes the right `/rename foo` keystroke payload.
- `Tests/ConductorTests/Stores/MetaStoreWriteTests.swift::testCapabilityGatedSetterUnavailable` (case 4 only) — calling the setter does not compile (compile-fail test) or returns the correct error.

Integration tests (gated on a real Terminal.app being present and approved):

- `Tests/ConductorTests/Platform/TerminalProbeIntegrationTests.swift::testOpensTabAndRuns` — opens a tab, runs `echo conductor-marker`, polls the tab's stdout history (via AppleScript), asserts the marker appears. (Marked `XCTSkip` if `TERMINAL_APP_TEST=1` is unset.)

Architecture tests:

- `Tests/ConductorTests/Architecture/LayeringTests.swift::testActionsLiveInViewsLayer` — only `Sources/Conductor/Views/` may invoke action methods on the repository.

#### Quality gates

- All Phase 1 gates plus:
- New action surface code coverage ≥ 75% (some AppleScript paths are environmental and skipped in unit tests; integration tests fill the gap).
- AppleScript strings live in dedicated `.applescript` files or top-of-file Swift constants — no ad-hoc string interpolation in business logic.

#### Evaluator pass

The evaluator must:
1. On a real session, click Resume. Confirm a new Terminal tab opens in the right cwd and `claude --resume <uuid>` runs (capture screenshot or screen recording).
2. Click Jump-to-tab on a session whose Terminal tab is alive. Confirm Terminal activates and the right tab focuses.
3. Click Jump-to-tab on a session whose Terminal tab has been closed. Confirm graceful fallback (Resume), not a crash.
4. (Cases 1–3) Click Rename, set a new name, observe the JSONL or sidecar file change matches the schema in the addendum, and the dashboard refreshes within ≤ 5s.
5. (Cases 1–3) Click Toggle RC, observe the JSONL or sidecar bit flips and the badge updates.
6. (Case 4) Confirm Rename and Toggle RC are absent from the UI (not greyed out — absent).

Verdict PASS requires steps 1–3 and the appropriate subset of 4–6.

#### Anti-self-praise rubric

- ❌ "Resume works" without screen recording.
- ❌ "Rename writes correctly" without diffing the addendum-cited file.
- ❌ Action method called from the repository layer (architecture violation).
- ❌ AppleScript built via `String(format:…)` in `Stores/` (concern leak).
- ❌ "Falls back gracefully" without simulating the failure.

---

## Phase 3 — Overlay DB (notes, flags, tags)

### Sprint contract

**Goal:** A SQLite overlay DB owns Conductor-invented metadata. Detail pane gets a notes editor, tags input, and flag toggles. The dashboard search reads tags. Conductor's metadata never tries to overwrite Claude Code's.

**Owner:** branch `feat/phase-3-overlay`.

**Estimated effort:** weekend.

#### In scope

1. **GRDB.swift dependency** added to `Package.swift`.
2. **Overlay schema** (`Sources/Conductor/Stores/Overlay/Schema.swift`):
    - `notes(uuid TEXT PRIMARY KEY, body TEXT NOT NULL, updatedAt INTEGER NOT NULL)`
    - `tags(uuid TEXT NOT NULL, tag TEXT NOT NULL, PRIMARY KEY(uuid, tag))`
    - `flags(uuid TEXT NOT NULL, flag TEXT NOT NULL, PRIMARY KEY(uuid, flag))`
    - `archive_log(uuid TEXT PRIMARY KEY, archivedAt INTEGER NOT NULL, reason TEXT)`
    - Migration runner (`migrations/001_initial.swift`).
3. **OverlayStore** (`Sources/Conductor/Stores/OverlayStore.swift`) — CRUD for each table; emits change events for repository to merge.
4. **Repository merge** — `SessionRepository` composes overlay into `SessionView.overlay`.
5. **Detail pane editor** — Notes textarea (auto-save, debounced 500ms), tag input (chip-style), flag toggle bar.
6. **Dashboard filter** — filter chip "tag:" for any tag in use.

#### Out of scope

- Archive UI (the `archive_log` table is created and an `archive(uuid:)` API exists, but the UI affordance + sweep + tombstone are Phase 4).
- FTS5 across notes — Phase 4.

#### Follow-ups

- `[ ]` Notes export (Markdown) — backlog.
- `[ ]` Custom flag colors — backlog.

#### Functional checks

- `Tests/ConductorTests/Stores/OverlayStoreTests.swift::testCRUDRoundtrip` — write a note, read it back; bytes match.
- `Tests/ConductorTests/Stores/OverlayStoreTests.swift::testMigratesFromEmpty` — apply migrations to a fresh DB; schema matches expected DDL.
- `Tests/ConductorTests/Stores/OverlayStoreTests.swift::testTagUniqueness` — adding the same tag twice does not duplicate.
- `Tests/ConductorTests/Repository/RepositoryOverlayMergeTests.swift::testOverlayMerges` — repository emits SessionView with overlay populated from DB.
- Snapshot tests: `DetailPaneSnapshotTests.testWithNotesAndTags`.

#### Quality gates

- All Phase 1 + 2 gates.
- Migrations are forward-only (downgrade is not a Phase 3 concern). Architecture test asserts `migrations/` files are append-only by name.
- No string SQL in business logic — all SQL through GRDB query builders or a single `Schema.swift` file.

#### Evaluator pass

1. Add a note to a session via the UI. Quit Conductor. Reopen. Note is still there.
2. Open the SQLite DB at `~/Library/Application Support/Conductor/overlay.sqlite` with `sqlite3` and `SELECT * FROM notes WHERE uuid = '<uuid>'`. Paste the row.
3. Add three tags. Filter the dashboard by one. Confirm filter narrows to the tagged session(s).
4. Confirm Conductor never writes a `name` column anywhere — `sqlite3 … '.schema' | grep -i name` returns nothing.

#### Anti-self-praise rubric

- ❌ "Notes persist" without the SQL row.
- ❌ "Migrations run on first launch" without observing the `~/Library/Application Support/Conductor/overlay.sqlite` file appear.

---

## Phase 4 — Archive + full-text search

### Sprint contract

**Goal:** "Archive" is a primary affordance, with a tombstone view that is fully searchable alongside active sessions. FTS5 indexes session text + notes. Bulk action: "Sweep idle ≥7d, no RC". **Nothing is ever lost.**

**Owner:** branch `feat/phase-4-archive-fts`.

**Estimated effort:** weekend.

#### In scope

1. **Archive action** in detail pane and as bulk action — writes a row to `archive_log` (timestamp + optional reason). Archived sessions are filtered out of the default dashboard view.
2. **Archive view** — toggle filter "Show archived" or a separate sidebar entry. Shows archived sessions with the option to Unarchive (delete row from `archive_log`).
3. **FTS5 virtual table** — index over: notes body, tag set, native name, first/last user message, last assistant message. Triggers keep it in sync with the source tables.
4. **Search box** — single-input, queries FTS5 for ranked results across active + archived. Cmd-F focuses it.
5. **Sweep action** — "Sweep idle ≥7d, no RC" lists candidates (with safe-to-close info), confirm-then-archive.

#### Out of scope

- Multi-Mac sync — explicitly YAGNI per plan.
- Auto-archive policy (set-and-forget archiving) — backlog.

#### Follow-ups

- `[ ]` Export archived as JSONL bundle — backlog.

#### Functional checks

- `Tests/ConductorTests/Stores/OverlayStoreTests.swift::testArchiveRoundtrip`.
- `Tests/ConductorTests/Stores/FTSTests.swift::testIndexesOnNoteWrite` — write a note, query FTS, get the session.
- `Tests/ConductorTests/Stores/FTSTests.swift::testRankedAcrossActiveAndArchived` — fixture with 5 active + 5 archived, query, ordering matches expected.
- `Tests/ConductorTests/Repository/SweepTests.swift::testListsIdleNoRCCandidates`.

#### Quality gates

- All prior gates.
- FTS5 query latency < 50ms for a corpus of 1000 sessions (microbenchmark in tests, marked `XCTSkip` unless `RUN_PERF=1`).

#### Evaluator pass

1. Archive a session. Confirm it disappears from default view, appears in archived view, search still returns it.
2. Search for an exact phrase from a note. Confirm the session ranks in top 3.
3. Run sweep. Confirm preview shows expected candidates with safe-to-close info. Cancel — nothing changes. Run again, confirm — sessions move to archived.

#### Anti-self-praise rubric

- ❌ "Archive works" without showing the disappear/reappear in the UI.
- ❌ "Sweep is safe" without showing the cancel-path leaves state unchanged.

---

## Phase 5 — Polish

### Sprint contract

**Goal:** Conductor lives in your menu bar. Dock badge shows awaiting-input count. New sessions appear instantly via the `SessionStart` hook. You can launch a new session from a menu.

**Owner:** branch `feat/phase-5-polish`.

**Estimated effort:** ongoing — split into sub-chunks per deliverable.

#### In scope (each a sub-chunk with its own contract before code lands)

1. **Menu bar widget** — `NSStatusItem` with active count, awaiting-input badge, RC-on count. Click → mini popover with quick filters.
2. **Dock badge** — number of sessions awaiting user input.
3. **`SessionStart` hook auto-registration** — Conductor installs (and keeps current) the global hook config in `~/.claude/settings.json` (or the appropriate file per upstream). Hook posts to a local Unix socket Conductor listens on; new session appears in dashboard within 1s.
4. **Awaiting-input notifications** — UserNotifications when a session goes from mid-turn to awaiting-input.
5. **"Start new session" launcher** — picks a repo, opens new Terminal tab in cwd, runs `claude`.

#### Out of scope (each)

- Multi-Mac sync, cloud sync, account auth — YAGNI.

#### Follow-ups

- `[ ]` Public release / open-source — once Phase 4 ships and the repo is well-loved enough to share.

#### Functional checks (per sub-chunk; written in the sub-chunk's contract before code)

(Stub — each sub-chunk fills in its own.)

#### Quality gates

All prior gates. Plus:

- Menu bar / dock badge updates within 1s of a state change.
- `SessionStart` hook injection is idempotent — re-running registration on an already-registered hook is a no-op.

#### Evaluator pass

(Per sub-chunk.)

#### Anti-self-praise rubric

(Per sub-chunk; same template — claims need artifacts, not narration.)

---

## Open questions

1. **Public or personal?** Every Claude Code power user hits this pain. If open-sourcing is on the table, license + screenshot hygiene + docs go on the list. Personal-only is fine. Flag intent before Phase 4 ships.
2. **Multi-Mac sync?** YAGNI for now. Local-only is faster, simpler.
3. **Remote-control writability** — answered by Phase 0. The plan accommodates either outcome.

---

## Status

| Phase | Status | Branch | Notes |
|---|---|---|---|
| Harness scaffold | ✅ Landed | `main` | Initial commit; CI + hook installed |
| Phase 0 | ⏳ Not started | `feat/phase-0-confirm-spike` | Pick up from here |
| Phase 1 | ⏳ Blocked on P0 | — | |
| Phase 2 | ⏳ Blocked on P1 | — | |
| Phase 3 | ⏳ Blocked on P2 | — | |
| Phase 4 | ⏳ Blocked on P3 | — | |
| Phase 5 | ⏳ Blocked on P4 | — | |

Update this table as phases land.
