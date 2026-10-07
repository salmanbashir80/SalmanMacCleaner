# 8002CleanUp

A premium, privacy-respecting native macOS maintenance application built with
SwiftUI. 8002CleanUp finds junk, large files, duplicates, developer
caches, leftovers and more — and it does so **preview-first**: nothing is ever
removed automatically, and every removal goes to the Trash (never permanent).

> **macOS 13+ · Swift 5.9 · Apple Silicon (arm64) · Xcode 15+ / Xcode 26 ready**

---

## Aurora Glass interface

- Immersive full-window midnight/indigo/violet gradient with subtle animated
  aurora glow (static illumination under Reduce Motion)
- Premium glass sidebar: MAIN / CLEANUP / STORAGE / APPLICATIONS / HEALTH /
  OTHER — 20 modules with original Canvas artwork, capsule selection and
  distinct hover/pressed/keyboard-focus states
- Hero screen per module: artwork, benefit, three capabilities, scope and
  scan-mode selectors, one anchored primary action
- Native Liquid Glass via `glassEffect` on macOS 26 (`#available` guarded,
  `#if compiler(>=6.2)`), `.ultraThinMaterial` fallback on macOS 13–15
- Accessibility first: Reduce Motion, Reduce Transparency, Increase Contrast,
  VoiceOver labels, Full Keyboard Access, light/dark behavior

## Modules

| Group | Modules |
| --- | --- |
| MAIN | **Smart Care** · **Deep Scan** |
| CLEANUP | **System Junk** · **Trash Bins** · **App Leftovers** · **Developer Caches** |
| STORAGE | **Space Lens** · **Large & Old Files** · **Duplicates** · **My Clutter** |
| APPLICATIONS | **Applications** · **Uninstaller** · **App Updater** · **Startup & Background Items** |
| HEALTH | **Performance** · **Security Audit** · **Permissions** |
| OTHER | **My Tools** · **Activity & History** · **Settings** |

Unavailable features (e.g. third-party app update inventory, Trash emptying,
startup-item modification) are shown with a technically accurate reason —
never faked.

## Scan modes

- **Quick Scan** — high-value junk locations, leftovers and dev caches; no
  broad personal-folder traversal; cached inventory where valid.
- **Balanced Scan** — Quick plus user-Library metadata traversal, app
  inventory, old installers, startup inventory and duplicate pre-grouping.
