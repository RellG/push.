# Coding Agent Brief — Push.

A daily pushup tracker for Android and iOS, built in Flutter.

---

## Project Identity
- **App display name**: `Push.` (the period is part of the brand — render it everywhere the name appears)
- **Project directory**: `push_app`
- **Dart package name**: `push_app`
- **Application ID (Android)**: `com.tktechnology.push`
- **Bundle Identifier (iOS)**: `com.tktechnology.push`
- **Organization**: TK Technology

---

## Project Setup — DO THIS FIRST

**Do not use Android Studio's native "New Project" wizard.** That scaffolds a Kotlin/Compose Android-only app, which will not ship to iOS. This project is **Flutter**.

### Prerequisites
- macOS (required for iOS builds)
- Flutter SDK (`brew install --cask flutter`)
- Android Studio with the **Flutter** and **Dart** plugins installed
- Xcode (from the Mac App Store) for iOS compilation
- `sudo xcode-select --install` run once
- `flutter doctor` returns no blocking errors

### Create the project
```bash
flutter create \
  --org com.tktechnology \
  --project-name push_app \
  --platforms=android,ios \
  push_app

cd push_app
open -a "Android Studio" .
```

### First commit before touching code
```bash
git init
git add .
git commit -m "chore: initial Flutter scaffold for Push."
```

Then proceed to the Build Order at the bottom of this brief.

---

## How to Work with This Brief
- **Read the entire brief before writing code.** No exceptions.
- **If a requirement is ambiguous, ask before guessing.** A wrong assumption is more expensive to undo than a clarification.
- **Commit after each completed step in the Build Order** with conventional-commit messages (`feat:`, `fix:`, `chore:`, `refactor:`, `style:`).
- **Never ship pseudocode or `// TODO: implement later`.** Each step lands working, tested code or it isn't done.
- **Test on both platforms at every checkpoint** — Pixel emulator and iPhone simulator. A bug on either is a bug.

---

## Role
You are a senior mobile engineer. Build a production-quality cross-platform mobile app for tracking daily pushup goals. Ship working code. Use **Flutter** so a single codebase serves both Android and iOS, developed in **Android Studio** with the Flutter and Dart plugins.

---

## Product

**Concept**: Daily pushup tracker. The user sets a daily pushup goal (e.g., 100 reps). They log sets throughout the day. The day is marked "completed" only when the goal is met. Streaks reward consistency. Inspired by Hevy, Strong, and habit-tracker apps — fast logging, zero friction, satisfying feedback.

**One-line pitch**: *"Push. Hit your daily pushup goal. Build the streak. That's it."*

---

## Core User Flows
1. **First launch** → onboarding (name, daily goal, theme) → home
2. **Home** → progress ring (current / goal), big "+ Add Set" button, today's sets list, current streak badge
3. **Logging** → tap quick buttons (+5, +10, +20) or custom input → instant update with spring animation + haptic
4. **Goal hit** → progress ring fills, gradient sweep celebration, day marked complete, streak ticks up
5. **History** → calendar heatmap (GitHub contributions style), tap a day for breakdown
6. **Stats** → total pushups, longest streak, weekly average, max single set, 7/30/90-day line chart
7. **Settings** → adjust goal, toggle theme, export data as JSON

---

## Tech Stack (non-negotiable)
- **Framework**: Flutter (latest stable 3.x) + Dart
- **IDE**: Android Studio with Flutter + Dart plugins
- **State management**: Riverpod 2.x (no `setState` for app state, no Provider)
- **Navigation**: `go_router`
- **Local DB**: Isar (fast, type-safe, modern)
- **Preferences**: `shared_preferences` (theme, onboarding-complete flag)
- **Charts**: `fl_chart`
- **Animations**: built-in `AnimationController` + `flutter_animate` for declarative chains
- **Haptics**: `HapticFeedback` (built-in) — light impact on quick-add, success on goal complete
- **Notifications**: `flutter_local_notifications` (for daily reminder)
- **Fonts**: Geist Sans + Geist Mono — self-host in `assets/fonts/`, declare in `pubspec.yaml`
- **Icons**: `lucide_icons` package (matches the Vercel/Geist web aesthetic)
- **Lint**: `very_good_analysis` with strict rules

