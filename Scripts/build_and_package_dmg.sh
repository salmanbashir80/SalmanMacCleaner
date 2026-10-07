#!/usr/bin/env bash
# Build, verify, stage, and package 8002CleanUp as a drag-install DMG.
#
# Requirements: macOS 13+, Xcode 15+, Python 3, and network access for the
# first Swift Package Manager resolution (Sparkle).
#
#   ./Scripts/build_and_package_dmg.sh              # Release + DMG + install/launch smoke test
#   ./Scripts/build_and_package_dmg.sh --test       # also run XCTest before Release
#   ./Scripts/build_and_package_dmg.sh --open-dmg   # open the finished DMG in Finder
#   APP_ARCH=arm64 ./Scripts/build_and_package_dmg.sh
#
# The resulting dist/*.dmg contains 8002CleanUp.app and an /Applications
# symlink. It uses hdiutil (not zip), and ditto copies the app bundle without
# flattening framework symlinks or discarding macOS metadata. The build is
# ad-hoc signed; it is not Developer ID signed or notarized.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/SalmanMacCleaner.xcodeproj"
SCHEME="SalmanMacCleaner"
CONFIGURATION="Release"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
APP_ARCH="${APP_ARCH:-$(uname -m)}"
RUN_TESTS=0
OPEN_DMG=0

usage() {
  sed -n '2,20p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --test) RUN_TESTS=1 ;;
    --open-dmg) OPEN_DMG=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "DMG creation requires macOS (hdiutil and codesign are not available here)."
[[ -d "$PROJECT" ]] || fail "Xcode project not found: $PROJECT"
case "$APP_ARCH" in
  arm64|x86_64) ;;
  *) fail "Unsupported APP_ARCH '$APP_ARCH' (use arm64 or x86_64)." ;;
esac
HOST_ARCH="$(uname -m)"
[[ "$APP_ARCH" == "$HOST_ARCH" ]] || fail "Launch verification requires a native build (host: $HOST_ARCH, requested: $APP_ARCH)."

for tool in xcodebuild hdiutil ditto codesign lipo shasum python3; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool not found: $tool"
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/8002CleanUp-dmg.XXXXXX")"
MOUNT_DIR="$WORK_DIR/mounted-dmg"
INSTALL_ROOT="$WORK_DIR/install/Applications"
INSTALL_APP="$INSTALL_ROOT/8002CleanUp.app"
MOUNTED=0
LAUNCH_PID=""

cleanup() {
  if [[ -n "$LAUNCH_PID" ]]; then
    kill -TERM "$LAUNCH_PID" >/dev/null 2>&1 || true
  fi
  if [[ "$MOUNTED" == "1" ]]; then
    hdiutil detach -quiet "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}

verify_app_bundle() {
  local app="$1"
  local info="$app/Contents/Info.plist"
  local display_name bundle_id minimum_os executable executable_path arches

  [[ -d "$app" ]] || fail "Missing app bundle: $app"
  [[ -f "$info" ]] || fail "Missing Contents/Info.plist in $app"
  /usr/bin/plutil -lint "$info" >/dev/null || fail "Invalid Info.plist: $info"

  display_name="$(plist_value CFBundleDisplayName "$info")"
  bundle_id="$(plist_value CFBundleIdentifier "$info")"
  minimum_os="$(plist_value LSMinimumSystemVersion "$info")"
  executable="$(plist_value CFBundleExecutable "$info")"
  executable_path="$app/Contents/MacOS/$executable"

  [[ "$display_name" == "8002CleanUp" ]] || fail "Unexpected display name: $display_name"
  [[ "$bundle_id" == "com.salman.SalmanMacCleaner" ]] || fail "Unexpected bundle id: $bundle_id"
  [[ "$minimum_os" == "13.0" ]] || fail "Expected macOS minimum 13.0, got $minimum_os"
  [[ -x "$executable_path" ]] || fail "Missing executable: $executable_path"
  [[ -d "$app/Contents/Resources" ]] || fail "Missing app resources directory"
  [[ -n "$(find "$app/Contents/Resources" -type f -print -quit)" ]] || fail "App Resources directory is empty"

  arches="$(/usr/bin/lipo -archs "$executable_path")"
  case " $arches " in
    *" $APP_ARCH "*) ;;
    *) fail "Expected $APP_ARCH executable slice, found: $arches" ;;
  esac

  # A framework bundle commonly uses relative symlinks (for example,
  # Versions/Current). They must remain intact and resolve inside the app.
  python3 - "$app" <<'PY'
