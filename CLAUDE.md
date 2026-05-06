# CLAUDE.md

Guidance for Claude Code (and any human collaborator) working in the Conductor repo.

> **STOP: Read [AGENTS.md](AGENTS.md) first.** It contains the mandatory BLT-CP rules and safety constraints. This file is the *context engineering* layer — what Conductor is, how it's built, and how we work.

---

## What Conductor is

A native macOS SwiftUI app that gives you a dashboard over your 40+ concurrent Claude Code sessions across ~10 repos. Three pains it solves:

1. **Find** — locate the session you want among many.
2. **Decide** — know which sessions are safe to close.
3. **Recover** — close without losing context, with a 2-click way back.

Once recovery is trivial, "close" stops being a one-way door. That's the unlock.

**Source of truth lives in `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl`** plus sibling lock files. Conductor never owns the session — it observes, augments, and surfaces. The Claude Code processes are authoritative; we are a read-mostly companion with a small overlay DB for things only Conductor invents (tags, flags, notes, archive log).

Full plan: see [PROJECT_PLAN.md](PROJECT_PLAN.md).

---

## How we build (Harness Engineering)

This repo is **harness-engineered**. Modeled on executive-assistant's EA-205 (Phase 1 — Harden the Harness) and EA-270 (separated QA evaluator, sprint contracts, concrete grading, anti-self-praise).

Three pillars:

1. **Context Engineering** — every chunk starts with a written *sprint contract* (see [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md)). Concrete, testable acceptance criteria *before* code. The author and reviewer agree the contract is achievable; only then does code land.
2. **Architectural Constraints** — encoded as code: `swift build -Xswiftc -warnings-as-errors`, `swiftlint --strict`, `swift-format lint --strict`, file/function size limits, dependency-layering tests (Phase 1+). Violations fail the build, not a code review.
3. **Entropy Management** — pre-commit hook + CI run the full BLT-CP. No warnings shipped. No TODOs in shipped code. PR description matches reality. Force-pushing main is forbidden.

Four phases of the harness itself (the *meta-plan*, not the product plan):

1. **Harden the Harness** *(this initial commit)* — pre-commit hook, BLT-CP, lint, format, CI on every push, sprint contract template, evaluator role, grading criteria.
2. **Formalize Context** — domain-model layering tests, architecture tests as XCTest cases, file-size ratchet, public-API doc requirements.
3. **Orchestration** — separated evaluator agent, automated sprint-contract verification, generated PR comments grading each chunk against the contract.
4. **Bring to Work** — once stable, generalize patterns into a shareable `harness-swift` skill so the next Swift app starts here.

---

## Tech stack

