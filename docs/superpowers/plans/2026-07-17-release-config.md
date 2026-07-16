# Device E2E Checklist + Release Config — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual device-E2E checklist, non-breaking Android release signing, a release/publishing guide, and cosmetic app metadata — doing everything achievable without secrets/accounts/a device and documenting the rest as hand-offs.

**Architecture:** Pure docs + Android Gradle config + cosmetic tweaks. Android release signing adopts Flutter's standard `key.properties` pattern with a debug-signing fallback so current builds keep working with no secrets. No Dart or backend changes.

**Tech Stack:** Markdown, Android Gradle (Kotlin DSL), Flutter tooling.

**Repo:** `~/pockterm`, branch `fix/6-release-config` (spec committed).

---

## File Structure

| File | Change |
|---|---|
| `app/android/app/build.gradle.kts` | Load optional `key.properties`; `release` signing with debug fallback |
| `.gitignore` | Ignore keystores + `key.properties` |
| `app/pubspec.yaml` | Fix `description` (NOT `name`) |
| `app/android/app/src/main/AndroidManifest.xml` | `android:label` → `pockterm` |
| `docs/DEVICE-E2E-CHECKLIST.md` | New — manual QA script |
| `docs/RELEASE.md` | New — signing + build + store hand-off guide |

---

## Task 1: Android release signing (non-breaking) + gitignore

**Files:**
- Modify: `app/android/app/build.gradle.kts`
- Modify: `.gitignore`

- [ ] **Step 1: Ignore secrets first** — append to `.gitignore`:
```
# Android release signing (never commit)
**/key.properties
*.jks
*.keystore
```

- [ ] **Step 2: Replace `app/android/app/build.gradle.kts` entirely with:**
```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing: create android/key.properties (gitignored) to sign
// release builds. If absent, release falls back to debug signing so local
// `flutter run/build` keeps working with no secrets.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "one.pockterm.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "one.pockterm.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
```

- [ ] **Step 3: Verify the Dart analyzer is still clean** (gradle change is invisible to it, but confirms nothing else broke)

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Best-effort release build (proves the debug fallback compiles)**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter build apk --release 2>&1 | tail -15`
Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`.
**If the Android SDK/Java toolchain is not configured on this machine** (error like "No Android SDK found" / "Unable to locate Android SDK"), that is acceptable here — record it as DONE_WITH_CONCERNS and note that release-build verification is deferred to `RELEASE.md` for the user to run. Do NOT install the Android SDK.

- [ ] **Step 5: Confirm no keystore/props got staged**

Run: `cd /Users/harshwardhangokhale/pockterm && git status --porcelain | grep -E "key.properties|\.jks|\.keystore" && echo "SECRET STAGED — stop" || echo "no secrets staged"`
Expected: `no secrets staged`.

- [ ] **Step 6: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add app/android/app/build.gradle.kts .gitignore && git commit -m "build(android): optional key.properties release signing, debug fallback (#6)"
```

---

## Task 2: Cosmetic metadata

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Fix the pubspec description** (do NOT change `name: app`)

In `app/pubspec.yaml`, change:
```yaml
description: "A new Flutter project."
```
to:
```yaml
description: "pockterm — your computer's terminal, on your phone."
```

- [ ] **Step 2: Set the Android app label**

In `app/android/app/src/main/AndroidManifest.xml`, change:
```xml
android:label="app"
```
to:
```xml
android:label="pockterm"
```

- [ ] **Step 3: Verify + analyze**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm/app && grep -q 'android:label="pockterm"' android/app/src/main/AndroidManifest.xml \
  && grep -q "terminal, on your phone" pubspec.yaml && flutter analyze
```
Expected: `No issues found!` (and both greps match silently).

- [ ] **Step 4: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add app/pubspec.yaml app/android/app/src/main/AndroidManifest.xml && git commit -m "chore(app): real description + 'pockterm' app label (#6)"
```

---

## Task 3: Device E2E checklist

**Files:**
- Create: `docs/DEVICE-E2E-CHECKLIST.md`

- [ ] **Step 1: Write `docs/DEVICE-E2E-CHECKLIST.md`:**
````markdown
# Pockterm — Device E2E Checklist

Manual acceptance test that CI can't run. Needs: a Mac/Windows computer running the
backend and a real Android/iOS phone with the pockterm app, **on the same Wi-Fi**.

Mark each step pass/fail. Expected result is in _italics_.

## Setup
- [ ] `python -m pockterm` on the computer → _a QR code prints; "pockterm on https://<lan-ip>:8422"_.
- [ ] Open the pockterm app on the phone → _Pair screen with camera + instructions_.

## Pairing (pinned TLS)
- [ ] Scan the QR → _app pairs and shows a live shell prompt within a couple seconds_.
- [ ] (Optional) Point the app at a wrong/self-signed server → _connection refused (cert pin mismatch)_.

## Shell
- [ ] Type `ls` / `echo hi` → _output streams back correctly_.
- [ ] Run something long (`ping -c 5 8.8.8.8` / `for i in 1 2 3; do echo $i; sleep 1; done`) → _output arrives incrementally, not all at once_.

## Sessions
- [ ] Tap **+** → create a second session → _new tab appears, fresh prompt_.
- [ ] Switch between tabs → _each shows its own scrollback_.
- [ ] Kill a session from the menu → _tab disappears; "[session ended]" if it was active_.

## Key bar
- [ ] `Esc`, `Tab` → _behave in a TUI (e.g. `vi`, tab-completion)_.
- [ ] `^C` interrupts a running command → _returns to prompt_.
- [ ] Arrows → _command history / cursor movement_.
- [ ] `|`, `/`, `~` → _typed literally_.

## Resize / fit
- [ ] Rotate the phone / resize → _the terminal reflows; `tput cols` reflects the new width_.

## Reconnect
- [ ] Background the app ~30s, then foreground → _session resumes with replayed scrollback; status returns to "connected"_.
- [ ] Toggle Wi-Fi off/on briefly → _status shows "reconnecting…" then "connected" (up to 3 tries)_.

## Expiry re-pair (issue #2)
- [ ] Restart the backend (`Ctrl-C`, re-run `python -m pockterm`) → this rotates the pairing token.
- [ ] On the phone → _within a few seconds the app returns to the Pair screen with an orange "Session expired — scan to reconnect" banner_.
- [ ] Rescan the new QR → _back to a live shell_.

## Security spot-check
- [ ] From a **second** phone that never scanned the QR, try to reach `https://<lan-ip>:8422` → _no shell; pairing requires the QR token_.

