# 8002CleanUp — restoration report (release v1.0.13 → verified 2026-08-27 state)

Date: 2026-10-07
Branch `arena/1e501ddc-salmanmaccleaner`: `5e67e54` (restore), `5757d6f` (compile fix confirmed
by CI), plus this report. An earlier commit `d852159` was squash-rewritten into `5e67e54` so the
branch could be pushed without `.github/workflows/` changes (see Option C, "Push constraint").
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
| **Non-installable packaging** | The active legacy CI packaged the `.app` with `zip -r`, which can flatten framework symlinks. The new DMG builder stages the bundle with `ditto`, creates a read-only image with `hdiutil`, and verifies the mounted contents; this new path is not yet run in CI. |
| **Ad-hoc signature** | The new DMG builder uses `CODE_SIGN_IDENTITY="-"` and fails if it cannot verify the ad-hoc signature; it has no unsigned fallback. Developer ID signing and notarization are not included. |
| **Misleading release tags** | `main` pushes no longer publish `v1.0.<run number>` releases; `release.yml` publishes from a real tag and names the asset after the product version. |
| **CI committing into the repo** | The "Commit Logs on Failure" steps force-added `build.log`, `test.log`, `job_log*.txt`, `run_status*.json`, `jobs*.json`, `annotations.json`, `artifacts.json`, `step_logs.txt` to the repo; they are deleted and logs now upload as workflow artifacts. |
| **Raw localization keys in the UI** | 10 keys used by the restored Trash/Duplicate views (`trash.restore_selected`, `trash.delete_permanently`, `permanent_delete_confirmation_title`, …) were **never defined in any commit**, so the UI displayed the raw key. They are now defined in `en.lproj/Localizable.strings` (603 used keys, 0 undefined). |
| **Dead code** | `Features/TrashBins/TrashValidator.swift` was never referenced by any code path *and* never added to the Xcode project → removed. |
| **TrashBinsView did not compile under Xcode 15.2** | The first macOS CI run on this branch failed with exactly three errors in the restored file (`243:30: expression is 'async' but is not marked with 'await'`; `282:27` and `283:30: reference to captured var 'found'/'total' in concurrently-executing code`). Fixed in `5757d6f` with the same hoisting main's variant carries: resolve `[~/.Trash] + trashMounts()` on the main actor before the detached task, and hoist `found`/`total` into immutable locals before `await MainActor.run`. The next run passed. |
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
Support/workflows/ci.yml                    macOS 14 + macOS 27 tests/builds; DMG artifact,
                                            ad-hoc signing and mounted-image/launch checks
Support/workflows/release-unsigned.yml (new)  FIXED tag-release workflow (real product version,
                                            ditto packaging, SHA-256, no secrets needed)
Support/workflows/ios-ci.yml (new)          FIXED iOS workflow (no branch-pushing log dumps)
Scripts/activate_workflows.sh (new)         copies the templates into .github/workflows/
.gitignore                                     dist/, *.log, packaged ZIP names
CHANGELOG.md, README.md, SECURITY.md           accurate Trash/sandbox policy; restore entry
Docs/Distribution.md, Docs/ReleaseWorkflow.md  sandbox rationale; CI/release documentation
TEST_REPORT-v1.2.0.md                          marked as the historical build-8 report
Scripts/build_and_package_dmg.sh (new)          build + ad-hoc sign + verify + hdiutil DMG + install/launch smoke test
Scripts/build_and_verify_macos.sh               compatibility shim to the DMG builder (no ZIP output)
Scripts/Install.command                         double-clickable DMG builder; opens Finder to the finished image
INSTALL.md                                       DMG activation, checksum, installation and limitation guide
RESTORE_REPORT.md                                evidence + provenance audit, with current DMG status
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
| Workflow YAML | `yaml.safe_load` on all 7 files under `.github/workflows/` and `Support/workflows/` | All valid |
| DMG build/package script | `bash -n Scripts/build_and_package_dmg.sh` | Syntax OK (macOS commands not run here) |
| Compatibility/installer scripts | `bash -n Scripts/build_and_verify_macos.sh Scripts/Install.command Scripts/activate_workflows.sh` | Syntax OK |
| Diff review | file-by-file `git diff 0e990e1 HEAD` / `63e9c9c` | Every restored hunk traced to a named working commit; no unverified rewrites |

Baseline check: `Tools/validate_project.py` on **unmodified `main` (`63e9c9c`)** already failed with
4 errors (dead empty button, `emptyTrash` outside the policy) — the released state did not even
pass the repository's own validator, and the old CI never ran it.

### macOS compile + test evidence (GitHub Actions, real hardware)

The first CI run on this branch is what found the three concurrency errors above; after the fix,
**the restored source compiles and the test suite passes on macOS**:

