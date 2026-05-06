# Grading Criteria

Concrete, repo-specific quality gates. Distinct from the **per-chunk** functional checks (which live in the sprint contract). These criteria apply to **every** chunk.

The evaluator agent grades each PR against this list and produces a PASS/FAIL verdict per criterion. Any FAIL blocks merge.

---

## 1. Build

| Criterion | Check | Threshold |
|---|---|---|
| Build clean | `swift build -Xswiftc -warnings-as-errors` | exit 0, zero warnings |
| Tests build | `swift test --skip-build false` reaches the test phase | exit 0 on the build phase |

## 2. Lint / Format

| Criterion | Check | Threshold |
|---|---|---|
| SwiftLint strict | `swiftlint lint --strict --quiet` | exit 0, zero violations |
| swift-format strict | `xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests` | exit 0 |
| No force-unwrap | SwiftLint `force_unwrapping` rule | error severity |
| No force-try | SwiftLint `force_try` rule | error severity |
| No force-cast | SwiftLint `force_cast` rule | error severity |

## 3. Tests

| Criterion | Check | Threshold |
|---|---|---|
| All tests pass | `swift test --parallel` | exit 0 |
| No skipped tests | `grep -RIn 'XCTSkip' Tests` returns only justified skips with a linked issue | one of: zero matches, or every match has a comment citing an issue |
| New code covered | `xcrun llvm-cov` on `swift test --enable-code-coverage` for files in the diff | new lines ≥ 80% covered |
| Overall coverage doesn't drop | Compared to base branch | non-decreasing (ratchet) |

## 4. Code shape

| Criterion | Check | Threshold |
|---|---|---|
| File size | SwiftLint `file_length` | ≤400 LOC warn, ≤600 LOC error |
| Function size | SwiftLint `function_body_length` | ≤50 LOC warn, ≤80 LOC error |
| Type size | SwiftLint `type_body_length` | ≤250 LOC warn, ≤400 LOC error |
| Cyclomatic complexity | SwiftLint `cyclomatic_complexity` | ≤10 |
| Line length | SwiftLint `line_length` | ≤120 |

## 5. Architecture

| Criterion | Check | Threshold |
|---|---|---|
| Domain has no I/O | Architecture test (Phase 1+): `Sources/Conductor/Domain/**/*.swift` does not import `FileManager`, `Process`, `SQLite`, `GRDB`, `AppKit`, `OSAKit` | zero violations |
| One direction of flow | Architecture test (Phase 1+): `Sources/Conductor/Stores/` does not import `Repository/` or `Views/`; `Views/` does not import `Stores/` | zero violations |
| Public API documented | swift-format `ValidateDocumentationComments` (enabled Phase 1+) | exit 0 |

## 6. Hygiene

| Criterion | Check | Threshold |
|---|---|---|
| No TODOs in shipped code | `grep -RIn 'TODO\|FIXME\|XXX' Sources` | zero matches, OR every match links to a filed issue |
| No commented-out code | Manual review + spot-check via `grep` for blocks of `//.*[a-zA-Z]` | zero matches |
| No dead code | SwiftLint `unused_declaration` analyzer | zero violations |
| No unused imports | SwiftLint `unused_import` analyzer | zero violations |

## 7. PR / Commit hygiene

| Criterion | Check | Threshold |
|---|---|---|
| Pre-commit hook installed | `./scripts/verify-hooks.sh` on the author's machine | exit 0 |
| BLT-CP locally green | Author pastes BLT-CP output in PR description | output shown, ends in "BLT-CP PASSED" |
| CI green | GitHub Actions on the latest commit of the PR branch | all required jobs green |
| PR description matches reality | Evaluator cross-check | every claim corresponds to an artifact |
| Sprint contract present | PR description quotes or links the contract | contract present and complete |
| Follow-ups filed | Discovered issues listed in PR description | each one has an entry in PROJECT_PLAN.md or an issue |

## 8. Process

| Criterion | Check | Threshold |
|---|---|---|
| Branch is feature branch (not main) | `git rev-parse --abbrev-ref HEAD` ≠ `main` | true (except initial scaffold) |
| No `--no-verify` commits | `git log --format='%B' base..HEAD` does not contain `--no-verify` justification absent | zero |
| No force-pushes to main | git reflog inspection | zero |

---

## How the evaluator reports

For each criterion, the evaluator records:

```
1. Build clean
   - Command:  swift build -Xswiftc -warnings-as-errors
   - Output:   Build complete! (0.42s)
   - Warnings: 0
   - Verdict:  PASS
```

A PASS without a cited command output is itself a FAIL of the anti-self-praise rule. If the evaluator can't produce the artifact, the criterion is FAIL by default.
