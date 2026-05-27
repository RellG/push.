# CODEX — Push.

Complete technical reference for the Push. Flutter app. Read this before writing any code.

---

## Project Identity

| Field | Value |
|---|---|
| Display name | `Push.` (period is part of the brand — never drop it) |
| Package name | `push_app` |
| Android app ID | `com.tktechnology.push` |
| iOS bundle ID | `com.tktechnology.push` |
| Organization | TK Technology |
| Version | `1.0.0+1` |
| Dart SDK | `^3.12.0` |

---

## What It Does

Push. is a daily pushup tracker for Android and iOS. The user sets a daily rep goal, logs sets throughout the day, and the day is marked complete when the goal is hit. Streaks reward consecutive completed days. The UX is fast, frictionless, and satisfying — Vercel/Geist aesthetic all the way down.

**Core flows:**
1. First launch → onboarding (name + goal + theme) → stored in Isar + SharedPreferences → never shown again
2. Home → animated progress ring, quick-add buttons (+5/+10/+20 + custom), today's sets list, streak badge
3. Goal hit → gradient sweep celebration + haptic + `DayLog.completedAt` stamped
4. History → GitHub-style heatmap of last 365 days, tap a cell to see day breakdown
5. Stats → total reps, longest streak, weekly avg, max set, 7/30/90-day line chart
6. Settings → change goal, toggle theme, export all data as JSON

---

## Tech Stack

| Concern | Library |
|---|---|
| Framework | Flutter (Material 3) |
| Language | Dart strict mode |
| State management | `flutter_riverpod ^2.6.1` |
| Navigation | `go_router ^17.2.3` |
| Local database | `isar ^3.1.0+1` + `isar_flutter_libs` |
| Preferences | `shared_preferences ^2.5.5` |
| Charts | `fl_chart ^1.2.0` |
| Animations | `flutter_animate ^4.5.2` + `AnimationController` |
| Notifications | `flutter_local_notifications ^21.0.0` |
| Icons | `lucide_icons ^0.257.0` |
| Fonts | Geist Sans + Geist Mono (self-hosted in `assets/fonts/`) |
| Lint | `very_good_analysis ^10.2.0` |
| Code generation | `isar_generator ^3.1.0+1` + `build_runner ^2.4.13` |

**Hard rule:** do not introduce alternative packages. If a package seems wrong, raise it before changing.

---

## Directory Structure