---

## Design Language — Vercel / Geist
Mimic Vercel's aesthetic precisely: clean, monochrome, mechanical, restrained. This is the entire visual identity. Get this wrong and the product fails.

### Typography
- **Geist Sans** for all UI text
- **Geist Mono** for numbers (rep counts, streaks, dates, stats) — numbers must feel monospaced, mechanical, satisfying
- Headlines: heavy weight, tight tracking (`letterSpacing: -0.4`)
- Body: regular weight, normal tracking
- Sizes: 32 / 24 / 18 / 14 / 12 scale

### Color (default to dark mode)
```
Dark:
  background     #000000
  surface        #0A0A0A
  surfaceAlt     #171717
  border         #262626
  textPrimary    #FAFAFA
  textMuted      #A1A1AA
  accent gradient: #0070F3 → #7928CA → #FF0080   (completion moments only)

Light:
  background     #FFFFFF
  surface        #FAFAFA
  surfaceAlt     #F4F4F5
  border         #E4E4E7
  textPrimary    #0A0A0A
  textMuted      #71717A
  accent gradient: same as dark, used sparingly
```

### Motion (critical — Vercel "feels right" because of motion)
- **Default curve**: `Curves.easeOutCubic`, 200–300ms
- **Spring feedback** on press: scale to 0.97, spring back (stiffness ~400, damping ~30 equivalent)
- **Progress ring**: animate stroke from old → new over 600ms easeOutCubic
- **Number counter**: tween old → new over 400ms (no jumpy text)
- **Page transitions**: 250ms fade + 8px y-translate
- **Goal completion**: gradient sweep across ring + light confetti burst + success haptic — brief, tasteful, never childish
- **Quick-add buttons**: spring scale + selection haptic
- **60fps everywhere** — profile and fix any jank on mid-range Android (Pixel 4a class)

### Layout
- 8px grid system (every padding/margin is a multiple of 8)
- Generous whitespace, max content width on tablets (~600px)
- Card surfaces with 1px borders and 12px radius max — sharp, not pillowy
- Bottom nav on mobile (Home / History / Profile)
- Edge-to-edge rendering, transparent status bar

### Brand application: rendering "Push."
- App display name everywhere: `Push.` with the period
- Splash screen wordmark: `Push.` in Geist Sans, heavy weight, tight tracking, the period rendered in the accent gradient
- App icon: bold lowercase `p.` or filled `Push.` wordmark on solid black, period gradient-filled; supply adaptive icon for Android and 1024×1024 master for iOS

---

## Data Model (Isar)
```dart
@collection
class PushupSet {
  Id id = Isar.autoIncrement;
  late int reps;
  late DateTime loggedAt;
  String? note;
}

@collection
class DayLog {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String date;          // ISO yyyy-MM-dd, user's local timezone
  late int goal;             // goal at time of day (immutable per day)
  late int totalReps;
  DateTime? completedAt;
  List<int> setIds = [];
}

@collection
class Profile {
  Id id = Isar.autoIncrement;
  late String name;
  late int currentGoal;
  late String themeMode;     // 'light' | 'dark' | 'system'
  late DateTime createdAt;
}
```

---

## Architecture
```
lib/
  main.dart
  app/
    app.dart                 // MaterialApp.router + theme
    router.dart              // go_router config
    theme/
      colors.dart
      typography.dart
      motion.dart            // shared curves, durations
  features/
    onboarding/
    home/
    history/
    stats/
    settings/
  data/
    db/                      // Isar schemas + DAOs
    repositories/            // SetRepository, DayRepository, ProfileRepository
  domain/
    models/
    services/                // StreakCalculator, StatsCalculator
  presentation/
    widgets/                 // ProgressRing, QuickAddRow, StreakBadge, HeatmapCalendar, StatCard
  providers/                 // Riverpod providers (todayProvider, streakProvider, statsProvider)
```

