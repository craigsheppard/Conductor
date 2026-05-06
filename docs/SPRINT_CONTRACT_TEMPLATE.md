# Sprint Contract Template

> **Copy this template into PROJECT_PLAN.md (under the relevant phase) or into `docs/sprints/<phase-N-short-name>.md`.** Fill it in *before* writing any code. The contract is the source of truth for "done."

---

## Chunk: `<phase-N: short name>`

**Goal** *(one sentence the reader can hold in their head — "what observable thing exists when this lands")*

>

**Owner** *(branch name, agent or human author)*

>

**Estimated effort** *(rough — hours, weekend, etc.)*

>

---

### In scope

- Bullet list of concrete deliverables.
- Each bullet is something a reviewer can point at and say "yes, that exists" or "no, that doesn't."

### Explicitly out of scope

- What this chunk does *not* deliver, especially adjacent things a reader might assume are included.
- Each out-of-scope item that's still on the roadmap gets a follow-up entry below.

### Follow-ups (out-of-scope but tracked)

- `[ ]` Item — owner — phase or "backlog"
- `[ ]` Item — owner — phase or "backlog"

---

### Functional checks

> Tests that prove the feature works. Listed by name *before* implementation. The evaluator runs these and confirms they pass at HEAD on the merge commit.

XCTest cases (path — case name — what it asserts):

- `Tests/ConductorTests/JSONLStoreTests.swift` — `testParsesValidSession()` — given a real-world session JSONL, parses without error and returns a `RawSession` with the expected uuid/cwd/messageCount.
- `…`

UI / snapshot tests (where applicable):

- `Tests/ConductorTests/Views/DashboardSnapshotTests.swift` — `testEmptyState()` — empty state renders with "No sessions" and the bootstrap prompt.
- `…`

Integration / system tests (touching real `~/.claude/` fixtures):

- `…`

---

### Quality gates

> Run by `scripts/blt-cp` and CI. Failures block merge.

- `swift build -Xswiftc -warnings-as-errors` — clean.
- `xcrun swift-format lint --strict` — clean.
- `swiftlint --strict --quiet` — zero errors, zero warnings.
- `swift test --parallel` — all tests pass, including those listed above.
- **Code coverage** — overall ≥ `<N>`%; new lines added in this chunk ≥ `<M>`%.
- **No TODOs in shipped code** — `grep -RIn 'TODO\|FIXME' Sources` returns nothing (or only filed-and-linked items).
- **No dead code** — `swiftlint` `unused_declaration` analyzer rule passes.
- **Public API documented** — every `public` declaration has a `///` doc comment (enforced once swift-format `ValidateDocumentationComments` is on, Phase 1+).
- **File size** — no file >300 LOC unless splitting would worsen readability; absolute hard cap 600 (SwiftLint enforces).

Per-chunk gates (add chunk-specific architectural constraints here):

- `…`

---

### Evaluator pass

> What the **separated evaluator agent** must do — concrete, runtime-grounded, skeptical. The evaluator does not trust narration; they verify.

The evaluator must:

1. **Run the app.** *(For Phase 1+: launch Conductor; for Phase 0: run the inspect script.)* Capture a screenshot or terminal-output paste.
2. **Exercise the specific paths the contract claims work.** Document each path: input → observed output. No "works as expected" — describe what was observed.
3. **Inspect side effects on disk.** If the contract says "writes a row to `notes` table", open the SQLite DB and `SELECT *`. Paste the result.
4. **Inspect logs.** If the contract says "MetaStore reads RC state", grep the runtime log for the read. Paste the matching line.
5. **Reproduce the failing case** for any "fixed bug" claim. First reproduce the original failure on the parent commit; then confirm the fix at HEAD.
6. **Re-run the functional checks** at HEAD on a clean clone. Paste the test output, including pass count.
7. **Cross-check the PR description against reality.** If the description says X, X must be observably true. Note any discrepancies.

Anti-self-praise rubric (failure conditions — any one of these is a FAIL):

- ❌ Claim made without an artifact (test name, screenshot, log line, SQL row, file path).
- ❌ "Works as expected" / "looks good" / "comprehensive" used in lieu of evidence.
- ❌ Functional check listed but not actually present in `Tests/`.
- ❌ Functional check present but skipped, disabled, or marked `XCTSkip`.
- ❌ Test added that doesn't exercise the claimed behavior (asserts only `true == true`, or asserts the wrong thing).
- ❌ Coverage claim unverified (no `xcrun llvm-cov` output cited).
- ❌ "All tests pass" claim without the actual test count and runtime cited.
- ❌ Behavior visible in the UI not screen-captured (snapshot test or recording).
- ❌ Discovered issues not filed as follow-ups.

---

### Sign-off

- `[ ]` Author has run `scripts/blt-cp` locally; pasted output into the PR description.
- `[ ]` Evaluator agent has produced a graded report; report verdict is PASS; report attached to PR.
- `[ ]` PR description quotes the goal and lists each functional check with its result.
- `[ ]` PR description's "Out of scope" section matches this contract's; follow-ups filed.
- `[ ]` No TODOs, no commented-out code, no dead imports.
- `[ ]` Force-push to feature branch happened only before opening the PR (or never).

When all six are checked, merge.
