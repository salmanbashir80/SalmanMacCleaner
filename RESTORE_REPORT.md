# 8002CleanUp — restoration report (release v1.0.13 → verified 2026-08-27 state)

Date: 2026-10-07
Restore commit: `5e67e54` (branch `arena/1e501ddc-salmanmaccleaner`); the earlier working
restore commit `d852159` was squash-rewritten into it so the branch could be pushed without
`.github/workflows/` changes (see Option C, "Push constraint").
Branch: `arena/1e501ddc-salmanmaccleaner` (based on `main` @ `63e9c9c4e594560a214d3aba1129b8d0c7586db6`)
Environment used for the work: Linux (Debian 12, x86_64), Python 3.11 — **no macOS, no Xcode, no Swift toolchain**.

---

## 1. What the project is actually called (verified, not guessed)

| Question | Verdict | Evidence |
| --- | --- | --- |
| Repository / Xcode target | **SalmanMacCleaner** | Remote `salmanbashir80/SalmanMacCleaner`; target and scheme `SalmanMacCleaner`; bundle `SalmanMacCleaner.app`; bundle id `com.salman.SalmanMacCleaner` |
| Visible product name (today) | **8002CleanUp** | `Info.plist` → `CFBundleName`/`CFBundleDisplayName = 8002CleanUp`; `Core/AppIdentity.swift` → `displayName = "8002CleanUp"`; rename commit `6fee63e` (2026-08-26, "feat: rename visible product to 8002CleanUp, bump to v1.2.0 (build 8)") |
| Original name in the first commits | **SalmanMacCleaner** (README `# SalmanMacCleaner`, commit `1670d0d`), then **Salman Mac Cleaner** for the app (commit `85468d2`) | `git show 1670d0d:README.md`, `git show 85468d2:README.md` |
| Was it ever **8002Cleaner**? | **No.** | `git grep -i "8002Cleaner" $(git rev-list --all)` → **0 hits in the entire 64-commit history.** The "8002" substring only exists as the old GitHub account name `8002salman-ai` and in the product name `8002CleanUp`. |

So: repository/project = **SalmanMacCleaner**, visible product = **8002CleanUp**, and `8002Cleaner` is not a name this project ever used.

---

## 2. Which source was used, and why "release v1.0.13" is not a working version

`gh release list` shows two releases: **v1.0.13** and **v1.0.6**. Both were produced by
`.github/workflows/ci.yml`, which tagged every push to `main` with
`tag_name: "v1.0.${{ github.run_number }}"`. The tags are **CI run numbers**, not product versions:

| Tag | Commit | CI run | Product version at that commit | Published ZIP |
| --- | --- | --- | --- | --- |
| `v1.0.6` | `66c3e4c` | CI #6 | 1.2.0 (build 8) | `SalmanMacCleaner-macOS.zip` (6,502,090 bytes on v1.0.13) |
| `v1.0.13` | `63e9c9c` | CI #13 | 1.2.0 (build 8) | `SalmanMacCleaner-macOS.zip` |

`v1.0.13` therefore points at the **current, broken `main` head** — it is not a snapshot of the
working app. The working code lives on a branch that `main` never merged:

- `main` history: … → `0737d29` → **`f56d38e`** → `d85b6a7` (2026-10-06) → … → `63e9c9c`
- verified history: … → `0737d29` → **`a072429` → `a6a9dd5` → `9f43293` → `35d71d7` → `b5eef52` → `5d37f6f` → `0e990e1`**

`f56d38e` and `a072429` are sibling commits with the same message
("fix: Duplicate Finder idle state rendering + Trash Bins enhancements + regression tests");
`main` took one, and the working line continued with six more commits plus `a072429`.
`git merge-base --is-ancestor f56d38e 0e990e1` → **false**: they are divergent branches.