```
lib/
├── main.dart                         # Entry point — edge-to-edge, transparent bars, runApp
├── app/
│   ├── app.dart                      # PushApp (ProviderScope) → _PushMaterialApp
│   ├── router.dart                   # GoRouter, AppRoutes constants, _fadePage transition
│   └── theme/
│       ├── colors.dart               # PushColorTokens (ThemeExtension) + context.colors
│       ├── typography.dart           # PushTypography.textTheme(), PushTypography.monoNumber()
│       ├── motion.dart               # PushMotion constants (curves, durations, pressedScale)
│       └── theme.dart                # PushTheme.dark() / PushTheme.light()
├── data/
│   ├── db/
│   │   ├── push_database.dart        # openPushDatabase(), pushSchemas list
│   │   └── entities/
│   │       ├── day_log.dart          # @collection DayLog
│   │       ├── day_log.g.dart        # generated
│   │       ├── profile.dart          # @collection Profile
│   │       ├── profile.g.dart        # generated
│   │       ├── pushup_set.dart       # @collection PushupSet
│   │       └── pushup_set.g.dart     # generated
│   └── repositories/
│       ├── date_key.dart             # localDateKey(DateTime) → 'yyyy-MM-dd' (local tz)
│       ├── day_repository.dart       # DayRepository — find, watch, getOrCreate, findRange
│       ├── profile_repository.dart   # ProfileRepository — get, watch, save, updateGoal, updateTheme
│       └── set_repository.dart       # SetRepository — addSet (atomic w/ day update), findSetsForDay, deleteSet
├── domain/
│   ├── models/
│   │   ├── chart_point.dart          # ChartPoint { date: String, value: int }
│   │   └── push_stats.dart           # PushStats (all computed stats, PushStats.empty sentinel)
│   └── services/
│       ├── streak_calculator.dart    # StreakCalculator — currentStreak, longestStreak
│       └── stats_calculator.dart    # StatsCalculator — calculate(days, sets, today) → PushStats
├── features/
│   ├── onboarding/
│   │   └── onboarding_screen.dart    # Name + goal + theme picker, calls completeOnboardingProvider
│   ├── home/
│   │   └── home_screen.dart          # Progress ring + quick-add + sets list + celebration overlay
│   ├── history/
│   │   └── history_screen.dart       # HeatmapCalendar + bottom-sheet day drill-down
│   ├── stats/
│   │   └── stats_screen.dart         # 4-cell stat grid + segmented range picker + line chart
│   └── settings/
│       └── settings_screen.dart      # Goal input, theme toggle, export JSON, seed demo data
├── presentation/
│   └── widgets/
│       ├── app_bottom_nav.dart       # NavigationBar — Home / History / Stats (index 0/1/2)
│       ├── progress_ring.dart        # Custom-painted animated ring + tweened number counter
│       ├── quick_add_row.dart        # +5/+10/+20 buttons + custom text field row
│       ├── heatmap_calendar.dart     # 365-day grid, color by goal %, tap to select day
│       └── goal_celebration_layer.dart  # Full-screen overlay — sweep arc + particles, triggered by key
└── providers/
    └── app_providers.dart            # All Riverpod providers (see Provider Map below)

assets/
├── fonts/
│   ├── Geist.ttf
│   └── GeistMono.ttf
└── brand/
    ├── push_icon_master.png
    ├── push_icon_foreground.png
    └── push_launch_wordmark.png

test/
├── data/repositories/repository_test.dart
├── domain/services/
│   ├── streak_calculator_test.dart
│   └── stats_calculator_test.dart
├── features/onboarding/onboarding_screen_test.dart
├── presentation/widgets/
│   ├── progress_ring_test.dart
│   └── quick_add_row_test.dart
└── widget_test.dart
```

---

## Data Model

### `PushupSet`
Individual set within a day.

| Field | Type | Notes |
|---|---|---|
| `id` | `Id` | auto-increment |
| `reps` | `int` | validated > 0 in `SetRepository.addSet` |
| `loggedAt` | `DateTime` | timestamp of the log |
| `note` | `String?` | optional annotation |

### `DayLog`
One record per calendar day (keyed by local date string).

| Field | Type | Notes |
|---|---|---|
| `id` | `Id` | auto-increment |
| `date` | `String` | unique index, `'yyyy-MM-dd'` local tz via `localDateKey()` |
| `goal` | `int` | goal at time of first set — immutable per day |
| `totalReps` | `int` | running sum, maintained atomically by `SetRepository` |
| `completedAt` | `DateTime?` | stamped on the set that crosses the goal threshold |
| `setIds` | `List<int>` | ordered list of `PushupSet.id`s for this day |

### `Profile`
Singleton — only one row ever exists.

| Field | Type | Notes |
|---|---|---|
| `id` | `Id` | auto-increment |
| `name` | `String` | user's display name |
| `currentGoal` | `int` | current daily target |
| `themeMode` | `String` | `'dark'` \| `'light'` \| `'system'` |
| `createdAt` | `DateTime` | first onboarding timestamp |

**Key invariant:** `DayLog.goal` is frozen when the day is created. Changing `Profile.currentGoal` does not retroactively alter past days. `SetRepository.addSet` passes the current goal only when creating a new `DayLog`.

---

## Navigation

Defined in `lib/app/router.dart`. All routes use a 250ms fade + 3% y-translate transition (`_fadePage`).