**Strict separation**: widgets never touch Isar directly — always go through repository → provider → widget.

---

## Testing Requirements
- **Unit tests** for every service in `domain/services/` — especially `StreakCalculator` (midnight rollover, timezone edges, missed days) and `StatsCalculator`
- **Repository tests** with an in-memory Isar instance
- **Widget tests** for `ProgressRing`, `QuickAddRow`, and the onboarding flow
- **Golden tests** for the home screen in both light and dark themes
- `flutter test` must pass before any milestone commit
- Aim for 70%+ coverage on `domain/` and `data/`; don't chase coverage in `presentation/`

---

## Acceptance Criteria

### MVP (must ship)
1. Onboarding flow captures goal + name, persists to Isar, never shown again
2. Home shows live-updating progress ring synced to today's total reps
3. Quick-add buttons (+5, +10, +20) and custom input log to today's `DayLog`
4. Sets list scrollable, swipe-to-delete with undo snackbar
5. Streak calculated correctly across midnight, timezone-aware (device local time)
6. Goal completion triggers celebration animation + sets `DayLog.completedAt`
7. History calendar shows last 12 months, cell color intensity by % of goal hit
8. Stats screen shows total, max set, longest streak, line chart for 7/30/90 days
9. Settings: change goal, toggle theme, export JSON
10. Both dark and light themes pixel-perfect
11. Empty states, loading states, and error states all designed — not placeholders
12. App icon and splash screen render `Push.` brand correctly on both platforms

### Stretch (only after MVP is solid)
- Rest timer between sets
- Daily reminder notification at user-chosen time
- Multiple exercises (extend data model — same engine for pull-ups, squats)
- Cloud sync (don't build it; architect repos so a remote source can swap in cleanly later)
- Share card generation (today's progress rendered as an image)

---

## Quality Bar
- Dart strict mode, no dynamic typing
- Responsive at 360px width minimum
- Accessibility: semantic labels on all icon buttons, WCAG AA contrast
- Tested on both Pixel emulator and iPhone simulator
- Cold launch < 2s on mid-range Android
- Zero layout jumps, zero animation jank
- README with: setup steps, architecture overview, design rationale, build commands for both platforms

---

## What NOT to do
- **Don't use Android Studio's native New Project wizard** — that's Android-only Kotlin. Use `flutter create`.
- Don't use stock Material 3 purple — fully override via `ColorScheme`
- Don't use Cupertino widgets on iOS — single visual language across both platforms
- Don't use emojis in the UI — Lucide icons only
- Don't add features outside MVP without explicit approval
- Don't skip motion — restraint is the point, not absence
- Don't write pseudocode or `// TODO: implement later` — ship working code
- Don't introduce additional state management on top of Riverpod
- Don't drop the period from `Push.` anywhere it appears as the brand

---

## Deliverables
1. Working Flutter project that boots on both platforms via `flutter run`
2. README with setup, architecture, and design decisions
3. Seeded demo data toggle for screenshots
4. Build instructions for Android APK and iOS TestFlight
5. App icons and splash screens configured for both platforms
6. Screenshot set: home (light + dark), history, stats, onboarding

---

## Build Order
Commit after each step.

1. `flutter create` scaffold + `pubspec.yaml` dependencies + Geist fonts wired
2. Theme system (`colors.dart`, `typography.dart`, `motion.dart`)
3. Isar setup + repositories + unit tests
4. Riverpod providers (today, streak, stats)
5. Onboarding flow
6. **Home screen — progress ring + quick add** (the centerpiece — polish hardest here)
7. Streak + goal-completion logic + celebration animation
8. History calendar
9. Stats screen
10. Settings
11. App icon + splash screen for both platforms (Push. wordmark)
12. Polish pass: motion timing, haptics, empty states, both themes verified pixel-perfect
13. README + screenshots + build instructions
