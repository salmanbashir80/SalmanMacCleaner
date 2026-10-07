#!/bin/bash
#
# build_and_verify_macos.sh — build, verify and optionally install 8002CleanUp
# on a Mac with Xcode installed.
#
#   ./Scripts/build_and_verify_macos.sh              # build + verify only
#   ./Scripts/build_and_verify_macos.sh --test       # also run the unit tests
#   ./Scripts/build_and_verify_macos.sh --install    # build + install to /Applications
#
# It never touches user data: it only builds the project, checks the produced
# bundle and (with --install) copies the .app into /Applications.

set -euo pipefail

MODE_BUILD=1
RUN_TESTS=0
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --test) RUN_TESTS=1 ;;
    --install) INSTALL=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="SalmanMacCleaner.xcodeproj"
SCHEME="SalmanMacCleaner"
DERIVED="build_mac"
APP="$DERIVED/Build/Products/Release/SalmanMacCleaner.app"

echo "==> 0. Toolchain"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild not found. Install Xcode from the App Store and run:" >&2
  echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi
xcodebuild -version
sw_vers
uname -m

echo
echo "==> 1. Structural validation (no Xcode required)"
python3 Tools/validate_project.py

echo
echo "==> 2. Resolve Swift packages (Sparkle 2)"
xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME" >/dev/null

if [ "$RUN_TESTS" = "1" ]; then
  echo
  echo "==> 3. Unit tests"
  set -o pipefail
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO | tee mac_test.log
fi

echo
echo "==> 4. Release build (ad-hoc signed so it can launch on Apple Silicon)"
set -o pipefail
if ! xcodebuild build \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination 'platform=macOS' \
      -derivedDataPath "$DERIVED" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGN_STYLE=Manual \
      DEVELOPMENT_TEAM="" 2>&1 | tee release_build.log; then
  echo "Ad-hoc signing failed; retrying unsigned."
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee release_build.log
fi

echo
echo "==> 5. Verify the built bundle"
test -d "$APP" || { echo "ERROR: $APP was not produced" >&2; exit 1; }
for key in CFBundleName CFBundleDisplayName CFBundleShortVersionString CFBundleVersion CFBundleIdentifier; do
  printf '%-28s %s\n' "$key" "$(/usr/libexec/PlistBuddy -c "Print :$key" "$APP/Contents/Info.plist")"
done
echo -n "Architecture: "; lipo -archs "$APP/Contents/MacOS/SalmanMacCleaner"
if codesign --verify --deep --strict --verbose=2 "$APP" 2>&1; then
  echo "Code signature: OK"
  codesign -dv --verbose=2 "$APP" 2>&1 | sed -n '1,6p'
else
  echo "WARNING: the app is not code-signed; macOS will require manual approval." >&2
fi
du -sh "$APP"

echo
echo "==> 6. Package (symlink-safe ditto)"
MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | sed 's/.*= *//; s/;//')
BUILD_NUMBER=$(grep -m1 'CURRENT_PROJECT_VERSION' "$PROJECT/project.pbxproj" | sed 's/.*= *//; s/;//')
NAME="8002CleanUp-${MARKETING_VERSION}-build${BUILD_NUMBER}-macos.zip"
mkdir -p dist
rm -rf "dist/SalmanMacCleaner.app"
cp -R "$APP" dist/
ditto -c -k --keepParent dist/SalmanMacCleaner.app "dist/$NAME"
(cd dist && shasum -a 256 "$NAME" | tee checksums.txt)
echo "Packaged: dist/$NAME"

if [ "$INSTALL" = "1" ]; then
  echo
  echo "==> 7. Install to /Applications"
  DEST="/Applications/SalmanMacCleaner.app"
  if [ -d "$DEST" ]; then
    echo "Removing the previous copy at $DEST"
    rm -rf "$DEST"
  fi
  cp -R "$APP" "$DEST"
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
  echo "Installed: $DEST"
  echo "The visible name in the Dock/Finder is 8002CleanUp (bundle: SalmanMacCleaner.app)."
fi

echo
echo "==> Done. Launch with: open \"$APP\"   (or open $DEST after --install)"
echo "    If macOS blocks the first launch: right-click the app → Open,"
echo "    or run: xattr -dr com.apple.quarantine \"$APP\""
