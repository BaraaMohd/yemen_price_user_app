# Release Checklist (Outside Play Store) - User App

## 1. Update version

In `pubspec.yaml`, increase version:

- `version: x.y.z+N`
- `N` (versionCode) must be higher than previous release.

## 2. Build signed APK

```bash
flutter pub get
flutter build apk --release --flavor user -t lib/main.dart
```

Output:
- `build/app/outputs/flutter-apk/app-user-release.apk`

## 3. Generate checksum

```bash
sha256sum build/app/outputs/flutter-apk/app-user-release.apk > build/app/outputs/flutter-apk/app-user-release.apk.sha256
```

## 4. Publish GitHub Release

Upload both files:
- `app-user-release.apk`
- `app-user-release.apk.sha256`

## 5. Verify update compatibility

- Same package name: `com.pricepulse.yemen`
- Same signing key as previous releases
- Higher versionCode than installed version

