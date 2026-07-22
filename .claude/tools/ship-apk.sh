#!/bin/zsh
# Build the Android app split-per-abi and upload the arm64-v8a APK as a
# GitHub release asset named pockterm.apk. Split is mandatory: the unsplit
# APK (~66MB) exceeds Telegram's 50MB bot limit; arm64 alone is ~24MB.
# Usage: ship-apk.sh <tag>     e.g. ship-apk.sh v0.1.3   (release must already exist)
set -euo pipefail
TAG="$1"
ROOT="${0:A:h}/../.."
cd "$ROOT/app" && flutter build apk --release --split-per-abi
APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
gh release upload "$TAG" "$APK#pockterm.apk"
