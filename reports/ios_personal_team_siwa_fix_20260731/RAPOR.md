# iOS personal team — SIWA unblock (2026-07-31)

## Problem

`flutter run` / device provision fail on Personal Team (`NGT6U64563`, "selcuk sezer"):

- Personal teams do not support Sign In with Apple
- Profile missing SIWA capability
- Missing `com.apple.developer.applesignin` entitlement match

Bundle: `com.gkk.gkkFlutter`

## Fix (local / personal team)

| Item | Change |
|------|--------|
| `ios/Runner/Runner.entitlements` | Removed `com.apple.developer.applesignin` (empty dict) |
| `CODE_SIGN_ENTITLEMENTS` | Unchanged — still `Runner/Runner.entitlements` (Debug/Release/Profile) |
| Dart `sign_in_with_apple` | Left as-is; login UI already gates via `SignInWithApple.isAvailable()` (device support). Without entitlement, Apple sign-in will fail at ASAuthorization even if button shows on real iOS |

## Production SIWA (later)

Needs **paid Apple Developer Program** + capability on App ID + entitlement restored in `Runner.entitlements` + profile regen. Personal free team cannot ship SIWA.