**Source used for this restore:** `origin/arena/01a03f44-verified`, tip
**`0e990e15e886b8724a7e020fb95e64e01a52fa93`** (2026-08-27 12:31 +0500,
"Add visible back navigation to duplicate finder") — the newest commit of the branch that was
verified on macOS. Version metadata at that commit: `MARKETING_VERSION = 1.2.0`,
`CURRENT_PROJECT_VERSION = 12`, i.e. **8002CleanUp 1.2.0 (build 12)**, newer than the
**1.1.7 (build 7)** build previously installed on the user's Mac (`226b9da`, 2026-08-26).

Why the released ZIP was not inspectable: the release asset is served from
`release-assets.githubusercontent.com`, which this sandbox's network policy blocks
(`curl` → `SSL_ERROR_SYSCALL`, `gh release download` → `EOF`). The comparison was therefore done
**at source level**, from the tag's commit, which is the same commit that produced that ZIP.

---

## 3. What was missing/broken, and what was restored

Seven working commits were absent from `main`. Their content, restored here:

| # | Missing work (source commit) | Symptom in the current ZIP | Action |
| --- | --- | --- | --- |
| 1 | `a072429` — Duplicate Finder idle state + Trash Bins enhancements + regression tests | Trash module rebuilt from a compile-fix pass; ~112 lines of regression tests deleted from `DuplicateFinderTests.swift` | Files restored from `0e990e1` |
| 2 | `a6a9dd5` — "make trash actions compile and stay inside trash" | — | included in the restored file |
| 3 | `9f43293` — "honor Full Disk Access in local build" | **`ENABLE_APP_SANDBOX = YES` + `com.apple.security.app-sandbox` were re-enabled.** A sandboxed app cannot reach `~/Library`, other volumes or protected locations even with Full Disk Access, so Deep Scan / Smart Care silently degraded | Sandbox removed from `project.pbxproj` (2 configs), `Tools/generate_pbxproj.py`, and the entitlements file; `Tools/validate_project.py` asserts it stays off |
| 4 | `35d71d7` — "prevent Smart Care application scan stall" | Health check ran the *full* applications inventory (measuring, signing and metadata-querying every bundle) and appeared stuck at 50% | `HealthCheckService.applicationsFactor` restored to the bounded bundle count |
| 5 | `b5eef52` — "Compact macOS window and fix sidebar title-bar overlap" | Window grew to 1100×720 min / 1440×900 default; sidebar list overlapped the title-bar controls | Compact sizes (980×640 min, 1180×760 default), sidebar width, and the `safeAreaInset` fix restored |
| 6 | `5d37f6f` — "Add visible back navigation to startup items" | No way back to Smart Care | "Back to Smart Care" button restored |
| 7 | `0e990e1` — "Add visible back navigation to duplicate finder" | No way back to Smart Care | "Back to Smart Care" button restored |

Additionally fixed in this pass (defects present in the released state):

| Item | Detail |
| --- | --- |
| **Trash safety regression** | The released code validated permanent deletion with `paths.filter { $0.contains(".Trash") }` — any path merely *containing* `.Trash` (e.g. `~/Documents/my.Trash.notes/`) passed. Restored: standardised prefix check against the real Trash roots (`~/.Trash` + per-volume trashes). |
| **Put Back on items with no original path** | Restored version disables Put Back when `originalPath` is unknown instead of offering a dead action. |
| **Non-installable packaging** | CI packaged the `.app` with `zip -r`, which follows symlinks and flattens framework version directories. All packaging now uses `ditto -c -k --keepParent` (CI + local script). |
| **Unsigned Release build** | Release builds are now ad-hoc signed (`CODE_SIGN_IDENTITY="-"`, which Apple Silicon requires) with an explicit unsigned fallback and a loud warning. |
| **Misleading release tags** | `main` pushes no longer publish `v1.0.<run number>` releases; `release.yml` publishes from a real tag and names the asset after the product version. |
| **CI committing into the repo** | The "Commit Logs on Failure" steps force-added `build.log`, `test.log`, `job_log*.txt`, `run_status*.json`, `jobs*.json`, `annotations.json`, `artifacts.json`, `step_logs.txt` to the repo; they are deleted and logs now upload as workflow artifacts. |
| **Raw localization keys in the UI** | 10 keys used by the restored Trash/Duplicate views (`trash.restore_selected`, `trash.delete_permanently`, `permanent_delete_confirmation_title`, …) were **never defined in any commit**, so the UI displayed the raw key. They are now defined in `en.lproj/Localizable.strings` (603 used keys, 0 undefined). |
| **Dead code** | `Features/TrashBins/TrashValidator.swift` was never referenced by any code path *and* never added to the Xcode project → removed. |
| **Stale URLs** | `8002salman-ai/SalmanMacCleaner` → `salmanbashir80/SalmanMacCleaner` (app menu, settings, appcast, support workflow). |