| Route constant | Path | Screen |
|---|---|---|
| `AppRoutes.root` | `/` | `_LaunchScreen` (spinner while checking onboarding) |
| `AppRoutes.onboarding` | `/onboarding` | `OnboardingScreen` |
| `AppRoutes.home` | `/home` | `HomeScreen` |
| `AppRoutes.history` | `/history` | `HistoryScreen` |
| `AppRoutes.stats` | `/stats` | `StatsScreen` |
| `AppRoutes.settings` | `/settings` | `SettingsScreen` |

**Redirect logic:** `/` always redirects — to `/onboarding` if `onboardingCompleteProvider` is false, otherwise to `/home`. All other paths are direct.

Bottom nav (`AppBottomNav`) covers indices 0/1/2 = Home/History/Stats. Settings is pushed from Stats via `context.push(AppRoutes.settings)`.

---

## Provider Map

All providers live in `lib/providers/app_providers.dart`.

### Infrastructure

| Provider | Type | What it gives |
|---|---|---|
| `clockProvider` | `Provider<DateTime Function()>` | Injectable clock — always use instead of `DateTime.now()` directly |
| `todayDateProvider` | `StreamProvider<String>` | Today's date key, e.g. `'2026-05-25'`; re-emits across midnight and on app resume |
| `isarProvider` | `FutureProvider<Isar>` | Singleton Isar instance |
| `sharedPreferencesProvider` | `FutureProvider<SharedPreferences>` | Singleton prefs instance |

### Repositories

| Provider | Type |
|---|---|
| `profileRepositoryProvider` | `FutureProvider<ProfileRepository>` |
| `dayRepositoryProvider` | `FutureProvider<DayRepository>` |
| `setRepositoryProvider` | `FutureProvider<SetRepository>` |

### App state

| Provider | Type | What it gives |
|---|---|---|
| `onboardingCompleteProvider` | `FutureProvider<bool>` | Whether onboarding has been completed |
| `profileProvider` | `StreamProvider<Profile?>` | Live profile stream |
| `themeModeProvider` | `Provider<ThemeMode>` | Derived from `profileProvider` |
| `todayProvider` | `StreamProvider<DayLog?>` | Today's `DayLog` (live) |
| `todaySetsProvider` | `FutureProvider<List<PushupSet>>` | Sets for today's `DayLog` |
| `allDaysProvider` | `StreamProvider<List<DayLog>>` | All day logs (live) |
| `allSetsProvider` | `StreamProvider<List<PushupSet>>` | All sets (live) |
| `streakProvider` | `Provider<AsyncValue<int>>` | Current streak count |
| `statsProvider` | `Provider<AsyncValue<PushStats>>` | All computed stats |

### Actions (callable providers)

| Provider | Signature | What it does |
|---|---|---|
| `completeOnboardingProvider` | `CompleteOnboarding` typedef | Saves profile + sets onboarding flag + invalidates providers |
| `logSetProvider` | `LogSet` typedef | Calls `SetRepository.addSet` then invalidates today/all caches |
| `exportJsonProvider` | `Future<String> Function()` | Serializes profile + days + sets as pretty JSON |
| `seedDemoDataProvider` | `Future<void> Function()` | Writes 90 days of fake data (dev/demo only) |

**Cache invalidation pattern:** after any write, the action provider manually calls `ref.invalidate(...)` on the affected downstream providers. There is no automatic cascade.

---

## Design System

### Colors (`lib/app/theme/colors.dart`)

`PushColorTokens` is a `ThemeExtension<PushColorTokens>`. Access anywhere via `context.colors`.

