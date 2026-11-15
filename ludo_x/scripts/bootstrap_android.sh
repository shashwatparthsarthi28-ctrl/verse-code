#!/usr/bin/env bash
# Generates the Android platform project (Gradle files, manifest, launcher icons)
# with your installed Flutter SDK, then applies the LUDO X settings.
# Run once from the project root:  bash scripts/bootstrap_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter SDK not found on PATH (need Flutter 3.27 or newer)."; exit 1; }

flutter create --platforms=android --project-name ludo_x --org com.ludox .
flutter pub get

# Firebase Auth / Firestore need minSdk 23
if [ -f android/app/build.gradle.kts ]; then
  sed -i -E 's/minSdk *= *[^ ]+/minSdk = 23/' android/app/build.gradle.kts
else
  sed -i -E 's/minSdkVersion +[^ ]+/minSdkVersion 23/' android/app/build.gradle
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
grep -q "android.permission.INTERNET" "$MANIFEST" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
sed -i -E 's/android:label="[^"]*"/android:label="LUDO X"/' "$MANIFEST"

echo
dart run flutter_launcher_icons || echo "(launcher icon step skipped)"

echo "Android project ready. Next:"
echo "  flutter run                      # run on a device or emulator"
echo "  flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk"
