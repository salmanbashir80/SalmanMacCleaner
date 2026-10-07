#!/bin/bash
#
# Double-clickable DMG builder for 8002CleanUp 1.2.0 (build 12).
#
# On a Mac with Xcode installed, this builds, verifies and packages the app as a
# real .dmg, then opens the image in Finder. To install, drag 8002CleanUp.app
# onto the Applications shortcut in that mounted image. This script does not
# bypass macOS privacy controls or silently write into /Applications.
#
# Requirements: macOS 13+, Xcode 15+, and an internet connection on the first
# build so Xcode can resolve Sparkle.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

clear
cat <<'BANNER'
==================================================================
  8002CleanUp 1.2.0 (build 12) — build a verified install DMG

  This compiles the app on this Mac, verifies its ad-hoc signature,
  creates a .dmg with an Applications shortcut, and opens the image.
  To install, drag 8002CleanUp.app onto Applications in Finder.
==================================================================
BANNER
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
  cat <<'NOXCODE'
Xcode is not installed (xcodebuild was not found).

Install Xcode from the Mac App Store, open it once to accept the licence, then
point the developer directory at it:

    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

After that, double-click this file again.
NOXCODE
  echo
  read -r -p "Press Return to close…" _
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  cat <<'NOPYTHON'
Python 3 was not found. The build's structural validation and bundle-symlink
checks require python3. Install Python 3 (for example from python.org or
Homebrew), then double-click this file again.
NOPYTHON
  echo
  read -r -p "Press Return to close…" _
  exit 1
fi

xcodebuild -version
sw_vers
echo

echo "Starting the Release build, DMG packaging, bundle checks, and launch smoke test…"
echo

if ./Scripts/build_and_package_dmg.sh --open-dmg; then
  cat <<'DONE'

==================================================================
  The DMG was created in dist/ and opened in Finder.

  Install:
   1. Drag 8002CleanUp.app onto the Applications shortcut.
   2. Eject the mounted 8002CleanUp volume.
   3. Open /Applications/8002CleanUp.app.
   4. If macOS blocks the first launch: right-click → Open → Open.
   5. For complete scans, grant Full Disk Access in System Settings.
==================================================================
DONE
else
  cat <<'FAILED'

==================================================================
  The build/package/verification failed. Scroll up for the error.

  Common causes:
   - Xcode is not selected: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   - The first Swift Package resolution cannot reach the network (Sparkle).
   - A valid ad-hoc signature could not be produced.
   - The app could not launch on this Mac or the DMG could not be mounted.
==================================================================
FAILED
fi

echo
read -r -p "Press Return to close this window…" _