import os
import sys

root = sys.argv[1]
broken = []
for current, directories, files in os.walk(root, followlinks=False):
    for name in directories + files:
        path = os.path.join(current, name)
        if os.path.islink(path) and not os.path.exists(path):
            broken.append(os.path.relpath(path, root))
if broken:
    print("Broken symlinks inside app bundle:", file=sys.stderr)
    for item in broken:
        print("  " + item, file=sys.stderr)
    sys.exit(1)
print("App-bundle symlinks: all resolve")
PY

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app" \
    || fail "codesign verification failed for $app"
  /usr/bin/codesign --display --verbose=4 "$app" >"$WORK_DIR/codesign.txt" 2>&1 \
    || fail "Could not read code-signature details for $app"
  /usr/bin/grep -q '^Signature=adhoc$' "$WORK_DIR/codesign.txt" \
    || fail "Expected an ad-hoc signature (Signature=adhoc)"

  echo "Verified bundle: $app"
  echo "  Name:        $display_name"
  echo "  Bundle ID:   $bundle_id"
  echo "  Minimum OS:  $minimum_os"
  echo "  Executable:  $executable"
  echo "  Architectures: $arches"
  echo "  Signature:   ad-hoc (valid; not Developer ID/notarized)"
}

echo "==> Host and toolchain"
sw_vers
uname -m
xcodebuild -version

if [[ "$RUN_TESTS" == "1" ]]; then
  echo "==> XCTest"
  set -o pipefail
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    ARCHS="$APP_ARCH" \
    CODE_SIGNING_ALLOWED=NO
fi

echo "==> Structural project validation"
python3 "$ROOT/Tools/validate_project.py"

echo "==> Resolve Swift packages"
xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME"

# Use a fresh DerivedData directory so a previous build cannot leak stale files
# into the DMG. No unsigned fallback: this deliverable must have a verified
# ad-hoc signature.
echo "==> Build Release ($APP_ARCH, ad-hoc signed)"
set -o pipefail
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK_DIR/DerivedData" \
  ARCHS="$APP_ARCH" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=""

BUILT_APP="$WORK_DIR/DerivedData/Build/Products/$CONFIGURATION/SalmanMacCleaner.app"
verify_app_bundle "$BUILT_APP"

INFO="$BUILT_APP/Contents/Info.plist"
VERSION="$(plist_value CFBundleShortVersionString "$INFO")"
BUILD_NUMBER="$(plist_value CFBundleVersion "$INFO")"
DMG_BASENAME="8002CleanUp-${VERSION}-build${BUILD_NUMBER}-macos-${APP_ARCH}.dmg"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "dmg_basename=$DMG_BASENAME" >> "$GITHUB_OUTPUT"
  echo "artifact_name=8002CleanUp-${VERSION}-build${BUILD_NUMBER}-macos-${APP_ARCH}-dmg" >> "$GITHUB_OUTPUT"
fi
DMG_PATH="$OUTPUT_DIR/$DMG_BASENAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
DMG_ROOT="$WORK_DIR/dmg-root"
mkdir -p "$DMG_ROOT" "$MOUNT_DIR" "$INSTALL_ROOT"

