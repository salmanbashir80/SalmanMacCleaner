# CI & Release Workflows

## Active workflows (`.github/workflows/`)

| File | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | push to `main` / `arena/**`, PRs to `main`, manual | Structural validation, tree-sitter Swift syntax parse, unit tests, Release build (ad-hoc signed, unsigned fallback), symlink-safe `.app` packaging + SHA-256, uploads the `.app` zip as a build artifact. **No release is published** — artifact only. |
| `release.yml` | tag push `v*`, manual dispatch with a tag | Tests, archive, ad-hoc signature, bundle verification, `ditto` packaging, checksum, GitHub Release. Needs **no secrets**. |
| `ios-ci.yml` | push / PR | Builds and tests the separate iOS target (`SalmanCleanerMobile.xcodeproj`). |

Nothing in CI ever commits to the repository. Logs are attached as workflow
artifacts instead of being pushed to branches (an earlier revision force-added
`build.log`, `test.log` and GitHub API dumps such as `run_status*.json` to
`main`; those files were removed and the behaviour is gone).

### Why the app must not be sandboxed

8002CleanUp performs full-disk maintenance. With App Sandbox enabled the app
cannot reach `~/Library`, other volumes or protected locations even when the
user grants Full Disk Access, so the scan silently degrades. The project
therefore builds with `ENABLE_APP_SANDBOX` **not** set and
`Tools/validate_project.py` fails the build if it reappears.

### Why `ditto` and not `zip`

`ditto -c -k --keepParent` preserves symlinks and extended attributes inside
`.app` bundles. `zip -r` follows symlinks, which flattens framework version
directories and produces an application bundle that macOS may refuse to launch.
Never package the app with `zip`.

### Why ad-hoc signing

On Apple Silicon every executable must carry at least an ad-hoc signature.
The Release jobs build with `CODE_SIGN_IDENTITY="-"` (which Xcode resolves to
an ad-hoc signature) and fall back to an unsigned build with a loud warning if
that is not possible in the runner environment.

## Signed / notarized distribution (optional, needs secrets)

`Support/workflows/release.yml` is the **Developer ID pipeline**: certificate
installation, hardened runtime, notarization (`notarytool`), stapling,
Gatekeeper verification (`spctl`), Sparkle EdDSA appcast generation and
publishing. It fails loudly when secrets are missing.

To switch to it, replace `.github/workflows/release.yml` with that file once
these secrets exist (GitHub → Settings → Secrets and variables → Actions):

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `CERTIFICATE_PASSWORD` | `.p12` password |
| `APPLE_ID` | Apple ID for `notarytool` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` |
| `APPLE_TEAM_ID` | Team ID for `notarytool` |
| `SPARKLE_ED25519_PRIVATE_KEY` | base64 of the Sparkle Ed25519 private key |

`Support/workflows/ci.yml` is a mirror of the active `ci.yml` kept with the
templates for reference.

## Release tags

Release tags must match the product version in the project
(`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
`SalmanMacCleaner.xcodeproj/project.pbxproj`), e.g. `v1.2.0`.
Earlier CI revisions published `v1.0.<workflow run number>` tags, which
produced release names (`v1.0.6`, `v1.0.13`) that had no relationship to the
application version (1.2.0). That behaviour has been removed.
