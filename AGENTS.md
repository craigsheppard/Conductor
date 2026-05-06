# AGENTS.md — Mandatory Rules

This file contains rules that **must** be followed by any agent (AI or human) working on Conductor. Modeled on executive-assistant's AGENTS.md (EA-205), adapted for Swift.

> **Read [CLAUDE.md](CLAUDE.md) for the *why*.** This file is the *what*.

---

## 🔧 Setup (do this once per clone)

```bash
./scripts/install-hooks.sh
```

Without this, `git commit` silently bypasses BLT-CP. The pre-commit hook itself refuses to run if `verify-hooks.sh` doesn't see the marker, so missing hooks fail closed at commit time. But you should still install on first clone — don't wait for the failure.

You'll also need:

- **SwiftLint** — `brew install swiftlint`
- **swift-format** — bundled with Xcode 16+ / CommandLineTools (`xcrun swift-format`). No install needed if you have a current Xcode.
- **Swift 5.10+ / macOS 14+ SDK** — bundled with Xcode 16+.

CI installs these automatically on every push.

---

## 🚨 BLT-CP: Build-Lint-Test before Commit-Push

**MANDATORY** for any commit or PR. No exceptions.

### Quick (recommended)

```bash
./scripts/blt-cp
```

### Manual

```bash
swift build -Xswiftc -warnings-as-errors && \
  xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests && \
  swiftlint lint --strict --quiet && \
  swift test --parallel && \
  echo "✅ BLT-CP PASSED"
```

If **any** step fails, **DO NOT COMMIT**. Fix the issue. Do not skip the step.

The pre-commit hook runs all four steps. CI runs them again on push and PR. They must pass at every gate.

---

## 🧱 Architectural Constraints (enforced by the build)

These are **build failures**, not review nits:

1. **Zero warnings shipped.** `-Xswiftc -warnings-as-errors` enforces it at build time. SwiftLint enforces it at lint time. If a warning is correct (e.g., a deprecation), suppress it inline with a comment that explains *why* and references the upstream issue.
2. **No force-unwrap, force-try, force-cast.** SwiftLint errors on all three (`force_unwrapping`, `force_try`, `force_cast`).
3. **Line length ≤ 120.** SwiftLint errors at 120.
4. **Cyclomatic complexity ≤ 10.** SwiftLint errors at 10.
5. **File length ≤ 600 lines.** Files >300 should be split; >600 is a hard error. Tests are not exempt.
6. **Function body ≤ 80 lines.** Functions >50 lines should be refactored.
7. **Domain layer has no I/O.** `Sources/Conductor/Domain/` may not import `Foundation.FileManager`, `SQLite`, `GRDB`, AppKit, `Process`, or any platform integration. Architecture tests (added in Phase 1) enforce this.
8. **One direction of flow.** Stores never call repository or views. Views never call stores. Architecture tests enforce.
9. **Public API has `///` doc comments.** swift-format's `ValidateDocumentationComments` enforces, once enabled in Phase 1.

---

## 🔒 Git Safety

- **Never push directly to `main`.** Branch + PR. One exception: the initial scaffold commit (this commit) lands directly on main because there's nothing to PR against yet.
- **Never force-push to `main`.** Ever. Not for any reason.
- **Never skip hooks** with `--no-verify` unless you've documented *why* in the commit message body. The hook is the harness — bypassing it makes the harness lie.
- **Branch naming**: `feat/`, `fix/`, `docs/`, `refactor/`, `test/`, `chore/`.

If you encounter unexpected files, branches, or state, **investigate before deleting or overwriting**. Resolve merge conflicts; don't discard.

---

## 📝 PR Requirements

A PR is mergeable when **all** of these hold:

1. ✅ All BLT-CP checks pass (zero errors, zero warnings).
2. ✅ The PR's sprint contract (in `docs/sprints/<phase-or-task>.md` or in the PR description) is fully satisfied. Each functional check has a passing test cited by name. Each evaluator pass has a recorded artifact.
3. ✅ PR description matches implementation completely. If you couldn't implement the full description, **split the PR**, don't merge "partial".
4. ✅ Evaluator agent has produced a graded report and the report says PASS, citing artifacts (not narration).
5. ✅ No TODOs in shipped code (filed as follow-ups instead).
6. ✅ No dead code, no commented-out code, no unused imports.

---

## 🧠 Sprint Contract Discipline

**No code without a contract.**

Before writing any code for a chunk:

1. Read [PROJECT_PLAN.md](PROJECT_PLAN.md) for the chunk's contract.
2. If the contract is missing details, update the plan first and commit that as a docs change.
3. Only then open the implementation branch.

The contract is the single source of truth for "done." The evaluator grades against it. The PR description quotes it.

Template: [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md).

---

## 🚫 Anti-Self-Praise

Forbidden in commits, PR descriptions, evaluator reports:

- "Works as expected" without showing the expectation.
- "All tests pass" without naming them.
- "Comprehensive", "robust", "production-ready" without evidence.
- "Looks good to me" — the evaluator does not opine, it verifies.

Required:

- Specific test names that ran. Specific files that changed. Specific behaviors observed.
- For UI changes: a screenshot or screen recording. Type-checking and tests verify code correctness, not feature correctness.

---

## 🐛 Discovered Issues

If you find a bug, tech-debt, or improvement **outside the current chunk's scope**:

- Don't fix it inline — that's scope creep, and it dilutes the sprint contract.
- Don't ignore it — that's lost knowledge.
- File it as a follow-up in `PROJECT_PLAN.md` under the relevant phase, or open a separate issue and link from the PR's "Discovered Issues" section.

---

## 📚 Required Reading

Before your first commit, read in this order:

1. [AGENTS.md](AGENTS.md) — this file.
2. [CLAUDE.md](CLAUDE.md) — context engineering, stack, architecture, workflow.
3. [PROJECT_PLAN.md](PROJECT_PLAN.md) — phased plan with sprint contracts.
4. [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md) — what every chunk's contract looks like.
5. [docs/GRADING_CRITERIA.md](docs/GRADING_CRITERIA.md) — concrete quality gates.
6. [docs/EVALUATOR.md](docs/EVALUATOR.md) — the skeptical evaluator's role.

If your task spans phases, re-read the chunk's contract in PROJECT_PLAN.md before each commit.