| Token | Dark | Light | Usage |
|---|---|---|---|
| `background` | `#000000` | `#FFFFFF` | Scaffold background |
| `surface` | `#0A0A0A` | `#FAFAFA` | Cards, inputs |
| `surfaceAlt` | `#171717` | `#F4F4F5` | Heatmap empty cells, nav indicator, tooltip bg |
| `border` | `#262626` | `#E4E4E7` | Card borders, input borders, dividers |
| `textPrimary` | `#FAFAFA` | `#0A0A0A` | Primary text, active icons |
| `textMuted` | `#A1A1AA` | `#71717A` | Labels, timestamps, secondary info |
| `accentStart` | `#0070F3` | same | Gradient start (blue) |
| `accentMid` | `#7928CA` | same | Gradient mid (purple) |
| `accentEnd` | `#FF0080` | same | Gradient end (pink) |

Accent gradient is only used for completion moments (celebration overlay, heatmap completion cell).

### Typography (`lib/app/theme/typography.dart`)

- `Geist` (sans) — all UI text
- `GeistMono` — all numbers: rep counts, streaks, dates, stats

`PushTypography.textTheme()` defines the full `TextTheme`. Use `PushTypography.monoNumber(color, fontSize)` for any numeric display outside the standard text roles.

Scale: `32 / 24 / 18 / 14 / 12` — nothing else.

### Motion (`lib/app/theme/motion.dart`)

| Constant | Value | Used for |
|---|---|---|
| `defaultCurve` | `Curves.easeOutCubic` | Almost everything |
| `fast` | `200ms` | Button press, quick transitions |
| `pageTransition` | `250ms` | Route fade+slide |
| `medium` | `300ms` | General UI |
| `counter` | `400ms` | Number tween (rep counter) |
| `progress` | `600ms` | Progress ring stroke |
| `pressedScale` | `0.97` | Quick-add button press spring |

---

## Key Algorithms

### `localDateKey(DateTime)` — `lib/data/repositories/date_key.dart`
Converts any `DateTime` to a `'yyyy-MM-dd'` string in the device's **local** timezone. Always use this for date keying — never call `.toUtc()` or format manually.

### `StreakCalculator.currentStreak`
Walks backwards from today. If today is not complete, starts from yesterday (streak is still alive today as long as yesterday was complete). Stops at the first gap.

### `StreakCalculator.longestStreak`
Sorts the set of completed date strings, then counts the longest run of consecutive days (where consecutive means `difference.inDays == 1`).

### `SetRepository.addSet` — atomic write
Single `isar.writeTxn` that:
1. Gets or creates today's `DayLog` with the current goal
2. Writes the `PushupSet`
3. Updates `DayLog.totalReps` and `setIds`
4. Stamps `DayLog.completedAt` on the set that first crosses the goal (never overwrites if already stamped)

### `SetRepository.deleteSet` — atomic write
Single `isar.writeTxn` that:
1. Reads the set to find its date
2. Decrements `DayLog.totalReps`, removes from `setIds`
3. Clears `DayLog.completedAt` if the new total falls below goal
4. Deletes the `PushupSet` record

---

## Screen Reference

### `OnboardingScreen`
- `ConsumerStatefulWidget`
- Fields: name (text), goal (number, default 100), theme (segmented button: dark/light/system)
- Validates then calls `completeOnboardingProvider` → navigates to `/home`
- Accepts optional `onCompleted` callback (used in widget tests)

### `HomeScreen`
- `ConsumerStatefulWidget`
- Holds a `GlobalKey<GoalCelebrationLayerState>` — listens to `todayProvider` changes, fires `.play()` on the celebration layer when `completedAt` transitions from null → non-null
- `_hasSeenToday` flag prevents spurious celebration on initial load
- Layout: `Stack` — `CustomScrollView` (header + progress ring + quick-add + sets list) over `GoalCelebrationLayer`

### `HistoryScreen`
- `ConsumerWidget`
- Renders `HeatmapCalendar` with all days + today
- Tap → `showModalBottomSheet` showing date, total reps, and % of goal

### `StatsScreen`
- `ConsumerStatefulWidget` (holds `_StatsRange` enum state for the chart picker)
- 2×2 `GridView` stat cards + `SegmentedButton` for 7/30/90 days + `_LineChart`
- Settings icon in header pushes to `/settings`

