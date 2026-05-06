# Conductor

A native macOS dashboard for your Claude Code sessions. Find what's running, decide what's safe to close, recover anything in two clicks.

> This repo is **harness-engineered**. The scaffolding (sprint contracts, BLT-CP, separated evaluator, anti-self-praise) precedes the features. See [CLAUDE.md](CLAUDE.md) for the *why*, [AGENTS.md](AGENTS.md) for the *what*, and [PROJECT_PLAN.md](PROJECT_PLAN.md) for the *plan*.

## Status

Initial scaffold landed. Phase 0 (confirm + reverse-engineer) is the next chunk. See PROJECT_PLAN.md § Phase 0 for the sprint contract.

## Setup

```bash
./scripts/install-hooks.sh        # one-time per clone — installs pre-commit hook
brew install swiftlint            # required by BLT-CP
xcrun --find swift-format         # bundled with Xcode 16+ / Command Line Tools
```

## Build / test / run

```bash
swift build                       # build (use -Xswiftc -warnings-as-errors for the strict version)
swift test --parallel             # tests
swift run conductor               # run (currently prints a placeholder line; Phase 1 ships the GUI)
./scripts/blt-cp                  # full pipeline — what the pre-commit hook runs
```

## Stack

Swift 5.10+ · macOS 14+ · SwiftUI · SwiftPM · GRDB.swift (Phase 3+) · XCTest.

## Documents

- [AGENTS.md](AGENTS.md) — mandatory rules.
- [CLAUDE.md](CLAUDE.md) — context, architecture, conventions.
- [PROJECT_PLAN.md](PROJECT_PLAN.md) — phased plan with sprint contracts.
- [docs/SPRINT_CONTRACT_TEMPLATE.md](docs/SPRINT_CONTRACT_TEMPLATE.md) — the template every chunk fills in before code lands.
- [docs/GRADING_CRITERIA.md](docs/GRADING_CRITERIA.md) — concrete quality gates per PR.
- [docs/EVALUATOR.md](docs/EVALUATOR.md) — the separated evaluator's role.