---

## 4. Files changed (41 files; `git diff --shortstat 63e9c9c 5e67e54` = 1079 insertions, 1868 deletions)

Application code restored from `0e990e1`:

```
SalmanMacCleaner/Engine/HealthCheckService.swift                 (Smart Care stall fix)
SalmanMacCleaner/Features/Duplicates/DuplicatesView.swift        (back navigation)
SalmanMacCleaner/Features/StartupItems/StartupItemsView.swift    (back navigation)
SalmanMacCleaner/Features/TrashBins/TrashBinsView.swift          (safe trash validation, Put Back, styles)
SalmanMacCleaner/SalmanMacCleanerApp.swift                       (compact window; URL kept current)
SalmanMacCleaner/UI/ContentView.swift                            (compact sidebar width)
SalmanMacCleaner/UI/SidebarView.swift                            (title-bar overlap fix)
SalmanMacCleaner/SalmanMacCleaner.entitlements                   (app sandbox removed)
SalmanMacCleanerTests/DuplicateFinderTests.swift                 (regression tests restored)
SalmanMacCleanerTests/PathSafetyTests.swift                      (regression tests restored)
SalmanMacCleanerTests/AppIdentityTests.swift                     (build 12)
Support/workflows/release.yml                                    (signed/notarized template restored; URLs updated)
```

Surgical edits made in this pass:

```
SalmanMacCleaner.xcodeproj/project.pbxproj     sandbox off (2 configs), CURRENT_PROJECT_VERSION 8 → 12 (4 configs)
Tools/generate_pbxproj.py                      same two changes, so regeneration cannot reintroduce them
Tools/validate_project.py                      sandbox assertion restored; destructive-API rule scoped to Trash Bins
SalmanMacCleaner/en.lproj/Localizable.strings  10 missing keys added; Trash warning copy corrected
SalmanMacCleaner/Core/AppIdentity.swift        version-badge doc comment
SalmanMacCleaner/Features/TrashBins/TrashBinsView.swift  dead "Search" button (empty action) removed
Support/workflows/ci.yml                    FIXED CI workflow (ad-hoc signing, ditto packaging,
                                            no auto-release from main pushes, artifact logs)
Support/workflows/release-unsigned.yml (new)  FIXED tag-release workflow (real product version,
                                            ditto packaging, SHA-256, no secrets needed)
Support/workflows/ios-ci.yml (new)          FIXED iOS workflow (no branch-pushing log dumps)
Scripts/activate_workflows.sh (new)         copies the templates into .github/workflows/
.gitignore                                     dist/, *.log, packaged ZIP names
CHANGELOG.md, README.md, SECURITY.md           accurate Trash/sandbox policy; restore entry
Docs/Distribution.md, Docs/ReleaseWorkflow.md  sandbox rationale; CI/release documentation
TEST_REPORT-v1.2.0.md                          marked as the historical build-8 report
Scripts/build_and_verify_macos.sh  (new)       build + verify + optional install on macOS
RESTORE_REPORT.md  (new)                       this document
```