| Run | Workflow | Event | Commit | Result | Steps |
| --- | --- | --- | --- | --- | --- |
| [37680551814](https://github.com/salmanbashir80/SalmanMacCleaner/actions/runs/37680551814) | `CI` | pull_request | `0373d16` (restored branch before DMG follow-up) | **success** | XCTest ✅ · Debug ✅ · Release (unsigned) ✅ · legacy `Package Mac Application` ✅; no DMG and no uploaded artifacts |
| [37679861978](https://github.com/salmanbashir80/SalmanMacCleaner/actions/runs/37679861978) | `CI` | pull_request | `7d6ebac` | **success** | `Run Unit Tests` ✅ · `Build Debug` ✅ · `Build Release (Unsigned)` ✅ · `Package Mac Application` ✅ (`Create GitHub Release` correctly skipped) |
| [37675648454](https://github.com/salmanbashir80/SalmanMacCleaner/actions/runs/37675648454) | `CI` | pull_request | `5757d6f` | **success** | same four steps ✅ |
| 37675150238 | `CI` | pull_request | `abfaa89` | failure | 3 `TrashBinsView.swift` concurrency errors (fixed in `5757d6f`) |

Runner: `macos-14`, Xcode 15.2, Swift 5.9, `xcodebuild test -destination 'platform=macOS'`.
The failing run's log was recovered from the `ci-logs-mac` branch the old workflow pushes on
failure (`git show origin/ci-logs-mac:mac_test.log`); the passing run's log host is blocked from
this sandbox, so the evidence for it is the job/step conclusions from the GitHub API.
This is **compile + unit-test evidence**, not launch/install evidence.

### What is NOT verified — stated plainly

- **Nothing was compiled or tested in the working environment itself.** There is no macOS and no
  Xcode/Swift toolchain here (`xcodebuild`, `swift`, `swiftc`: not found; OS: Debian 12 x86_64).
  Compilation and unit tests were exercised only through GitHub's macOS runner (see above).
- **The app was never launched or installed** — on this machine (no macOS) or on a runner. No
  `.app`, `.dmg`, `.xcarchive` or `.xcresult` is included in the ZIP; the release asset could not
  be downloaded, so no binary was inspectable.
- tree-sitter is a **syntax** parser, not a type checker: locally it only proves the restored
  files parse. Compilation proof comes from the macOS CI run above, on the repository's own
  workflow (which uses `CODE_SIGNING_ALLOWED=NO`); the ad-hoc signing flags in the new
  `Support/workflows/ci.yml` template have not been exercised on a runner yet.
- The released ZIP asset (`release-assets.githubusercontent.com`) and the CI log host
  (`results-receiver.actions.githubusercontent.com`) are both blocked from this sandbox, so the
  comparison with the released binary is source-level only.
- The iOS target (`SalmanCleanerMobile`) was not verified here; it is untouched by this restore.
- No commit hash, test result or ZIP content in this report is invented — every claim above comes
  from the commands shown, and everything unverified is listed in this section.

---

## 6. Exact steps to build, install and verify on macOS

*(A standalone quick-start copy of this section ships as `INSTALL.md` at the project root,
so anyone who unzips the archive sees the build/launch steps immediately.)*

### Option A — build and package as a DMG (recommended)

```bash
cd /path/to/SalmanMacCleaner             # the cloned/unzipped project
python3 Tools/validate_project.py        # structural validation, no Xcode needed
./Scripts/build_and_package_dmg.sh      # Release + signed DMG + mount/install/launch checks
./Scripts/build_and_package_dmg.sh --test  # also runs the XCTest suite
```

The new script is macOS-only. It requires a valid ad-hoc signature (no unsigned fallback),
checks bundle resources and symlinks, uses `ditto` to stage `8002CleanUp.app`, creates and
mounts a read-only `.dmg` with an `/Applications` shortcut, verifies the copied bundle, and
runs a launch smoke test. It writes the DMG and SHA-256 sidecar to `dist/`. It has not been
executed in the Linux Agent Mode host; see section 9 for the current CI/artifact status.

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

# Copy/install without zip -r (the DMG uses this same bundle-preserving copy)
rm -rf /Applications/8002CleanUp.app
/usr/bin/ditto "$APP" /Applications/8002CleanUp.app
xattr -dr com.apple.quarantine /Applications/8002CleanUp.app 2>/dev/null || true
```

Expected: **8002CleanUp 1.2.0 (12)** in the sidebar header/toolbar badge, sidebar rows clear of the
title-bar controls, "Back to Smart Care" in Duplicate Finder and Startup Items, Full Disk Access
grantable and honored by Deep Scan. The unpacked app is **not notarized** (no Developer ID here),
so the first launch needs right-click → **Open**, or the `xattr -dr com.apple.quarantine` command.
The bundle is `SalmanMacCleaner.app` while the visible name is **8002CleanUp**.

### Option C — let GitHub's macOS runners build and test the DMG

The new CI template is in `Support/workflows/ci.yml`. The active `.github/workflows/ci.yml` on
the repository branch is still the older pipeline, which builds a ZIP and does not upload a DMG.
A maintainer with GitHub `workflows` permission must activate and push the template on the restored
branch; do not push this workflow change directly to `main`:

```bash
./Scripts/activate_workflows.sh
git diff -- .github/workflows
git add .github/workflows
git commit -m "ci: activate macOS 27 DMG verification"
git push origin arena/1e501ddc-salmanmaccleaner
```

After the workflow is activated, dispatch it (or let the pull-request check run) and download the
DMG + SHA-256 from the Actions artifact:

```bash
gh workflow run CI --repo salmanbashir80/SalmanMacCleaner \
  --ref arena/1e501ddc-salmanmaccleaner
gh run watch --repo salmanbashir80/SalmanMacCleaner
```

The macOS 14 job tests/builds with Xcode 15. The `xcode-27` preview job checks macOS 27/Xcode 27,
runs tests and Debug/Release builds, creates and mounts a signed DMG, checks its app bundle and
Applications symlink, copies the app to an install-style folder, and launches it. This is the
intended route to a real DMG without a local Mac, but **the template still has to run successfully**
before an actual DMG/checksum can be claimed.

> **Workflow-write constraint (measured, not assumed).** A previous push that included
> `.github/workflows/ci.yml` was rejected with `refusing to allow a GitHub App to create or update
> workflow ... without 'workflows' permission`. The CI template and build script can be committed
> under `Support/` and `Scripts/`, but a repository maintainer with workflow-write permission must
> activate/push `.github/workflows/ci.yml` before these new checks can run.

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
   for these commits (GitHub rejected the push; see Option C). The CI/release templates live under
   `Support/workflows/`; a maintainer with workflow-write permission must run
   `./Scripts/activate_workflows.sh`, review the changes, then push them on the restored branch.
   The DMG CI cannot run until that activation is complete.
6. **`v1.0.6` / `v1.0.13` releases** remain on GitHub with misnamed tags; they were produced by the
   removed run-number logic. Deleting them (or re-tagging `v1.2.0`) is a repository-owner action.

---

## 8. Attribution / provenance audit — is anything named "Freebuff" in this project?

**No. There is no evidence of a tool, service, branch, session, bot or person called
"Freebuff" (or FreeBuf / Free Buff / freebuff) anywhere in this project or in the history that
was inspectable from here.** The searches below were run against the full clone (all 12 remote
branches, all 64 commits, all objects) plus the GitHub API and the local environment:

| Search | Command | Result |
| --- | --- | --- |
| Commit messages, authors, committers, trailers | `git log --all --format='%an %ae %cn %ce %s %b' \| grep -i freebuff` | **0 hits** |
| File contents in *every* revision | `git grep -I -i freebuff $(git rev-list --all)` | **0 hits** |
| Unreachable/dangling git objects too | `git cat-file --batch-all-objects` blob scan | **0 hits** |
| Refs, branches, tags, stash, notes, reflog | `git for-each-ref`, `git stash list`, `git notes list`, `git reflog --all` | **no such ref** |
| Workspace files and filenames | `find /home/user -iname '*freebuff*'`, `grep -ril freebuff /home/user` | **0 hits** |
| Environment / processes | `env`, `ps aux` | **0 hits** |
| GitHub repo list of the owner | `gh api users/salmanbashir80/repos` | no repo of that name |
| GitHub Actions actors on this repo | `gh api repos/.../actions/runs` → unique actors | only `salmanbashir80` |
| Pull requests (all states) | `gh pr list --state all` | authors: `salmanbashir80`, `app/arena-ai-coding-agent` — no Freebuff |
| Commit trailers across all history | `git log --all --format='%b'` | exactly one trailer type: `Co-authored-by: arena-agent <297053741+arena-agent@users.noreply.github.com>` (26 commits) |

Arena's own agent identities appear in the history, but none is called Freebuff:

| Actor | How it appears | Commits |
| --- | --- | --- |
| `arena-ai-coding-agent[bot]` | author of 3 commits; author (`app/arena-ai-coding-agent`) of PRs #1–#4 | `1670d0d` (initial), `b4130ab`, `eaad166` |
| `arena-agent` | **Co-authored-by trailer only** on 26 commits | e.g. `85468d2` … `a072429`, `f56d38e` |
| `8002salman-ai` | author/committer, Aug 24–27 work (incl. the verified line) | 20 commits |
| `salmanbashir80` | author/committer, Oct 6–7 work; owner account; PR #5 | 29 commits |
| `github-actions[bot]` | author of the CI log-dump commits | 5 commits |
| `Arena Agent <agent@arena.ai>` | this restore | 4 commits |

### What actually made files and features disappear (evidence, not a guess)

1. **Branch divergence, not a third-party tool.** `main` and the verified line split at
   `0737d29` (2026-08-26). `main` received only `f56d38e`; the verified line continued with
   `a072429`, `a6a9dd5`, `9f43293`, `35d71d7`, `b5eef52`, `5d37f6f`, `0e990e1`.
   `git merge-base --is-ancestor f56d38e 0e990e1` → false (they are siblings). Those seven
   commits — Full Disk Access fix, Smart Care stall fix, back navigation, compact window, Trash
   validation — were never merged, so every `v1.0.x` release built from `main` lacked them.
2. **The 2026-10-06/07 rewrite on `main`** (`salmanbashir80`, no co-author trailers):
   - `d85b6a7` re-enabled App Sandbox (breaking Full Disk Access), deleted 117 lines of
     regression tests, and deleted `Support/workflows/release.yml`;
   - `a42e218` added `TrashValidator.swift` — never referenced and never added to the Xcode
     project (dead code), and rewrote TrashBins view code;
   - `9c30bb0` ("fix: compile errors in TrashBinsView") replaced the Trash-root validation with
     the unsafe `path.contains(".Trash")` check;
   - `63e9c9c` trimmed yet more test code.
3. **`github-actions[bot]` added files rather than removing them**: the old CI's
   "Commit Logs on Failure" steps force-added `build.log`, `test.log`, `job_log*.txt`,
   `run_status*.json`, `jobs*.json`, `annotations.json`, `artifacts.json` and `step_logs.txt`
   to the repository. Those are the junk files removed by this restore; the same steps also
   created the `ci-logs` / `ci-logs-mac` branches.

If "Freebuff" was seen outside this repository (for example as a browser extension, a macOS
utility, or a label in another tool), it cannot be linked to these changes from any evidence in
this repository or in the Arena-side history that is visible to this session — no such name is
present in either.

---

## 9. DMG request — implementation added, binary not yet built

The DMG packaging path was added after the source restore. **There is no generated DMG in this
checkout or in the latest CI run.** This status is explicit so the packaging script/template is
not mistaken for an installable artifact.

| Check | Evidence | What it proves / does not prove |
| --- | --- | --- |
| Local build host | Debian 12 x86_64; `xcodebuild`, `swift`, and `swiftc` are not installed | This host cannot compile, sign, mount a DMG, or launch a macOS app |
| Existing macOS CI at restored HEAD | Run `37680551814` on `0373d161b5caa2d4c3983ad67bf1971b7a03f209` passed XCTest, Debug build, Release build, and the old `Package Mac Application` step | It used the checked-in legacy workflow (`macos-14`, `zip -r`); run Artifacts API returned `total_count: 0`. It did not produce or upload a DMG |
| New build/package path | `Scripts/build_and_package_dmg.sh` and the `Support/workflows/ci.yml` template | Added, but not run on macOS in this session |
| macOS 27 runner availability | GitHub `actions/runner-images` issue [#14404](https://github.com/actions/runner-images/issues/14404) and its `xcode-27-arm64-Readme.md` identify the preview `xcode-27` image as macOS 27 with Xcode 27 | A runner label is available for a real macOS 27 CI attempt; it is not evidence that this project's new workflow passed |
| Workflow activation | The active `.github/workflows/ci.yml` is still the old file; the GitHub App push previously failed for lack of `workflows` permission | A repository maintainer with workflow-write permission must run `Scripts/activate_workflows.sh`, review/commit the workflow changes on the restored branch, then run CI |
| Minimum OS | Project `MACOSX_DEPLOYMENT_TARGET = 13.0`; new script checks built `LSMinimumSystemVersion` | Declares a 13.0 minimum. There is no macOS 13 hosted runner in the configured matrix, so real Ventura launch remains unverified |

The intended CI will run tests and Debug/Release builds on macOS 14, then on macOS 27 will build
an arm64 Release, require and verify an ad-hoc code signature, preserve the app bundle with
`ditto`, create a read-only DMG with `hdiutil`, mount and inspect it, copy the app into a
staged Applications folder, and run a launch smoke test. That workflow is a plan/template until
activated and successfully run. A GitHub Actions run artifact will contain the `.dmg` and its
`.sha256` sidecar; it is not a substitute for reporting the actual resulting checksum.
