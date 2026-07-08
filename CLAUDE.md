# CLAUDE.md

Operating instructions for Claude when working in this repo.

## Before doing anything

1. Read **`CODEX.md`** at the repo root — the complete architectural reference (data model, providers, screens, design tokens, key algorithms).
2. Read **`docs/pushup-tracker-coding-brief.md`** — the original product/design spec. Don't skim.
3. Read **`AGENTS.md`** — the short rules summary.

If a requirement is ambiguous, ask before guessing. A wrong assumption costs more than a clarification.

## What this app is

**Push.** — a Flutter daily pushup tracker shipping to Android, iOS, and the web (Render static site). Single codebase, dark-first Vercel/Geist aesthetic, Riverpod for state, Firebase (anonymous auth + Firestore with offline persistence) for data. The brand name is `Push.` *with the period* — never drop it.

## Stack lock-in (non-negotiable)

Flutter • Dart strict • Riverpod 2.x • go_router • Firebase (firebase_auth anonymous + cloud_firestore) • fl_chart • flutter_animate • lucide_icons • very_good_analysis.

(History: v1 used Isar → no web support → migrated to sembast 2026-07 → migrated to Firebase/Firestore days later, with the user's approval, to get accounts-less per-user cloud storage and an admin view. sembast remains only to migrate pre-Firebase local data — see `lib/data/firestore/legacy_migration.dart`.)

Do not introduce alternative packages (no Provider, no Cupertino widgets, no Material 3 purple). If the stack seems wrong, raise it before changing.

## Architecture boundary

**Widgets → Providers → Repositories → Firestore.** Widgets never import `cloud_firestore` or touch the database directly. Everything goes through a Riverpod provider that depends on a repository. Users sign in anonymously (`signedInUserProvider`); all data lives under `users/{uid}` and is guarded by `firestore.rules`.

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
| Web-incompatible plugins (`path_provider`, notifications) must never be imported on the web code path — use conditional imports like `lib/data/db/database_factory_io.dart` / `database_factory_web.dart`. | The web app must keep building. |
| Brand text is `Push.` with the period everywhere it appears as the app name. | Brand. |

## Before every commit

```bash
flutter analyze     # must pass
flutter test        # must pass
```

Conventional commits only: `feat:` / `fix:` / `chore:` / `refactor:` / `test:` / `style:` / `docs:`. Never push to `main` without explicit user authorization.

## Build quirks (fresh machines)

1. **`lucide_icons` 0.257.0** was published before Flutter made `IconData` a `final class` (Flutter 3.27+), so it won't compile unpatched. After a fresh `flutter pub get`, run `python3 scripts/patch_lucide_icons.py` (idempotent; the Render build script runs it automatically). The patch survives `flutter pub get`; it only needs re-applying after `dart pub cache repair`/`clean`.
2. **`flutter_local_notifications`** requires core library desugaring on Android. `android/app/build.gradle.kts` enables `isCoreLibraryDesugaringEnabled = true` and pulls in `com.android.tools:desugar_jdk_libs`. Don't remove either.

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
- Repository tests use `FakeFirebaseFirestore` from `fake_cloud_firestore` (see `test/data/repositories/repository_test.dart`). Never mock the database by hand.
- Widget tests for `ProgressRing`, `QuickAddRow`, onboarding flow.
- Aim 70%+ coverage on `lib/domain/` and `lib/data/`. Don't chase coverage in `lib/presentation/`.

## Hosts

A Linux cloud dev box (`/home/tktechfirm/push`) is now the primary dev + web-deploy surface: Flutter 3.44.5 / Dart 3.12.2 installed at `~/sdk/flutter`, analyze/test/`flutter build web` all run there. Render deploys from GitHub via `render.yaml`. The older Windows/MacBook split below still applies to mobile builds:

- **Windows (this machine):** primary development surface — editing code, running the systems reviewer agent, reading/searching the codebase, committing. **Flutter SDK is not installed** and disk space is tight (see `memory/reference_toolchain.md`). Do not try to run `flutter analyze`, `flutter test`, `flutter run`, or any emulator from here.
- **MacBook (separate host):** the test rig. Flutter SDK + Android toolchain are set up there (confirmed green on **Flutter 3.44.0 / Dart 3.12.0**: debug APK builds, analyze clean, all 23 tests pass). The user runs `flutter analyze`, `flutter test`, and the app there.
  - **Android emulator is the working run target.** There is a ready AVD named **`push_pixel`** (Android SDK 36). To run the app on the MacBook: `flutter emulators --launch push_pixel`, wait for boot (`adb wait-for-device` then `getprop sys.boot_completed` == 1), then `flutter run -d emulator-5554 --debug`. Confirmed working: the app installs, launches `com.tktechnology.push/.MainActivity`, and renders the Home screen. The `isarworker ... avc: denied` SELinux lines in logcat are benign emulator noise, not bugs. Note the app follows the system theme, so a light-mode emulator shows the app in light (toggle with `adb shell cmd uimode night yes` to see the dark-first brand look).
  - **iOS builds are NOT yet possible on the MacBook.** Status as of 2026-06-06: **CocoaPods is now installed** (1.16.2 via Homebrew), but **full Xcode is still not installed** — only Xcode Command Line Tools. The user is blocked on an **Apple ID billing issue** before they can download Xcode (~15 GB) from the App Store, so iOS is deferred. `flutter run`/`build` for any iPhone or iOS simulator will fail until full Xcode is installed and activated (`sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch`). Don't propose iOS device/sim runs until then. iOS bundle id is `com.tktechnology.push`; signing team is not yet configured. See README → "Private iOS testing".

What this means for Claude on the Windows host:

1. **Don't install Flutter / Dart / Android system images / AVDs.** If a task seems to require them, stop and confirm with the user.
2. **Don't run `flutter ...` commands.** They will fail. Recommend the user run them on the MacBook instead.
3. **Do** still write code that would pass `flutter analyze` and the test suite — the user will validate on the MacBook before pushing.
4. **Never `git push`** from this host unless the user explicitly asks. Default workflow is: commit on Windows, user tests on MacBook, user pushes from whichever host once green.

If the user asks Claude to "run the app" or "fire up an emulator" from the Windows host, surface this constraint and offer to either (a) prepare the change for them to test on the MacBook, or (b) ask whether they want to install the full Flutter toolchain on Windows after all.

## Production state (as of 2026-07-08)

The app is **live** at **https://bussdown.space** (canonical; Cloudflare-proxied custom domain) and https://push-sm51.onrender.com (legacy URL, same Render static site, auto-deploys on push to `main`). Backend is Firebase project **`push-d9e0b`** (owned by the user's Google account):

- **Anonymous auth** on first launch (zero-friction by design — the user explicitly does not want visitors to need an email) with **optional Google linking** in Settings → Profile (`linkWithPopup` on web, `linkWithProvider` on native; same uid, data preserved) and **Google sign-in on the onboarding screen** for returning users. Anonymous accounts are per-origin: switching domains or reinstalling the iOS PWA starts fresh unless the user linked Google.
- **Firestore** `users/{uid}` tree with offline persistence; `firestore.rules` (deploy with `~/.npm-global/bin/firebase deploy --only firestore:rules`) restricts each user to their own data.
- **Admin/monitoring** = Firebase console (Authentication tab for users, Firestore tab for their data). This is how the user watches friends' pushup counts — don't build a custom admin UI without being asked.
- Every serving domain (`bussdown.space`, `www.bussdown.space`, `push-sm51.onrender.com`) must be in Firebase Auth **authorized domains** or Google sign-in breaks with "The requested action is invalid". Verify the live allowlist without console access via `curl 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig?key=<web apiKey>'`.
- Firebase client keys in the repo are **public by design**; never treat them as leaked secrets. Real secrets still never go in the repo.
- Avoid Firestore queries that combine a `where` filter with `orderBy` on another field — they demand composite indexes and crash in production (`failed-precondition`). Filter server-side, sort small result sets client-side.
- PWA icons (`web/icons/`, white pushup figure on black) are the approved brand mark; regenerate with PIL if needed and reuse for native launcher icons when mobile builds happen.
- `web/index.html` carries the **TK Core monitoring tracker** (the user's own client-site dashboard at console.tktechnology.org). Keep the script tag when touching the web shell; it fires one view per app load.

## Post-v1 roadmap (not yet in scope)

Done from the original roadmap: cloud storage, accounts (anonymous + Google linking), cross-device data retrieval. Still **out of scope without the user re-confirming**:

1. **Social** — a shared leaderboard shipped 2026-07-08 (`leaderboard/{uid}` public-stats docs, synced client-side by `leaderboardSyncProvider`; board readable by any signed-in user, entries writable only by their owner). Further social (challenges, friends) still needs a green light.
2. **Native store releases** — Android APK/Play and iOS TestFlight (blocked on Xcode install; see Hosts). Add SHA-1 fingerprints to Firebase before Android Google sign-in.
3. **Monetization** — subscription tier; needs server-side receipt validation.

Decisions already made (don't re-litigate, don't build unprompted):

- **AI/Gemini: declined for now** (2026-07-08). If ever revisited, the agreed toe-in-the-water is a weekly coach recap via Firebase AI Logic on the Gemini free tier — nothing else.
- **Daily reminder notifications: deferred to the native-build milestone.** Use `flutter_local_notifications` (already a dependency, desugaring configured) — NOT Cloud Functions/FCM, which would force the Blaze plan. Nothing in the data model needs a midnight reset; days are date-keyed and streaks are computed client-side.
- **Firebase Analytics: skipped** — TK Core + the Firebase console already cover the user's monitoring needs.

Known improvement backlog the user has already seen (pick up when asked): link-Google nudge banner for anonymous users, offline first-launch screen, new-version reload toast, cap stats reads at last 365 days, restrict the web API key to known domains.
