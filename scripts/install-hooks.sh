#!/usr/bin/env bash
# install-hooks.sh — Install the Conductor pre-commit hook.
# Idempotent: safe to run on every clone, every checkout.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_PATH="${REPO_ROOT}/.git/hooks/pre-commit"

cat > "${HOOK_PATH}" <<'HOOK'
#!/usr/bin/env bash
# conductor-blt-cp-hook — pre-commit gate.
# DO NOT REMOVE THE MARKER ABOVE — verify-hooks.sh greps for it.
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
exec "${REPO_ROOT}/scripts/blt-cp"
HOOK

chmod +x "${HOOK_PATH}"

echo "✅ Installed pre-commit hook at ${HOOK_PATH}"
echo "   The hook runs scripts/blt-cp before every commit."
echo "   Bypass intentionally with --no-verify only if you know why."
