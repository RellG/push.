# Agent Instructions for Push.

## Project
This is **Push.** — a Flutter daily pushup tracker shipping to Android and iOS.
Full spec lives in `docs/BRIEF.md`. Read it before doing anything.

## Rules
- Read `docs/BRIEF.md` fully before writing code. No skimming.
- If a requirement is ambiguous, ask before guessing.
- Follow the Build Order at the bottom of the brief. One step at a time.
- Commit after each completed Build Order step. Conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `style:`.
- Run `flutter analyze` and `flutter test` before each commit. They must pass.
- Test changes on both Pixel emulator and iPhone simulator at meaningful checkpoints.
- Never ship pseudocode or `// TODO: implement later`. Working code or it isn't done.
- The brand name is `Push.` with the period. Don't drop it anywhere it appears as branding.
- Default to dark mode. Use Geist Sans / Geist Mono. Vercel-style motion (see brief §Design Language).

## Stack lock-in
Flutter • Dart strict • Riverpod 2.x • go_router • Isar • fl_chart • flutter_animate • lucide_icons.
Don't introduce alternatives. If you think the brief is wrong about the stack, ask first.
