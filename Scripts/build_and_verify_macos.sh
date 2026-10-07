#!/usr/bin/env bash
# Compatibility shim for the old source-build helper.
#
# The old helper made a .zip of the app bundle. New builds must use the
# symlink-preserving, ad-hoc signed DMG flow instead:
#   ./Scripts/build_and_package_dmg.sh
#
# `--install` remains accepted for old instructions, but now opens the
# resulting DMG in Finder. It does not copy an app into /Applications; the user
# explicitly drags 8002CleanUp.app onto the DMG's Applications shortcut.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --install)
      echo "Note: --install is now a compatibility alias for building and opening the DMG."
      echo "Drag 8002CleanUp.app onto Applications in Finder to install it."
      ARGS+=(--open-dmg)
      ;;
    *) ARGS+=("$arg") ;;
  esac
done

exec "$SCRIPT_DIR/build_and_package_dmg.sh" "${ARGS[@]}"