### `SettingsScreen`
- `ConsumerStatefulWidget`
- Sections: Goal (inline edit + save), Theme (segmented button — auto-saves), Data (export JSON + seed demo)
- Export copies JSON to clipboard and opens an `AlertDialog` showing the raw JSON

---

## Widget Reference

### `ProgressRing`
Custom-painted ring with `TweenAnimationBuilder` for the progress arc (600ms) and a separate tween for the center number (400ms). Uses `_ProgressRingPainter` (CustomPainter). Semantic label: "Daily pushup progress, X of Y".

### `QuickAddRow`
Row of `+5`, `+10`, `+20` `OutlinedButton`s + a custom text field. Each press triggers `HapticFeedback.lightImpact`, shows an `AnimatedScale` press state (0.97), then resets after `PushMotion.fast`.

### `HeatmapCalendar`
Horizontally scrollable (reversed, so latest week is rightmost). 12×12px cells, 4px gap between cells/weeks. Color mapping via 5-level intensity scale using `Color.lerp` through accent gradient. Empty padding cells fill the first partial week.

### `GoalCelebrationLayer`
`StatefulWidget` with `SingleTickerProviderStateMixin`. Imperatively triggered via public `play()` method and a `GlobalKey`. Renders a `CustomPaint` overlay (sweep arc + 16 particles radiating outward) over 1.1 seconds. `IgnorePointer` wraps it so it never blocks input.

### `AppBottomNav`
Thin wrapper around `NavigationBar`. Three destinations. `onDestinationSelected` uses `context.go(...)` (replaces stack, not push).

---

## Testing

Tests live in `test/` mirroring the `lib/` structure.

| File | What it covers |
|---|---|
| `test/domain/services/streak_calculator_test.dart` | currentStreak (today complete, today incomplete, gap) + longestStreak |
| `test/domain/services/stats_calculator_test.dart` | StatsCalculator output |
| `test/data/repositories/repository_test.dart` | ProfileRepository CRUD, SetRepository atomic writes, delete, goal completion stamp |
| `test/features/onboarding/onboarding_screen_test.dart` | Onboarding widget flow |
| `test/presentation/widgets/progress_ring_test.dart` | ProgressRing widget |
| `test/presentation/widgets/quick_add_row_test.dart` | QuickAddRow widget |

Repository tests use a real Isar instance in a temp directory (downloaded with `Isar.initializeIsarCore(download: true)` in `setUpAll`). Never mock Isar.

Run before every commit:
```bash
flutter analyze
flutter test
```

---

## Build Commands

```bash
# Dev
flutter run                         # runs on connected device/emulator

# Android
flutter build apk --release
flutter build appbundle --release   # for Play Store

# iOS
flutter build ios --release
# then open ios/Runner.xcworkspace in Xcode to archive

# Code generation (after editing Isar entities)
dart run build_runner build --delete-conflicting-outputs
```

---

## Conventions

- **Architecture boundary:** widgets → providers → repositories → Isar. Widgets never import `isar` or call `isar.*` directly.
- **Date keys:** always use `localDateKey(dateTime)` from `lib/data/repositories/date_key.dart`. Never format dates inline.
- **Clock injection:** always read time via `ref.read(clockProvider)()`. Never call `DateTime.now()` in feature code — this makes the clock testable.
- **Theming:** always use `context.colors` (`PushColorTokens`) for color. Never hardcode color literals outside `colors.dart`.
- **Numbers:** always render with `PushTypography.monoNumber(...)`. Never use Geist Sans for numeric displays.
- **No emojis in UI:** use `lucide_icons` only.
- **No dynamic types:** Dart strict mode throughout.
- **Brand name:** `Push.` with the period, everywhere the app name appears visually.
- **Commit style:** `feat:` / `fix:` / `chore:` / `refactor:` / `test:` / `style:`