- **Language**: Swift 5.10+ (toolchain pinned in `Package.swift`).
- **Platform**: macOS 14+ (Sonoma). SwiftUI for UI, AppKit only when necessary (menu bar, dock badge, AppleScript bridge).
- **Build system**: Swift Package Manager. No Xcode project committed; the .swiftpm/ folder is gitignored. `swift build`, `swift test`, `swift run` from the CLI; open `Package.swift` in Xcode if you want the GUI.
- **Storage**: SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift) (Phase 3+) for the overlay DB. FTS5 for search (Phase 4).
- **System integration**: FSEvents (file watcher), Scripting Bridge / AppleScript (Terminal.app), `Process` for `ps`/`git` shell-outs, UserNotifications for awaiting-input toasts.
- **Tests**: XCTest. Snapshot tests via `swift-snapshot-testing` once UI lands.
- **Lint/format**: SwiftLint (strict, zero-warning) + swift-format (Apple's, bundled with Xcode).

---

## Architecture (one-paragraph version)

Six stores, one repository, one direction of flow.

```
Views (SwiftUI) → SessionRepository (in-memory aggregate) →
  JSONLStore · LockStore · MetaStore · GitResolver · OverlayStore · TerminalProbe
        ↓             ↓          ↓            ↓             ↓              ↓
   ~/.claude/projects/  ~/.claude/   sidecars    git CLI    SQLite/FTS5   AppleScript
   (read-only)         (read+write)  (Phase 0)
```

- The JSONL + sidecars are the source of truth. We never copy them.
- Overlay only owns metadata Conductor invents (tags, flags, notes, archive log).
- Native surfaces (`/rename`, `/rc`) are read directly; setters go through whatever channel Phase 0 proves safe.
- Read is always free. Write is gated on Phase 0 capability flags.

Full domain model: [PROJECT_PLAN.md § Domain model](PROJECT_PLAN.md#domain-model-interfaces-first).

---

## Repo layout (target)

```
Conductor/
├── Package.swift               # SwiftPM manifest
├── Sources/
│   └── Conductor/
│       ├── App/                # SwiftUI app entry, scenes, menu bar
│       ├── Domain/             # SessionView, RawSession, etc. (no I/O)
│       ├── Stores/             # JSONLStore, LockStore, MetaStore, …
│       ├── Repository/         # SessionRepository (aggregate)
│       ├── Views/              # Dashboard, Detail, Search, Archive
│       └── Platform/           # FSEvents, AppleScript, ProcessProbe
├── Tests/
│   └── ConductorTests/         # XCTest (unit + integration + snapshot)
├── scripts/                    # blt-cp, install-hooks.sh, verify-hooks.sh
├── docs/                       # SPRINT_CONTRACT_TEMPLATE, GRADING, EVALUATOR
├── .github/workflows/ci.yml    # Build / lint / format / test on every push
├── .swiftlint.yml              # Strict ruleset
├── .swift-format               # Apple swift-format config
├── AGENTS.md                   # Mandatory rules (BLT-CP, safety)
├── CLAUDE.md                   # This file
├── PROJECT_PLAN.md             # Phased plan w/ sprint contracts
└── README.md
```

Phase 0 ships nothing in `Sources/Conductor/` beyond the bootstrap. Phase 1 fills in `Domain/` and `Stores/`. Don't pre-create empty folders — let them appear as the code does.

---

## Coding standards

- **Domain layer has no I/O.** `Domain/` types are pure values. Stores own all I/O. Repository composes stores.
- **One direction of flow.** Stores never call repository or views. Views never call stores. The repository is the only seam.
- **Single responsibility per store.** Each store owns one cadence and one source. JSONLStore handles `~/.claude/projects/`; LockStore handles `<uuid>.lock`. They do not know about each other.
- **No force-unwraps, no force-tries, no force-casts.** `swiftlint` errors on all three.
- **Zero warnings shipped.** `-Xswiftc -warnings-as-errors`. If you genuinely need to suppress something, justify it inline with a comment SwiftLint can read.
- **Public API gets `///` doc comments.** swift-format's `ValidateDocumentationComments` enforces it once we lift the disable in Phase 1.
- **Test-first when the contract is clear.** When the sprint contract specifies behavior, the failing test lands before the code that satisfies it.
- **No dead code, no commented-out code, no TODOs in shipped code.** If a TODO is genuinely needed, file it and link the issue from the comment.

Defaults & idioms (lifted from executive-assistant's spirit, ported to Swift):

- Prefer `@Observable` over `ObservableObject` (Swift 5.9+ macro).
- Prefer `inject(_:)`-style protocol injection in stores; testable seams are mandatory.
- Prefer `Result` or `throws` over Bool-returning methods that hide error info.
- Prefer enums with associated values over stringly-typed flags.
- DRY > SOLID > KISS > YAGNI in that priority. Duplicate code is the most expensive defect.
- File >300 lines: split. Function >50 lines: refactor.

---

## Workflow

### Claim work first

Before writing code:

1. Confirm the chunk you're working on (Phase 0, Phase 1, etc.) and read the **sprint contract** for that chunk in [PROJECT_PLAN.md](PROJECT_PLAN.md).
2. If the contract is missing or unclear, **stop and write/update it first.** No code without a contract.
3. Open a feature branch: `feat/phase-N-short-name` or `fix/short-name`.

### Sprint contract template

Every chunk fills in [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md):

- **Goal** (one sentence the reader can hold in their head).
- **In scope / out of scope** (explicit; out-of-scope items get a follow-up entry, not silent omission).
- **Functional checks** (XCTest cases that must pass — names listed *before* the tests are written).
- **Quality gates** (build, lint, format, coverage threshold, file-size limits).
- **Evaluator pass** (what the separated evaluator must verify — runtime behavior, on-disk side effects, log inspection).
- **Anti-self-praise rubric** (concrete failure conditions: "evidence required for every claim, not 'looks good'"; "screenshots not narration"; "show the test output, don't summarize it").

### Pre-commit (BLT-CP)

`scripts/blt-cp` runs:

1. `swift build -Xswiftc -warnings-as-errors`
2. `xcrun swift-format lint --strict`
3. `swiftlint --strict`
4. `swift test --parallel`

Installed as a git pre-commit hook by `scripts/install-hooks.sh`. **Never `--no-verify`** unless you've justified it in the commit message.

### PR description matches reality

If the PR description says "implements X", X must be implemented in this PR. If you couldn't finish, **split the PR** before merging. No "partial — Y in follow-up" without an explicit follow-up commitment in the description.

### Git rules

- **Never push directly to main.** Always feature branch + PR (one exception: this initial harness commit).
- **Never force-push main.** Ever.
- **Never skip hooks** (`--no-verify`) without explicit justification.
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`, `test/`, `chore/`.

---

## Evaluator skepticism rules

The evaluator's job is to **disprove** the author's claims, not to confirm them. When a chunk lands:

- Run the app. Don't trust "it builds, ship it" — *use the feature*.
- Inspect the disk. If the contract says "writes a tag to overlay DB", open the SQLite file and verify the row exists.
- Inspect the logs. If the contract says "MetaStore reads RC state", grep the log for the read.
- Re-run the failing case. If a bug was claimed fixed, reproduce the original failure first, then confirm the fix.
- "Looks good" is not evidence. The evaluator must produce a **graded report** against the sprint contract, citing artifacts.

Full role: [docs/EVALUATOR.md](docs/EVALUATOR.md). Full grading rubric: [docs/GRADING_CRITERIA.md](docs/GRADING_CRITERIA.md).

---

## Anti-self-praise

Forbidden language in commits, PRs, evaluator reports:

- "Looks good." "Works as expected." "All tests pass." (without showing them)
- "Comprehensive." "Robust." "Production-ready." (vague claims)
- "I think this should…" (in evaluator output — they verify, they don't think)
- "Successfully implemented." (every PR claims this; it carries no signal)

Required language:

- Specific test names that ran and their result.
- Specific files that changed and what changed.
- Specific behaviors observed at runtime.
- Specific failure modes considered, and how each is handled.

The evaluator agent and the human reviewer enforce this.

---

## When in doubt

- **Read [PROJECT_PLAN.md](PROJECT_PLAN.md) before writing code.**
- **Read [AGENTS.md](AGENTS.md) before committing.**
- **Read [docs/EVALUATOR.md](docs/EVALUATOR.md) before reviewing.**
- Ask. Or open a discovery issue and update the plan first.