Removed: `TrashValidator.swift`, `Tools/generate_mobile_pbxproj.py.bak`, `build.log`, `test.log`,
`job_log.txt`, `job_logs.txt`, `jobs.json`, `jobs_latest.json`, `run_status{,_2,_3}.json`,
`annotations.json`, `artifacts.json`, `step_logs.txt`.

---

## 5. Verification actually performed here (and its limits)

Run in this Linux container, on the restored tree:

| Check | Command | Result |
| --- | --- | --- |
| Structural validation | `python3 Tools/validate_project.py` | **PASSED — all checks passed (0 warnings)** — includes "app sandbox disabled for Full Disk Access build", "95 Swift file references resolve", "every Swift file is referenced by the project", "all 603 used keys defined in Localizable.strings", "destructive APIs confined to the Trash Bins module" |
| Swift syntax parse (all files) | `python3 Tools/parse_check.py` (tree-sitter Swift grammar) | Parsed **102 Swift files** — **no syntax errors** |
| Cross-reference heuristic | `python3 Tools/xref_check.py` | Checked 102 files — no suspicious member references |
| Tooling syntax | `python3 -m py_compile Tools/*.py` | All OK |
| Workflow YAML | `yaml.safe_load` on all 5 workflow files | All valid |
| Build/verify script | `bash -n Scripts/build_and_verify_macos.sh` | Syntax OK |
| Diff review | file-by-file `git diff 0e990e1 HEAD` / `63e9c9c` | Every restored hunk traced to a named working commit; no unverified rewrites |

Baseline check: `Tools/validate_project.py` on **unmodified `main` (`63e9c9c`)** already failed with
4 errors (dead empty button, `emptyTrash` outside the policy) — the released state did not even
pass the repository's own validator, and the old CI never ran it.

### What is NOT verified — stated plainly

- **The app was not compiled, not tested, not launched and not installed.** There is no macOS and
  no Xcode/Swift toolchain in this environment (`xcodebuild`, `swift`, `swiftc`: not found;
  OS: Debian 12 x86_64). No `.app`, `.dmg`, `.xcarchive` or `xcresult` exists in the ZIP.
- tree-sitter is a **syntax** parser, not a type checker: it proves the restored files parse, not
  that they compile.
- The released ZIP asset could not be downloaded (network policy), so the comparison with the
  released binary is source-level only.
- The iOS target (`SalmanCleanerMobile`) was not verified here; it is untouched by this restore.
- No commit hash, test result or ZIP content in this report is invented — every claim above comes
  from the commands shown, and everything unverified is listed in this section.

---

## 6. Exact steps to build, install and verify on macOS

### Option A — script (recommended)

```bash
cd /path/to/8002CleanUp                 # the unzipped project
python3 Tools/validate_project.py       # structural validation, no Xcode needed
./Scripts/build_and_verify_macos.sh            # build + verify bundle
./Scripts/build_and_verify_macos.sh --test     # also runs the XCTest suite
./Scripts/build_and_verify_macos.sh --install  # build, verify, copy to /Applications
```

The script checks for `xcodebuild`, resolves the Sparkle package, builds Release (ad-hoc signed,
unsigned fallback), prints `CFBundleName/DisplayName/ShortVersion/Bundle/Identifier`,
`lipo -archs`, `codesign --verify` output, then packages `dist/8002CleanUp-1.2.0-build12-macos.zip`
with a SHA-256 in `dist/checksums.txt`.

### Option B — raw commands

```bash
xcodebuild -resolvePackageDependencies -project SalmanMacCleaner.xcodeproj -scheme SalmanMacCleaner

# Tests
xcodebuild test -project SalmanMacCleaner.xcodeproj -scheme SalmanMacCleaner \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Release build (ad-hoc signed so it launches on Apple Silicon)
xcodebuild build -project SalmanMacCleaner.xcodeproj -scheme SalmanMacCleaner \
  -configuration Release -destination 'platform=macOS' -derivedDataPath build_mac \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""

# Verify the bundle
APP=build_mac/Build/Products/Release/SalmanMacCleaner.app
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$APP/Contents/Info.plist"   # 8002CleanUp
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist"  # 1.2.0
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist"       # 12
codesign --verify --deep --strict --verbose=2 "$APP"
open "$APP"

# Install (replacing any older copy)
rm -rf /Applications/SalmanMacCleaner.app
cp -R "$APP" /Applications/
xattr -dr com.apple.quarantine /Applications/SalmanMacCleaner.app 2>/dev/null || true
```

