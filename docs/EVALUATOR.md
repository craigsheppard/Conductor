# The Evaluator

> The evaluator is **separated** from the author. Either a different agent, a different person, or — at minimum — the same agent in a clean session with no memory of the implementation conversation. Modeled on EA-270 (separated QA evaluator, sprint contracts, concrete grading, anti-self-praise).

---

## Role

The evaluator's job is to **disprove** the author's claims, not to confirm them.

They start from skepticism: every assertion in the PR description is a hypothesis until verified. Their output is a **graded report** against the sprint contract and [GRADING_CRITERIA.md](GRADING_CRITERIA.md), citing artifacts for every PASS and explaining every FAIL.

They are not collegial. They are not encouraging. They are **adversarial in the right way**: they want the harness to catch problems before main does.

---

## Inputs

When the evaluator opens a PR for review, they need:

1. The PR's **sprint contract** (in PROJECT_PLAN.md or `docs/sprints/<chunk>.md`).
2. The PR's description.
3. A clean checkout of the PR branch on a fresh worktree (no prior local state).
4. Read-only access to `~/.claude/projects/` if the chunk involves real-session integration. (Phase 0+ chunks may need this; document the snapshot used.)

---

## Procedure

### Step 1 — Read the contract

Quote the contract's **goal** and **functional checks** in the report. The evaluator's job is to verify these and only these. Out-of-scope items are noted but not graded.

### Step 2 — Reproduce the build

```bash
git checkout <pr-branch>
./scripts/install-hooks.sh   # confirm idempotency on a fresh clone
./scripts/blt-cp             # full pipeline
```

Paste the **exact output** of `blt-cp`. If any step fails, the criterion fails — stop and FAIL the report.

### Step 3 — Run the named tests in isolation

For each functional check listed in the contract, run that test by name:

```bash
swift test --filter ConductorTests.JSONLStoreTests/testParsesValidSession
```

Paste the output. If the test doesn't exist, FAIL. If the test exists but is `XCTSkip`-ped, FAIL. If the test exists but doesn't actually exercise the claimed behavior (asserts trivial things, or asserts the wrong invariant), FAIL.

### Step 4 — Run the app or the script

Phase 0 chunks: run `inspect_claude_sessions.sh` and paste its output, side-by-side with the contract's expected fields.

Phase 1+ chunks: launch Conductor with `swift run conductor` (or, when a real GUI ships, open the .app). For each user-visible behavior in the contract, **drive the path** and capture the observed result:

- Take a screenshot, paste the path.
- For data flows, paste the SQL or `cat` output of the affected file.
- For background work, paste the relevant log lines.

### Step 5 — Inspect side effects

For each side effect the contract claims, verify directly:

- "Writes a row to `notes`" → open the SQLite DB, run `SELECT * FROM notes WHERE …`, paste result.
- "Sends a `SessionStart` hook event" → tail the hook log; paste matching line.
- "Renames the session via `/rename`" → on a throwaway session, observe the JSONL/sidecar diff before & after, paste the diff.

### Step 6 — Reproduce any "fixed bug" claim

If the PR claims to fix a bug:

1. Check out the parent commit. Reproduce the failure. Paste the failure output.
2. Check out HEAD of the PR branch. Run the same path. Paste the now-passing output.

If you can't reproduce the original failure on the parent, the bug claim is FAIL — there's nothing to confirm fixed.

### Step 7 — Cross-check description vs. reality

For each statement in the PR description, the evaluator answers one of:

- **Verified** — cite the artifact that confirms it (test output, screenshot, SQL row).
- **Out of scope** — note that this is in the contract's "Out of scope" section.
- **Unsupported** — no artifact found. **This is a FAIL.**

### Step 8 — Grade the criteria

Run through [GRADING_CRITERIA.md](GRADING_CRITERIA.md) section by section. For each criterion:

```
N. <criterion name>
   - Command:  <exact command run>
   - Output:   <paste, or "see CI run #1234">
   - Verdict:  PASS | FAIL
   - Notes:    <any caveats, or empty>
```

### Step 9 — Verdict

```
## Verdict: PASS | FAIL

- Total criteria: <N>
- PASS: <P>
- FAIL: <F>

If FAIL, the author must address each FAIL before re-review.
If PASS, the author may merge.
```

---

## Anti-self-praise rules (for evaluator output)

The evaluator must **never** use:

- "Looks good." "Works as expected." "All tests pass." (without naming them and pasting output)
- "Comprehensive." "Robust." "Production-ready." (vague signal)
- "I think this should…" — the evaluator does not opine; they verify.
- "Tested manually." (without describing what was driven and observed)

The evaluator **must always** include:

- The exact command run for each verification.
- The output (or a path to where it can be inspected — CI run, log file).
- The pass/fail verdict, attached to a criterion.
- Any artifact paths (screenshots, log files) committed to the PR's `evaluator-artifacts/` folder if substantial.

A report that reads like a victory lap is a FAIL — the evaluator sends it back.

---

## When the evaluator and author disagree

The evaluator's verdict stands. If the author thinks a FAIL is wrong:

1. The author **does not change** the verdict.
2. The author addresses the FAIL — by fixing the code, fixing the contract, or filing a follow-up if it's truly out of scope.
3. The evaluator re-grades at the next push.

If the author and evaluator disagree on the contract itself, **update the contract first** as a docs PR, then re-implement. The contract is the seam.

---

## Self-evaluation (single-author mode)

When there's no separate evaluator (initial bootstrap, solo work, etc.):

1. **Open a fresh shell.** Don't trust your own working state.
2. **Use a different worktree** so you can't accidentally amend the PR while evaluating.
3. **Run the procedure as written above.** Paste outputs into a self-evaluation report committed to `docs/evaluations/<branch>.md`.
4. **Wait at least an hour** between writing the code and evaluating it. Recency bias is the most common cause of false-positive PASS.

Self-evaluation is weaker than separated evaluation. Use it only when separated evaluation isn't available, and prefer to upgrade to separated evaluation as soon as the workflow allows it.

---

## Tooling

The evaluator may invoke any tool the harness supports:

- `swift build`, `swift test`, `swift run`
- `xcrun swift-format`, `swiftlint`
- `sqlite3` for overlay DB inspection
- `osascript` for AppleScript bridge inspection
- `/usr/bin/log show` and `/usr/bin/log stream` for app logs
- `xcrun llvm-cov` for coverage reports
- `gh pr view`, `gh pr diff`, `gh run view` for CI artifacts

The evaluator does **not** modify code. If a fix is obvious, they note it in the FAIL; the author makes the change.
