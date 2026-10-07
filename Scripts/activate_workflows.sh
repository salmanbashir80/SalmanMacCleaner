#!/bin/bash
#
# activate_workflows.sh — copy the ready-to-use GitHub Actions workflows from
# Support/workflows/ into .github/workflows/.
#
# Why this step exists: the automation identity used to prepare this repository
# is not allowed to write files under .github/workflows/ (GitHub rejects such
# pushes with "refusing to allow a GitHub App to create or update workflow
# ... without `workflows` permission"). Everything else is pushed normally, so
# the workflows ship as templates and are activated with one command by an
# account that has the `workflows` permission.
#
#   ./Scripts/activate_workflows.sh             # CI + iOS CI + unsigned release
#   ./Scripts/activate_workflows.sh --signed    # CI + iOS CI + Developer ID release
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGNED=0
for arg in "$@"; do
  case "$arg" in
    --signed) SIGNED=1 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p .github/workflows

cp Support/workflows/ci.yml        .github/workflows/ci.yml
cp Support/workflows/ios-ci.yml    .github/workflows/ios-ci.yml

if [ "$SIGNED" = "1" ]; then
  cp Support/workflows/release.yml .github/workflows/release.yml
  echo "Release workflow: Developer ID signed + notarized (requires the six secrets in Docs/ReleaseWorkflow.md)."
else
  cp Support/workflows/release-unsigned.yml .github/workflows/release.yml
  echo "Release workflow: ad-hoc signed, no secrets required."
fi

cat <<'EOF'

Activated:
  .github/workflows/ci.yml       macOS 14 + 27 tests/builds; ad-hoc signed DMG,
                                  bundle/signature verification and launch smoke test
  .github/workflows/release.yml  publishes a release from a v* tag
  .github/workflows/ios-ci.yml   iOS target build/test

Review, then commit and push with an account that has the `workflows` permission:

  git add .github/workflows
  git commit -m "ci: activate the restored workflows"
  git push origin "$(git branch --show-current)"
EOF
