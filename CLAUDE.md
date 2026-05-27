# CLAUDE.md

Operating instructions for Claude when working in this repo.

## Before doing anything

1. Read **`CODEX.md`** at the repo root — the complete architectural reference (data model, providers, screens, design tokens, key algorithms).
2. Read **`docs/pushup-tracker-coding-brief.md`** — the original product/design spec. Don't skim.
3. Read **`AGENTS.md`** — the short rules summary.

If a requirement is ambiguous, ask before guessing. A wrong assumption costs more than a clarification.

## What this app is

**Push.** — a Flutter daily pushup tracker shipping to Android and iOS. Single codebase, dark-first Vercel/Geist aesthetic, Riverpod for state, Isar for persistence. The brand name is `Push.` *with the period* — never drop it.

## Stack lock-in (non-negotiable)

Flutter • Dart strict • Riverpod 2.x • go_router • Isar • fl_chart • flutter_animate • lucide_icons • very_good_analysis.

Do not introduce alternative packages (no Provider, no Cupertino widgets, no Material 3 purple). If the stack seems wrong, raise it before changing.

## Architecture boundary

**Widgets → Providers → Repositories → Isar.** Widgets never `import 'package:isar/...'` or call `isar.*` directly. Everything goes through a Riverpod provider that depends on a repository.

## Mandatory conventions

| Rule | Why |
|---|---|
| Use `localDateKey(dateTime)` from `lib/data/repositories/date_key.dart` for any date string. Never format dates inline. | Single source of truth for the `yyyy-MM-dd` local-tz key that `DayLog.date` indexes on. |
| Read time via `ref.read(clockProvider)()`. Never call `DateTime.now()` directly in feature code. | Lets tests inject a fixed clock. Existing tests assume this. |
| Use `context.colors` (`PushColorTokens`) for any color. Never hardcode hex outside `lib/app/theme/colors.dart`. | Theme tokens drive light/dark switching. |
| Use `PushTypography.monoNumber(...)` for all numeric displays. | Brand requires Geist Mono for numbers — rep counts, streaks, stats, timestamps. |
| Use motion constants from `lib/app/theme/motion.dart`. | Vercel "feels right" because of consistent timing. |
| Icons only via `lucide_icons` (or Material outline icons where lucide doesn't apply). No emojis in UI. | Brand. |
| `DayLog.goal` is immutable per day. Changing `Profile.currentGoal` must not retroactively alter past days. | Streak integrity. |
| Brand text is `Push.` with the period everywhere it appears as the app name. | Brand. |

## Before every commit

```bash
flutter analyze     # must pass
flutter test        # must pass
```

Conventional commits only: `feat:` / `fix:` / `chore:` / `refactor:` / `test:` / `style:` / `docs:`. Never push to `main` without explicit user authorization.

## Code generation

After editing any `@collection` class in `lib/data/db/entities/`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated `*.g.dart` files are committed.

## Android build quirks (require manual fix on fresh machines)

These are documented in `README.md` → "Current Notes":

1. **`isar_flutter_libs` 3.1.0+1** is missing `namespace` (AGP 8+ requirement) and pins `compileSdk 30` (too low for transitive AndroidX deps). After any clean `flutter pub get`, patch `~/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/build.gradle` — set `namespace 'dev.isar.isar_flutter_libs'` and `compileSdkVersion 36`.
2. **`flutter_local_notifications`** requires core library desugaring. `android/app/build.gradle.kts` enables `isCoreLibraryDesugaringEnabled = true` and pulls in `com.android.tools:desugar_jdk_libs`. Don't remove either.

If a Gradle build fails on a fresh machine, check those two before debugging anything else.

## Don't do

- Ship pseudocode or `// TODO: implement later`. Working code or it isn't done.
- Add features outside the brief's MVP scope without explicit approval.
- Use `setState` for app state. Riverpod only.
- Use `Provider` (the package) or any other state library.
- Use Cupertino widgets on iOS — single visual language across both platforms.
- Use stock Material 3 purple — fully override via `ColorScheme`.
- Skip motion. Restraint is the point, not absence.
- Drop the period from `Push.` anywhere it appears as branding.
- Run `flutter clean` to "fix" a build issue without diagnosing the root cause — it nukes Gradle/Pub caches and often triggers re-downloading the NDK (~3GB) and re-patching the isar workaround.

## Testing expectations

- Unit tests for everything in `lib/domain/services/` — especially `StreakCalculator` (midnight, timezone edges, missed days) and `StatsCalculator`.
- Repository tests use a real in-memory Isar (see `test/data/repositories/repository_test.dart`). Never mock Isar.
- Widget tests for `ProgressRing`, `QuickAddRow`, onboarding flow.
- Aim 70%+ coverage on `lib/domain/` and `lib/data/`. Don't chase coverage in `lib/presentation/`.

## Host split: this Windows machine is for editing, MacBook is for running

This repo lives on two hosts:

- **Windows (this machine):** primary development surface — editing code, running the systems reviewer agent, reading/searching the codebase, committing. **Flutter SDK is not installed** and disk space is tight (see `memory/reference_toolchain.md`). Do not try to run `flutter analyze`, `flutter test`, `flutter run`, or any emulator from here.
- **MacBook (separate host):** the test rig. Flutter SDK + Android/iOS emulators are already set up there. The user runs `flutter analyze`, `flutter test`, and the app there.

What this means for Claude on the Windows host:

1. **Don't install Flutter / Dart / Android system images / AVDs.** If a task seems to require them, stop and confirm with the user.
2. **Don't run `flutter ...` commands.** They will fail. Recommend the user run them on the MacBook instead.
3. **Do** still write code that would pass `flutter analyze` and the test suite — the user will validate on the MacBook before pushing.
4. **Never `git push`** from this host unless the user explicitly asks. Default workflow is: commit on Windows, user tests on MacBook, user pushes from whichever host once green.

If the user asks Claude to "run the app" or "fire up an emulator" from the Windows host, surface this constraint and offer to either (a) prepare the change for them to test on the MacBook, or (b) ask whether they want to install the full Flutter toolchain on Windows after all.