---
Record device model, OS version, and app/backend versions with the run.
````

- [ ] **Step 2: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add docs/DEVICE-E2E-CHECKLIST.md && git commit -m "docs: device E2E manual QA checklist (#6)"
```

---

## Task 4: Release/publishing guide

**Files:**
- Create: `docs/RELEASE.md`

- [ ] **Step 1: Write `docs/RELEASE.md`:**
````markdown
# Pockterm — App Release Guide

The app builds/analyzes clean in debug. This is the checklist to produce signed
release builds and submit to the stores. Items marked **(you)** need secrets or
accounts and cannot be automated in this repo.

## 1. Versioning
`app/pubspec.yaml` `version: X.Y.Z+N` drives both platforms:
- Android `versionName = X.Y.Z`, `versionCode = N` (must increase every Play upload).
- iOS `CFBundleShortVersionString = X.Y.Z`, `CFBundleVersion = N`.
Bump it per release.

## 2. Android signing **(you)**
1. Generate a keystore (keep it safe & backed up — losing it locks you out of updates):
   ```bash
   keytool -genkey -v -keystore ~/pockterm-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias pockterm
   ```
2. Create `app/android/key.properties` (gitignored — never commit):
   ```properties
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=pockterm
   storeFile=/absolute/path/to/pockterm-release.jks
   ```
3. `app/android/app/build.gradle.kts` already picks this up automatically: when
   `key.properties` exists the release build is signed with it; otherwise it falls
   back to debug signing.

## 3. Android build
```bash
cd app
flutter build apk --release        # sideload / direct install
flutter build appbundle --release  # Play Store (AAB)
```
Outputs under `app/build/app/outputs/`.

## 4. App icons **(needs a logo asset)**
1. Add a 1024×1024 PNG at `app/assets/icon/pockterm.png`.
2. Add dev dependency + config to `app/pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.14.1
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icon/pockterm.png"
   ```
3. `cd app && dart run flutter_launcher_icons`.

## 5. iOS **(you — Apple Developer account)**
- Open `app/ios/Runner.xcworkspace` in Xcode.
- Set the display name to "pockterm" and confirm the bundle id `one.pockterm.app`.
- Signing & Capabilities → select your Team (automatic signing).
- `flutter build ipa --release` → upload the `.ipa` via Xcode Organizer / Transporter.

## 6. Store submission **(you)**
- **Google Play:** create the app in Play Console, upload the AAB, complete the
  listing (title, description, screenshots, privacy policy), roll out.
- **App Store:** create the app in App Store Connect, upload the build, complete the
  listing, submit for review.

## 7. Privacy note for listings
Pockterm is a **remote-shell** client. Both stores will ask about data use: it
transmits terminal I/O over the local network to a server the user controls; it does
not collect analytics or personal data. Disclose the LAN/network usage and the
full-shell capability honestly.
````

- [ ] **Step 2: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add docs/RELEASE.md && git commit -m "docs: release + store submission guide (#6)"
```

---

## Task 5: Final verification

**Files:** none.

- [ ] **Step 1: Analyzer + suite unaffected**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm/app && flutter analyze && flutter test 2>&1 | tail -2
```
Expected: `No issues found!`; tests pass (5 passed — the existing app tests).

- [ ] **Step 2: Scope — no Dart/backend logic changed**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && git diff --name-only main...HEAD | grep -E "\.dart$|^pockterm/" && echo "CODE CHANGED — unexpected" || echo "no app/backend code changed"
```
Expected: `no app/backend code changed` (only gradle, manifest, pubspec metadata, gitignore, docs).

- [ ] **Step 3: No secrets committed**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && git log main..HEAD --name-only | grep -E "key.properties|\.jks|\.keystore" && echo "SECRET COMMITTED — stop" || echo "no secrets committed"
```
Expected: `no secrets committed`.

---

## Notes for the implementer

- Do NOT change `app/pubspec.yaml` `name: app` — it is the Dart package name behind every `package:app/...` import.
- Do NOT create a real keystore or `key.properties`, and do NOT install the Android SDK. The gradle change must keep the debug fallback so builds work with zero secrets.
- The two docs are the primary deliverable; keep them accurate to the actual app behavior (session tabs, key bar, reconnect, #2 expiry banner).
- Hand-offs the user must complete are called out inline in `RELEASE.md` with **(you)** and **(needs a logo asset)**.
