#!/bin/bash
#
# Install.command — double-clickable installer for 8002CleanUp 1.2.0 (build 12)
#
# Double-click this file in Finder (or run it in Terminal) to build the app and
# install it into /Applications. It is a thin wrapper around
# Scripts/build_and_verify_macos.sh --install, kept as a .command file so it can
# be launched from Finder without typing any command.
#
# Requirements: macOS 13+ with Xcode 15+ installed (App Store), internet for the
# first build (Xcode downloads the Sparkle 2 package).
#
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

clear
cat <<'BANNER'
==================================================================
  8002CleanUp 1.2.0 (build 12) — build & install
  Source package: this will compile the app on this Mac and copy
  it to /Applications. Nothing else on your system is modified.
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

xcodebuild -version
sw_vers
echo

echo "Starting the build. This takes a few minutes the first time…"
echo

if ./Scripts/build_and_verify_macos.sh --install; then
  cat <<'DONE'

==================================================================
  Installed: /Applications/SalmanMacCleaner.app
  Visible name: 8002CleanUp — it should open showing "v1.2.0 (12)".

  Next steps:
   1. Launch it (open /Applications/SalmanMacCleaner.app).
   2. If macOS blocks the first launch: right-click the app → Open → Open
      (this build is ad-hoc signed and not notarized).
   3. For complete scans: System Settings → Privacy & Security →
      Full Disk Access → + → add the app → toggle on → relaunch.
==================================================================
DONE
else
  cat <<'FAILED'

==================================================================
  The build failed. Scroll up for the compiler output.

  Common causes:
   - Xcode not selected: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   - No internet access for the first build (Sparkle package download).
   - Xcode too old: this project needs Xcode 15 or newer.
   - Destination: run the build with -destination 'platform=macOS'.
==================================================================
FAILED
fi

echo
read -r -p "Press Return to close this window…" _
