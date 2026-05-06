#!/usr/bin/env bash
# verify-hooks.sh — Ensure the Conductor pre-commit hook is installed.
# Called by blt-cp and can be run standalone.
# Exit 1 if hooks are missing (prevents silent BLT-CP bypass — see EA-209 precedent).

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "❌ ERROR: not inside a git repo." >&2
  exit 1
fi

HOOK_PATH="${REPO_ROOT}/.git/hooks/pre-commit"
EXPECTED_MARKER="conductor-blt-cp-hook"

if [[ ! -x "${HOOK_PATH}" ]]; then
  echo "" >&2
  echo "❌ ERROR: pre-commit hook is NOT installed at ${HOOK_PATH}." >&2
  echo "   Without it, 'git commit' bypasses BLT-CP." >&2
  echo "" >&2
  echo "   Fix: run ./scripts/install-hooks.sh from the repo root." >&2
  echo "" >&2
  exit 1
fi

if ! grep -q "${EXPECTED_MARKER}" "${HOOK_PATH}"; then
  echo "" >&2
  echo "❌ ERROR: pre-commit hook at ${HOOK_PATH} is not the Conductor harness hook." >&2
  echo "   (missing marker: ${EXPECTED_MARKER})" >&2
  echo "" >&2
  echo "   Fix: run ./scripts/install-hooks.sh from the repo root." >&2
  echo "" >&2
  exit 1
fi

exit 0
