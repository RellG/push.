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

`lucide_icons` is included as required by the brief, but version `0.257.0` does not compile on the current Flutter SDK because it extends Flutter's final `IconData` class. The app avoids importing it until a compatible package version is available.
