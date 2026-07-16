# Device E2E checklist + Flutter release config — Design

**Date**: 2026-07-17
**Issue**: [#6](https://github.com/aidgoc/pockterm/issues/6)
**Status**: Approved (design), pending implementation plan

## Problem

Two things CI can't cover: (1) a manual on-device end-to-end test of the app, and
(2) release-build configuration — the Android release build currently signs with the
**debug** key (a scaffolding TODO), the `pubspec` still says "A new Flutter project.",
and the Android app label is "app". Store submission is unconfigured.

This change does the parts achievable without secrets/accounts/a device, and documents
the rest as explicit hand-offs.

## Current state (verified)

- `app/pubspec.yaml`: `name: app` (the **Dart package name** — used by every
  `package:app/...` import, so it must NOT change), `description: "A new Flutter
  project."`, `version: 1.0.0+1`.
- `app/android/app/build.gradle.kts`: `namespace`/`applicationId = one.pockterm.app`;
  `release { signingConfig = signingConfigs.getByName("debug") }` (TODO).
- `app/android/app/src/main/AndroidManifest.xml`: `android:label="app"`.
- No `.gitignore` entry for keystores / `key.properties`.

## Deliverables (doable now)

### A. `docs/DEVICE-E2E-CHECKLIST.md`
A checkbox manual-QA script with expected results:
1. Install backend (`python -m pockterm`), QR prints.
2. App scans QR → pairs (pinned TLS) → live shell appears.
3. Run `ls`, `echo`, a long-running command; output streams.
4. Session: create a 2nd session, switch tabs, kill one.
5. Key bar: Esc, Ctrl-C (interrupt), arrows (history), `|`, `/`.
6. Resize/fit: rotate device / resize; prompt reflows.
7. Reconnect: background the app ~30s, foreground → session resumes (replay), status
   returns to "connected".
8. Expiry re-pair (#2): restart the backend (rotates the token) → app shows the
   "Session expired" banner on the Pair screen → rescan → live shell.
9. Security spot-check: a second phone that never scanned the QR cannot connect.

### B. Android release signing (non-breaking) — `app/android/app/build.gradle.kts`
Adopt Flutter's standard `key.properties` pattern:
- Load `android/key.properties` if it exists (into a `Properties` object).
- If present → define a `release` `signingConfig` from those values and use it for the
  release build type.
- If absent → keep the current debug-signing fallback so `flutter build/run` still
  works today with zero secrets. Keystore + passwords are never committed.

### C. `docs/RELEASE.md`
The hand-off guide:
- Generate a keystore: `keytool -genkey -v -keystore …/pockterm-release.jks -keyalg
  RSA -keysize 2048 -validity 10000 -alias pockterm`.
- `key.properties` template (storeFile/storePassword/keyAlias/keyPassword).
- Build commands: `flutter build apk --release`, `flutter build appbundle --release`
  (Play), `flutter build ipa --release` (App Store).
- Version mapping: `pubspec version: X.Y.Z+N` → Android `versionName=X.Y.Z`,
  `versionCode=N`; bump per release.
- App icons: add `flutter_launcher_icons` (dev dep) with a source
  `assets/icon/pockterm.png`, then `dart run flutter_launcher_icons`. **Needs a logo
  asset (hand-off).**
- Store submission: Play Console (create app, upload AAB, listing) and App Store
  Connect (Xcode signing with an Apple Developer account, archive, upload). **Accounts
  + certs are hand-offs.**
- iOS display name / bundle id (`one.pockterm.app`): set in Xcode; signing is manual.

### D. Cosmetic config
- `app/pubspec.yaml`: `description:` → "pockterm — your computer's terminal, on your
  phone." (Do NOT touch `name:`.)
- `app/android/app/src/main/AndroidManifest.xml`: `android:label="pockterm"`.
- `.gitignore`: add `**/key.properties`, `*.jks`, `*.keystore`.

## Verification

- `flutter analyze` stays clean.
- Best-effort `flutter build apk --release` on the dev Mac to prove the gradle change
  builds via the debug fallback (no `key.properties` present). If the Android SDK is
  not configured on this machine, this becomes a documented user check in `RELEASE.md`
  rather than a hard gate.

## Explicit hand-offs (cannot be done here)

- Creating/owning the keystore + filling `key.properties` (secrets).
- Providing an app-icon source image (logo).
- Apple Developer Program + Google Play Console accounts, certificates, store
  listings, and the actual submission.
- Running the device E2E on a real phone.

## Non-goals

- No Dart/app-logic or backend changes.
- No renaming of the Dart package (`name: app` stays — renaming breaks all imports).
- No committing of any secret or generated binary.
