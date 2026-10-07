# Distribution Architecture

8002CleanUp is designed as a **direct-distribution** macOS utility with
two possible editions. The repository implements the direct edition as the
primary target.

## Direct distribution (primary — implemented)

- Developer ID signed (Hardened Runtime enabled, never disabled for file access)
- Apple notarized + stapled (`notarytool`, `stapler`, `spctl` verification in CI)
- Sparkle 2 self-updates with EdDSA-signed appcast (see `Docs/SparkleSetup.md`)
- Full Disk Access onboarding flow (user grants access in System Settings;
  the app never grants itself permission)
- Deepest supported scan with honest coverage reporting
- **App Sandbox is disabled for this edition.** App Sandbox cannot be combined
  with full-disk maintenance: a sandboxed process cannot reach `~/Library`,
  other volumes or protected locations even when the user grants Full Disk
  Access, so scans silently degrade. The direct-distribution build therefore
  ships without `ENABLE_APP_SANDBOX` and without
  `com.apple.security.app-sandbox`; Hardened Runtime stays **enabled**, and
  `Tools/validate_project.py` fails the build if the sandbox is switched back
  on. Protected locations are still only read after the user grants Full Disk
  Access through the normal TCC flow.

## Mac App Store (documented alternative — not the implemented target)

A future App Store edition would keep:

- App Sandbox with user-selected file access
- Security-scoped bookmarks for persistent folder choices
- Reduced cleanup scope (no privileged operations, no Sparkle)
- Store-managed updates

The current entitlements (`SalmanMacCleaner.entitlements`) are compatible
with the App Store edition except for Sparkle; releasing there would mean
removing the Sparkle package reference and adding security-scoped bookmark
handling for persisted custom scopes.

## Privileged cleanup helper — intentionally not implemented

Version 1 performs **no privileged cleanup**. If a future version needs it,
the documented constraints are:

- A narrowly scoped, separately signed helper registered through
  `SMAppService` and spoken to over XPC
- Structured operations only (a path + expected identity + allowlist rule),
  never arbitrary commands or shell strings
- The helper independently validates every path against a compiled allowlist
- Privileged cleanup is disabled automatically when signing requirements
  are unavailable

## Signing status today

| Item | Status |
| --- | --- |
| Debug/unsigned builds (CI) | Working — `CODE_SIGNING_ALLOWED=NO` |
| Ad-hoc development signing | Working (default Xcode) |
| Developer ID certificate | **Required from the maintainer** (GitHub secret) |
| Notarization credentials | **Required from the maintainer** (GitHub secrets) |
| Sparkle EdDSA key | **Required from the maintainer** (generated locally) |
| Release workflow | Implemented; fails loudly until secrets exist |
