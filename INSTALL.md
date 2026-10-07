# Install 8002CleanUp 1.2.0 (build 12)

## Which download is the app?

- The **restored-source ZIP** is source code and the complete Xcode project; it contains no `.app`, `.dmg`, or compiled executable.
- The **DMG workflow artifact** is the intended installable build. It contains `8002CleanUp.app` and an `Applications` shortcut. GitHub may download a workflow artifact as a ZIP wrapper; inside that wrapper is the actual `.dmg`, not another source archive.
- **This checkout does not currently contain a generated DMG.** Creating one requires a macOS runner (for `xcodebuild`, `codesign`, `hdiutil`, and a real launch check). The Agent Mode host for this restoration is Debian 12 x86_64 and has no Xcode or Swift toolchain. The new macOS 14/macOS 27 CI template is at `Support/workflows/ci.yml`; the repository's active `.github/workflows/ci.yml` must be replaced by a maintainer with GitHub `workflows` permission before that DMG job can run.

The final artifact name is generated from the app's built plist, currently expected to be:

```text
8002CleanUp-1.2.0-build12-macos-arm64.dmg
8002CleanUp-1.2.0-build12-macos-arm64.dmg.sha256
```

Do not treat the existing `v1.0.6` or `v1.0.13` release ZIPs as this DMG; those are old, mis-tagged artifacts from the broken `main` history (see `RESTORE_REPORT.md`).

---

## 1. Activate and run the DMG CI

A repository maintainer with permission to write GitHub Actions workflow files must activate the restored workflow template. From the restored branch:

```bash
./Scripts/activate_workflows.sh
git diff -- .github/workflows
```

Review the workflow diff. Then commit the workflow activation on the restored branch (or merge it through the existing pull request) using an identity with GitHub's `workflows` permission. The helper does not push or publish a release by itself.

The CI workflow then runs:

- macOS 14 with Xcode 15: unit tests, Debug build, and Release build;
- GitHub's `xcode-27` preview runner on macOS 27 / arm64 with Xcode 27: validation, tests, Debug build, ad-hoc signed Release build, DMG creation, image verification, install-copy verification, and app launch smoke test.

On a successful run, open **GitHub → Actions → CI → the completed run → Artifacts** and download `8002CleanUp-1.2.0-build12-macos27-arm64-dmg`. Extract GitHub's artifact wrapper ZIP to get the `.dmg` and adjacent `.sha256` file. The workflow intentionally creates no GitHub Release and does not package the app with `zip -r`.

The Xcode 27 runner is marked preview by GitHub. The workflow fails rather than silently substituting another OS/toolchain if the runner is not macOS 27, Xcode 27, and arm64.

---

## 2. Install from the DMG

1. In Finder, double-click the downloaded `.dmg`.
2. In the mounted window, drag **`8002CleanUp.app`** onto the **Applications** shortcut.
3. Eject the mounted `8002CleanUp` volume in Finder.
4. Open `/Applications/8002CleanUp.app`.
5. Because this build is ad-hoc signed and **not notarized**, macOS may block the first launch. If so, Control-click/right-click the app, choose **Open**, then choose **Open** again in the confirmation dialog. This is the preferred first-launch approval. If necessary, remove the download quarantine attribute explicitly:

   ```bash
   xattr -dr com.apple.quarantine /Applications/8002CleanUp.app
   open /Applications/8002CleanUp.app
   ```

6. For complete scans, add `/Applications/8002CleanUp.app` under **System Settings → Privacy & Security → Full Disk Access**, enable it, and relaunch. Full Disk Access is optional for launch and is granted by the user; without it, protected locations are reported as limited/denied.

The app's bundle identifier remains `com.salman.SalmanMacCleaner`; the user-visible app and DMG name is `8002CleanUp`. The app's internal executable/target is still `SalmanMacCleaner`.

### Verify the download checksum

From the directory containing both downloaded files:

```bash
shasum -a 256 -c 8002CleanUp-1.2.0-build12-macos-arm64.dmg.sha256
```

The checksum file is generated from the DMG produced by CI; do not reuse a checksum from a different build or commit.

---

## 3. Build a DMG locally on a Mac

Requirements: macOS 13+, Xcode 15+, Python 3, and network access for the first Swift Package Manager resolution (Sparkle).

```bash
# From the repository root
./Scripts/build_and_package_dmg.sh

# Optionally run XCTest before building/package verification
./Scripts/build_and_package_dmg.sh --test
```

The script uses a fresh DerivedData directory, requires a valid ad-hoc code signature (no unsigned fallback), verifies the app plist/resources/architecture and internal symlinks, copies the bundle with `ditto`, creates a compressed read-only DMG with `hdiutil`, checks that the DMG contains the app plus the `/Applications` symlink, checks the install-copy signature, launches that copied app, then writes a SHA-256 sidecar in `dist/`.

By default, the local build targets the current Mac's architecture. Set `APP_ARCH=arm64` to explicitly produce an Apple Silicon build. The CI distribution DMG is arm64. It is not a universal Intel/Apple-Silicon binary.

---

## 4. Supported OS and what verification means

`MACOSX_DEPLOYMENT_TARGET` and `LSMinimumSystemVersion` are set to **13.0**. The CI workflow checks the built plist and runs on macOS 14 and macOS 27; the macOS 27 job launches the copied app from its temporary install location. There is no macOS 13 hosted runtime job in the configured matrix, so actual execution on macOS 13 remains unverified until tested on a Ventura Mac.

The macOS 27 job checks bundle integrity, valid ad-hoc signing, the mounted DMG layout and application launch. It cannot test a user's downloaded-file quarantine dialog, notarization/Gatekeeper acceptance, Full Disk Access consent, every hardware configuration, or all app features against live user data. Developer ID signing/notarization is not included; the ad-hoc DMG requires the first-launch approval described above.