Expected: **8002CleanUp 1.2.0 (12)** in the sidebar header/toolbar badge, sidebar rows clear of the
title-bar controls, "Back to Smart Care" in Duplicate Finder and Startup Items, Full Disk Access
grantable and honored by Deep Scan. The unpacked app is **not notarized** (no Developer ID here),
so the first launch needs right-click → **Open**, or the `xattr -dr com.apple.quarantine` command.
The bundle is `SalmanMacCleaner.app` while the visible name is **8002CleanUp**.

### Option C — let GitHub's macOS runners do it (real compile + test evidence)

The workflow files ship under `Support/workflows/` **and** are already placed in
`.github/workflows/` inside the delivered ZIP. Push the extracted ZIP (or run the activation
script on an existing clone), then trigger the run:

```bash
./Scripts/activate_workflows.sh          # only needed when working from a clone
git add .github/workflows Support/workflows
git commit -m "ci: activate the restored workflows"
git push origin main

gh workflow run CI --repo salmanbashir80/SalmanMacCleaner --ref main
gh run watch --repo salmanbashir80/SalmanMacCleaner
```

The updated `ci.yml` runs the validator, the tree-sitter parse, the XCTest suite and a Release
build on `macos-14`, then uploads the packaged `.app` + checksum as a build artifact. That run is
the authoritative compile/test evidence and the fastest way to obtain a launchable `.app` without
a local Mac.

> **Push constraint (measured, not assumed).** The automation identity used to prepare these
> commits may not write `.github/workflows/`: `git push` was rejected with
> `refusing to allow a GitHub App to create or update workflow '.github/workflows/ci.yml' without
> 'workflows' permission`. The pushed branch therefore contains the workflow templates only under
> `Support/workflows/`, while the ZIP contains them activated in both locations. The repository
> owner (or a PAT with the `workflow` scope) can push them in one command.

---

## 7. Known remaining items / decisions

1. **Trash Bins policy.** The module can permanently delete items *already inside a Trash folder*
   after confirmation, and validates each path against the real Trash roots. The older read-only
   implementation (commit `56baad2`, UI limited to Refresh / Open in Finder / summary) is still in
   history if you prefer a Trash module that never deletes — say so and it can be swapped back.
2. **Accounting nuance.** `performPermanentDelete` / `emptyTrashConfirmed` record attempted
   selection counts in history; if a removal fails, the history entry can overstate what was
   removed. Not changed in this restore (behaviour identical to the verified build).
3. **`Tools/generate_pbxproj.py` is not authoritative.** Its output differs from the checked-in
   `project.pbxproj` (1024 diff lines), so the checked-in project file was edited directly and the
   generator was updated in parallel; do not regenerate without reconciling.
4. **Signed distribution** needs the six secrets listed in `Docs/ReleaseWorkflow.md`; until then
   releases are ad-hoc/unsigned and macOS shows the standard first-launch prompt.
5. **Workflow activation.** `.github/workflows/` cannot be written by the automation token used
   for these commits (GitHub rejected the push; see Option C). The fixed workflows are committed
   under `Support/workflows/` and are present, activated, in the delivered ZIP;
   `./Scripts/activate_workflows.sh` performs the copy and the owner pushes it.
6. **`v1.0.6` / `v1.0.13` releases** remain on GitHub with misnamed tags; they were produced by the
   removed run-number logic. Deleting them (or re-tagging `v1.2.0`) is a repository-owner action.