- **Deep Scan** — the deepest honest scan macOS allows: full accessible
  inventory with hidden files on selected volumes (startup volume by
  default; external/network/cloud volumes require explicit opt-in), apps,
  leftovers, staged duplicate hashing and a storage map. 13 real phases,
  pause/resume/cancel, thermal-pressure auto-pause, honest coverage report.

  **Root grant model:** the user home and user-Library cache/log roots are
  always granted; volume roots (`/`, external drives) are granted only when
  Full Disk Access is plausibly available (or the user explicitly opts in);
  `NSOpenPanel` + security-scoped bookmarks let the user authorize Desktop,
  Documents, Downloads and external folders ("Choose folders for Deep
  Scan"). Roots that are not granted are listed in the coverage report with
  the exact reason and the summary shows **Limited coverage** — the app
  never claims "complete" without genuinely traversing the roots.
- **Custom Scan** — volumes, folders, categories, hidden files, package
  contents, hashing, minimum size/age, inventory-only mode.

## Deep scan architecture

`SalmanMacCleaner/Engine/` — reusable, production-grade components:

- `DeepScanCoordinator` (13 phases, `AsyncStream` events, generation tokens)
- `VolumeDiscoveryService` (statfs-based, network/cloud/Time Machine opt-in)
- `FileInventoryScanner` (prefetched resource keys, batched sinks, depth
  bounds, cooperative cancellation, disappearing-file tolerance)
- `TraversalPolicy` + `PathSafety` (canonicalization, symlink containment,
  ownership, device boundaries, protected roots/names/suffixes)
- `JunkClassifier` (SAFE / REVIEW / PROTECTED; only SAFE is smart-selected)
- `ApplicationInventoryService` (all app roots, architecture via Mach-O
  headers, SecStaticCode signing state, quarantine xattr)
- `ResidualCorrelationEngine` (exact bundle/container/preference/saved-state
  matching; loose substring matching forbidden)
- `DuplicatePipeline` (size → sample hash → streaming SHA-256 → inode
  identity; hard-link aware; APFS clone uncertainty labelled)
- `ScanIndexStore` (SQLite via system libsqlite3 — schema migrations,
  batched inserts, checkpoints, root-granularity resume)
- `IncrementalScanSupport` (public FSEvents only — last event ID per volume,
  `MustScanSubDirs` rescan, `.fseventsd` never touched)
- `ScanCoverageReport` (precise wording: scanned/partial/denied/SIP/skipped)
- `CleanupPlanBuilder` → `CleanupSafetyValidator` → `CleanupExecutor`
  (immutable plan, TOCTOU revalidation, trash-only execution)
- `IgnoreListStore`, `ScanProgressAggregator`, `ScanGate` (pause/resume)

## Safety rules (unchanged and extended)

- **Preview Mode ON by default**; a deliberate, confirmed control exits it.
- Only user-selected items ever enter a cleanup plan; SAFE items may be
  smart-selected; REVIEW and PROTECTED are never auto-selected.
- Every scanning and cleanup module removes files exclusively through
  `FileManager.trashItem`. The single exception is the **Trash Bins** module,
  where you can explicitly confirm *Put Back*, *Delete Immediately* or *Empty
  Trash* for items that are **already inside a Trash folder**; every candidate
  path is re-validated against the real Trash roots (`~/.Trash` plus the
  per-volume trashes) with a standardised prefix check before anything is
  removed. The app never uses `sudo`, `rm`, shell commands,
  `Process`/`NSTask`, `system()`, `popen()` or network calls.
- `/System`, `/Library`, `/private`, `/usr`, `/bin`, `/sbin`, `/Applications`,
  `/Volumes`, `/Network`, `/dev`, `/cores` are hard-blocked; Desktop,
  Documents, Downloads, Pictures, Music and Movies are never scanned by
  default; other users' files, keychains, browser privacy data, personal
  documents, source repositories, cloud databases, Time Machine and VM disks
  are protected; running apps are never removed.
- SIP is never bypassed and the user is never asked to disable it. Full Disk
  Access is granted by the user in System Settings — the app probes it with
  carefully worded results (likely/limited/not determined/denied).
- Scan coverage is reported precisely; "Entire Mac scanned" is never shown
  unless true.

## Permissions & first run

The **Permissions** module (plus the onboarding flow inside Deep Scan)
explains what Full Disk Access enables, what SIP keeps protected, that macOS
requires manual grant, and the coverage impact of continuing limited. It
opens the correct System Settings pane via
`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.

## Updates

Sparkle 2 self-update via Swift Package Manager. Updates install **only** when
a real signed feed + EdDSA public key exist and the running binary passes the
Developer ID requirement — development builds honestly disable updates.
Third-party app update inventory is intentionally unavailable (no invented
version data). See `Docs/SparkleSetup.md` for the key generation, secrets and
release runbook, and `Docs/Distribution.md` for the two distribution editions.

## Download & install

**Two different things can be downloaded from this repository — read this first:**

| What you have | What it is | What to do |
| --- | --- | --- |
| `8002CleanUp-1.2.0-build12-…-source.zip` | **Source code only.** The complete Xcode project — no `.app`, no binary of any kind | Build it once on your Mac: `./Scripts/build_and_verify_macos.sh --install` (or double-click `Scripts/Install.command`). Full guide: **`INSTALL.md`** |
| A `.zip` from [GitHub Releases](https://github.com/salmanbashir80/SalmanMacCleaner/releases) | A prebuilt app bundle produced by CI | Unpack, then open the app; macOS may ask you to confirm the first launch |

Nothing in this repository is signed with a Developer ID or notarized, so macOS
Gatekeeper may block the first launch of any build you make or download:
**right-click the app → Open → Open**, or run
`xattr -dr com.apple.quarantine /Applications/SalmanMacCleaner.app`.

Grant **Full Disk Access** (System Settings → Privacy & Security → Full Disk Access) only when
you want complete scans; without it the app still runs and reports limited/denied areas honestly.

> **About the `v1.0.6` / `v1.0.13` releases:** those tags were CI run numbers
> (`v1.0.${{ github.run_number }}`), not product versions, and they were built from a `main`
> state that was missing seven working commits. They are superseded by this restore
> (product version **1.2.0 (12)**). See `RESTORE_REPORT.md` for the full evidence.

## Building

```bash
# Debug (unsigned)
xcodebuild -project SalmanMacCleaner.xcodeproj \
  -scheme SalmanMacCleaner \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build

# Release
xcodebuild -project SalmanMacCleaner.xcodeproj \
  -scheme SalmanMacCleaner -configuration Release \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build

# Tests
xcodebuild -project SalmanMacCleaner.xcodeproj \
  -scheme SalmanMacCleaner -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
```

`Tools/generate_pbxproj.py` regenerates the project file from the directory
tree; `Tools/validate_project.py`, `Tools/parse_check.py` and
`Tools/xref_check.py` provide no-Xcode structural validation.

CI and release workflows ship in `Support/workflows/` (see
`Docs/ReleaseWorkflow.md` for the one-step activation).

## Project layout

```
SalmanMacCleaner.xcodeproj        app + test targets, shared scheme, Sparkle SPM ref
SalmanMacCleaner/
  Core/                           safety, cleanup engine, stores, updater
  Engine/                         deep-scan architecture (see above)
  UI/                             Aurora shell, hero, results workspace
  UI/DesignSystem/                tokens, aurora background, glass, artwork
  Features/                       20 modules (Space Lens, Permissions, …)
  en.lproj/Localizable.strings    750+ localized strings
SalmanMacCleanerTests/            60+ tests incl. fixture end-to-end flow
Support/appcast.xml               Sparkle feed (stable raw URL)
Support/workflows/                ci.yml + release.yml (ready to activate)
Docs/                             Sparkle setup, distribution, CI activation
```

## Privacy

Everything is local. No analytics SDKs, no network calls from the app, no
upload of paths, names, hashes, inventory or history. History export is
local, and a Settings toggle redacts paths in history views.

## License

MIT — see [LICENSE](LICENSE). Not affiliated with Apple Inc.
