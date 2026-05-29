# Push.

Push. is a Flutter daily pushup tracker for Android and iOS. The app focuses on one fast loop: set a daily goal, log sets throughout the day, complete the goal, and keep the streak alive.

## Stack

- Flutter 3.x and Dart strict analysis
- Riverpod 2.x for app state
- go_router for navigation
- Isar for local persistence
- shared_preferences for onboarding/theme flags
- fl_chart for stats charts
- flutter_animate and AnimationController-based motion
- Geist Sans and Geist Mono self-hosted in `assets/fonts/`

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

The generated Isar files are committed. Re-run `build_runner` after changing any `@collection` model in `lib/data/db/entities/`.

## Architecture

- `lib/app/`: app shell, router, theme, motion, typography, color tokens
- `lib/data/`: Isar collections, database opener, repositories
- `lib/domain/`: stats and streak calculation services
- `lib/providers/`: Riverpod providers and app actions
- `lib/features/`: onboarding, home, history, stats, settings screens
- `lib/presentation/widgets/`: shared UI widgets such as the progress ring and heatmap

Widgets do not touch Isar directly. Screens call providers, providers call repositories, and repositories own database writes.

## Design

Push. uses a dark-first Vercel/Geist treatment: black background, bordered surfaces, restrained monochrome UI, Geist Sans for interface text, and Geist Mono for numbers. The accent gradient is reserved for completion and brand moments.

## Demo Data

Open Settings and tap `Seed demo data` to populate recent day logs for screenshots. The seeder skips dates that already have data.

## Build Commands

Android debug APK:

```bash
flutter build apk --debug
```

Android release APK:

```bash
flutter build apk --release
```

iOS local build:

```bash
flutter build ios --release
```

iOS TestFlight archive is created from Xcode:

```bash
open ios/Runner.xcworkspace
```

Then choose `Any iOS Device`, archive, and upload through Organizer.

## Screenshots

Use seeded demo data, then capture:

- Home in dark theme
- Home in light theme
- History heatmap
- Stats dashboard
- Onboarding

## Current Notes

Verified building and green on the MacBook test rig: **Flutter 3.44.0 / Dart 3.12.0** — debug APK builds, `flutter analyze` clean, all 23 tests pass.

### lucide_icons patch (required on every clean machine)

`lucide_icons 0.257.0` is used by onboarding, stats, and settings, but it was published before Flutter 3.27+ made `IconData` a `final class`, so its `class LucideIconData extends IconData` no longer compiles. After a fresh install, patch the pub cache:

- `~/.pub-cache/hosted/pub.dev/lucide_icons-0.257.0/pubspec.yaml` — set the `sdk` constraint to `">=3.3.0 <4.0.0"`.
- `~/.pub-cache/hosted/pub.dev/lucide_icons-0.257.0/lib/lucide_icons.dart` — replace every `const LucideIconData(0x….)` with `IconData(0x…., fontFamily: 'Lucide', fontPackage: 'lucide_icons')`.
- `~/.pub-cache/hosted/pub.dev/lucide_icons-0.257.0/lib/src/icon_data.dart` — replace its body with `typedef LucideIconData = IconData;`.

Unlike the isar Gradle patch below, this one survives `flutter pub get` (pub doesn't overwrite cached Dart sources). It only needs re-applying after `dart pub cache repair` / `dart pub cache clean`.

### Android build: isar_flutter_libs patch

`isar_flutter_libs 3.1.0+1` was published before AGP 8 made `namespace` mandatory and before transitive AndroidX deps required `compileSdk 34+`. After a fresh `flutter pub get`, patch `~/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/build.gradle` so the `android { ... }` block reads:

```gradle
android {
    namespace 'dev.isar.isar_flutter_libs'
    compileSdkVersion 36

    defaultConfig {
        minSdkVersion 21
    }
}
```

Until the Isar maintainers ship a fix (or we vendor a local fork via `dependency_overrides`), this manual edit is required on every clean machine.

### Android build: core library desugaring

`flutter_local_notifications` requires Java 8+ APIs that aren't available on older `minSdk` levels, so `android/app/build.gradle.kts` enables `isCoreLibraryDesugaringEnabled` and pulls in `com.android.tools:desugar_jdk_libs`. Don't remove either line.

## Private iOS testing (before publishing)

Bundle id: `com.tktechnology.push` · display name: `Push.` · deployment target: iOS 13.0.

**Prerequisite — the MacBook needs a full iOS toolchain (not yet installed):** it currently has only Xcode Command Line Tools and no CocoaPods, so any `flutter run`/`build` for an iPhone or simulator will fail. Install once:

```bash
# 1. Install Xcode from the Mac App Store (large download), then point the tools at it:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
# 2. Install CocoaPods:
brew install cocoapods   # or: sudo gem install cocoapods
```

Then pick a path:

### Option A — free, direct from your Mac (solo dev testing)

No paid account needed — a regular Apple ID works.

1. `open ios/Runner.xcworkspace`, select the **Runner** target → **Signing & Capabilities** → check *Automatically manage signing* → choose your personal Apple ID team. (`DEVELOPMENT_TEAM` is not set in the repo yet; this sets it locally.)
2. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (iOS 16+), reboot, and trust the Mac when prompted.
3. Connect the iPhone by USB and run: `flutter run --release -d <device-id>` (`flutter devices` lists ids).
4. First launch: **Settings → General → VPN & Device Management → trust your developer profile.**

Caveat: free provisioning certificates **expire after 7 days** — the app stops launching and must be re-deployed from the Mac weekly. Limited to a few sideloaded apps, and the phone must reach your Mac to reinstall.

### Option B — Apple Developer Program ($99/yr) + TestFlight (recommended)

Best for installing wirelessly, lasting 90 days per build, and adding other testers. You'll need this program to publish to the App Store anyway, so enrolling now is reasonable.

1. Enroll at [developer.apple.com](https://developer.apple.com/programs/).
2. `flutter build ipa` (or archive from `ios/Runner.xcworkspace` → *Any iOS Device* → Product → Archive).
3. Upload to App Store Connect via Xcode Organizer or `xcrun altool`/Transporter.
4. Distribute through **TestFlight**: yourself + up to 100 internal testers (no review) or up to 10,000 external testers (light review). Testers install the TestFlight app and get builds over the air.

(For Android private testing in the meantime: `flutter build apk --release` and sideload the APK, or use Google Play's internal-testing track.)