# ditto preserves bundle metadata and framework symlinks; never use cp -R or
# zip -r for a signed .app bundle.
echo "==> Stage the app and Applications shortcut"
/usr/bin/ditto "$BUILT_APP" "$DMG_ROOT/8002CleanUp.app"
ln -s /Applications "$DMG_ROOT/Applications"
verify_app_bundle "$DMG_ROOT/8002CleanUp.app"

rm -f "$DMG_PATH" "$CHECKSUM_PATH"
echo "==> Create compressed, read-only DMG"
/usr/bin/hdiutil create \
  -quiet \
  -volname "8002CleanUp" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"

# Mount the actual output and check the two Finder-visible entries, the
# Applications alias, signature integrity after packaging, and copy/install.
echo "==> Verify the mounted DMG and install-copy path"
/usr/bin/hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG_PATH"
MOUNTED=1
[[ -d "$MOUNT_DIR/8002CleanUp.app" ]] || fail "DMG is missing 8002CleanUp.app"
[[ -L "$MOUNT_DIR/Applications" ]] || fail "DMG is missing the Applications shortcut"
[[ "$(readlink "$MOUNT_DIR/Applications")" == "/Applications" ]] \
  || fail "Applications shortcut does not point to /Applications"
verify_app_bundle "$MOUNT_DIR/8002CleanUp.app"
/usr/bin/ditto "$MOUNT_DIR/8002CleanUp.app" "$INSTALL_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$INSTALL_APP" \
  || fail "Signature did not survive the install copy"
/usr/bin/hdiutil detach -quiet "$MOUNT_DIR"
MOUNTED=0

# Launch the copied app bundle, not a source tree or a symlink. This is a
# smoke-test only; it does not exercise Gatekeeper, TCC consent, or every UI.
echo "==> Launch smoke test from the installed copy"
/usr/bin/open -n "$INSTALL_APP"
EXECUTABLE="$(plist_value CFBundleExecutable "$INSTALL_APP/Contents/Info.plist")"
SHORT_EXECUTABLE="${EXECUTABLE:0:15}"
for _ in $(seq 1 30); do
  LAUNCH_PID="$(/usr/bin/pgrep -x "$EXECUTABLE" 2>/dev/null | /usr/bin/head -n 1 || true)"
  if [[ -z "$LAUNCH_PID" && "$SHORT_EXECUTABLE" != "$EXECUTABLE" ]]; then
    LAUNCH_PID="$(/usr/bin/pgrep -x "$SHORT_EXECUTABLE" 2>/dev/null | /usr/bin/head -n 1 || true)"
  fi
  [[ -n "$LAUNCH_PID" ]] && break
  sleep 1
done
[[ -n "$LAUNCH_PID" ]] || fail "App did not remain running after open"
echo "App launched successfully (PID $LAUNCH_PID); stopping the CI smoke-test process."
kill -TERM "$LAUNCH_PID" >/dev/null 2>&1 || true
for _ in $(seq 1 10); do
  if ! kill -0 "$LAUNCH_PID" >/dev/null 2>&1; then
    LAUNCH_PID=""
    break
  fi
  sleep 1
done
if [[ -n "$LAUNCH_PID" ]]; then
  kill -KILL "$LAUNCH_PID" >/dev/null 2>&1 || true
  LAUNCH_PID=""
fi

# SHA-256 contains a relative filename so the checksum can be checked from the
# downloaded artifact directory with `shasum -a 256 -c <file>.sha256`.
echo "==> Write checksum"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$DMG_BASENAME" > "$DMG_BASENAME.sha256"
  cat "$DMG_BASENAME.sha256"
)

echo "==> Complete"
ls -lh "$DMG_PATH" "$CHECKSUM_PATH"
echo "DMG:      $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
echo "Install: mount the DMG, drag 8002CleanUp.app onto Applications, then eject."
if [[ "$OPEN_DMG" == "1" ]]; then
  echo "Opening the DMG in Finder; installation still requires dragging the app onto Applications."
  /usr/bin/open "$DMG_PATH"
fi
