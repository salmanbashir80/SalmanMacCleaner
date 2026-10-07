# Install guide — 8002CleanUp 1.2.0 (build 12)

## Short answer: this ZIP is source code, not a prebuilt app

The archive contains the **complete Xcode project** (Swift sources, tests, Xcode project,
tools, docs, helper scripts) — and **no `.app`, `.dmg` or any compiled binary**. Nothing was
compiled when this ZIP was prepared: that environment had no macOS and no Xcode/Swift
toolchain (`xcodebuild`, `swift`, `swiftc` are absent; OS was Debian 12 x86_64). A macOS
application can only be compiled and code-signed on macOS.

So: **unzip → build once on your Mac (one command) → launch.** The build takes a few minutes.
What *has* been proven about this source is in `RESTORE_REPORT.md`: GitHub's macOS-14 runner
compiled it, ran the XCTest suite and built both Debug and Release successfully (run
37675648454); it has **not** been launched or installed anywhere.

---

## 1. Requirements

| Item | Requirement | Why |
| --- | --- | --- |
| Mac | macOS **13.0 (Ventura) or newer** | `MACOSX_DEPLOYMENT_TARGET = 13.0` |
| Xcode | **Xcode 15 or newer** (CI verified with 15.2) | Swift 5.9 language mode, SwiftUI APIs |
| Architecture | Apple Silicon **or** Intel | `ARCHS` is not pinned: you get a build for the Mac you build on |
| Disk | ~2–3 GB free | Derived data + build products |
| Network | Internet for the **first** build only | Xcode resolves the Sparkle 2 Swift package from GitHub |
| Optional | Python 3 | Only for the no-Xcode validation scripts in `Tools/` |

Full Disk Access is **not** required to build or launch; it is required for deep scans of
`~/Library` and other protected locations, and you grant it yourself (step 5).

---

## 2. Build and install (recommended path)

```bash
cd /where/you/unzipped/8002CleanUp-1.2.0-build12

# 0) optional, no Xcode needed — structural sanity check
python3 Tools/validate_project.py          # expect: PASSED — all checks passed (0 warnings)

# 1) build Release, verify the bundle, package it
./Scripts/build_and_verify_macos.sh
```

That script checks for `xcodebuild`, resolves the Sparkle package, builds `Release`
(ad-hoc signed, with an unsigned fallback), prints the bundle's `CFBundleDisplayName`,
`CFBundleShortVersionString`, `CFBundleVersion`, `CFBundleIdentifier`, `lipo -archs` and
`codesign --verify` result, then writes
`dist/8002CleanUp-1.2.0-build12-macos.zip` plus its SHA-256 in `dist/checksums.txt`.

```bash
# 2) install it into /Applications and clear the quarantine flag
./Scripts/build_and_verify_macos.sh --install

# 3) launch
open /Applications/SalmanMacCleaner.app
```

Run the test suite as well with `./Scripts/build_and_verify_macos.sh --test`.

### Manual equivalent (if you prefer raw Xcode commands)

```bash
xcodebuild -resolvePackageDependencies -project SalmanMacCleaner.xcodeproj -scheme SalmanMacCleaner

xcodebuild build -project SalmanMacCleaner.xcodeproj -scheme SalmanMacCleaner \
  -configuration Release -destination 'platform=macOS' -derivedDataPath build_mac \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""

APP=build_mac/Build/Products/Release/SalmanMacCleaner.app
codesign --verify --deep --strict --verbose=2 "$APP"
open "$APP"
```

Or just open `SalmanMacCleaner.xcodeproj` in Xcode, choose the **SalmanMacCleaner** scheme and
select *Product → Run* (⌘R).

---

## 3. First launch, Gatekeeper and Full Disk Access

1. **Gatekeeper.** The build is **ad-hoc signed, not notarized**, so a downloaded/zipped copy may
   be quarantined. If macOS refuses the first launch: **right-click the app → Open → Open**, or
   ```bash
   xattr -dr com.apple.quarantine /Applications/SalmanMacCleaner.app
   ```
   (The `--install` option of the script does this for you.)
2. **Identify the build.** The sidebar header/toolbar badge must read **8002CleanUp · v1.2.0 (12)**.
   The bundle file itself is named `SalmanMacCleaner.app`; **8002CleanUp** is the visible name
   (`CFBundleName`/`CFBundleDisplayName`) — both names refer to the same app.
3. **Full Disk Access** (for complete scans): System Settings → Privacy & Security → Full Disk
   Access → **+** → add `/Applications/SalmanMacCleaner.app` → toggle it on → relaunch the app.
   Without it, the app still runs; scans of protected locations are reported as *limited/denied*
   rather than silently pretending to be complete.

---

## 4. Limitations you should know about

| Area | Status | Detail |
| --- | --- | --- |
| Signing | **Ad-hoc only** | Signed with identity `-` (required so it launches on Apple Silicon). No Developer ID. |
| Notarization | **None** | Not notarized/stapled → first launch may need right-click → Open or the `xattr` command. |
| Sparkle updates | **Inactive for this build** | `Support/appcast.xml` contains no releases and the updater reports itself unconfigured; a Developer ID signed, notarized release (secrets + `Support/workflows/release.yml`) is what enables real updates. |
| Apple Silicon | Ad-hoc signature is sufficient to launch locally | Building on an Apple Silicon Mac gives an arm64 app; building on Intel gives x86_64. No universal binary is shipped (nothing prebuilt is shipped). |
| macOS version | **macOS 13.0+** | On macOS 26 the app additionally uses native Liquid Glass, `#available`-guarded. |
| iOS target | Present, separate | `SalmanCleanerMobile.xcodeproj` is a distinct iOS app; it was **not** verified in this restore. |
| Verification scope | Compile + unit tests proven on a macOS runner | Launch, install, Gatekeeper prompts and the ad-hoc signing flags in the new CI template have **not** been exercised yet. Nothing in this package was built or run by the environment that produced it. |
| Ready-made `.app` without a Mac | Possible via GitHub Actions | Push this tree (its `.github/workflows/` files are the fixed ones; `.github/workflows` requires an account/PAT with the `workflows` permission) and run the `CI` workflow — it builds, verifies and uploads the packaged `.app` as a workflow artifact. |

---

## 5. What to expect once it runs

- 20 modules in the sidebar (Smart Care, Deep Scan, System Junk, Developer Caches, Large & Old
  Files, Duplicate Finder, App Leftovers, Applications, Uninstaller, App Updater, Performance,
  Space Lens, Trash Bins, Security Audit, Permissions, Startup & Background Items, Activity &
  History, My Tools, Settings …).
- **Preview Mode ON by default**: nothing is removed until you tick items and confirm.
- Cleanup moves files to the Trash. The **Trash Bins** module is the only place that can delete
  immediately, and only for items already inside a Trash folder, after re-validating each path
  against the real Trash roots and asking for confirmation.
- "Back to Smart Care" appears inside Duplicate Finder and Startup & Background Items — if those
  buttons are absent you are looking at an old copy of the app (e.g. a stale `/Applications` entry
  from the v1.0.x releases that shipped a build of the broken `main` state).
