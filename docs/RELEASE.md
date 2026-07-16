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
