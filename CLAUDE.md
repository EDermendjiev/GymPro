# GymPro

Fork of the Flutter gym app GymMane (GPL-3.0, ~95k lines) with an offline
coaching engine added as separate modules. Android first; English only.
Keep the credit "Based on GymMane by InlitX" (see `CREDITS.md`, `test/coach/credit_test.dart`).

## Tools (not on PATH)
- Flutter 3.41.9: `/d/tools/flutter/bin/flutter.bat` (PowerShell: `& "D:\tools\flutter\bin\flutter.bat"`)
- Dart: `/d/tools/flutter/bin/cache/dart-sdk/bin/dart.exe`
- `gh` is not installed. GitHub secrets and settings are the owner's job.

## Commands
- Analyze: `flutter.bat analyze --no-fatal-infos` (must be clean)
- Targeted test first: `flutter.bat test test/coach/<x>_test.dart`
- Full suite (1–2 min, run once before committing): `flutter.bat test --reporter failures-only`
- Package tests: `cd packages/<pkg> && dart.exe test`
- Strings: after editing `lib/l10n/app_en.arb`, run `flutter.bat gen-l10n` and commit the generated files

## Layout
- `packages/coach_*`: pure-Dart engine (kernel, progression, training, recovery, nutrition; `coach_planner` from the
  smart-planner work). The packages are editable like any other code. Keep them pure (no Flutter, I/O, clock or
  randomness). A behaviour change comes with its own test. A changed fixture is a deliberate, named change in the commit, never a side effect.
- `lib/coach/`: the host layer. Only `adapters/`, `facade.dart` and `model/` may import `package:coach_*`.
  The rest of the app uses only the barrel `lib/coach/coach.dart` (`show` lists, `Coach`/`coach`-prefixed names).
- `lib/state/coach_state.dart`: thin mixin. It reads state, calls `CoachFacade`, stores and notifies. No coaching rules here.
- `lib/coach/ui/`: coach widgets. Reuse GymMane's theme, sheets, chips and toasts. No overflow at 360 px width.
- `test/coach/`: all coach tests. `docs/coach/`: ARCHITECTURE (seam table), UPSTREAM (merge playbook), BASELINE.

## Binding rules
- **Seams:** an edit to an upstream GymMane file is 1–3 lines with a `// coach-seam` marker.
  In the same commit, update the map in `test/coach/seam_audit_test.dart` and the seam table in `docs/coach/ARCHITECTURE.md`.
- With a coach module switched off, the app behaves exactly like upstream.
- Never modify upstream tests. Only `test/coach/**` and `test/pending_translation_keys.txt` may change.
- New strings go in `app_en.arb` only, and each new key is also added to `test/pending_translation_keys.txt`. Widgets never hard-code English.
- Every new file starts with `// SPDX-License-Identifier: GPL-3.0-only`.
- Never mention the source material (books, authors, page or chapter citations) or any private reference repo
  in code, comments, strings, docs or commit messages. A purity test in the packages enforces this.
- The in-app name is the `_kAppName` constant in `lib/app/gymmane_app.dart`. `.arb` strings that say "GymMane" stay as they are (upstream tests depend on them).

## Git
- Work on `coach`. `main` mirrors `upstream/main` and moves only by fast-forward. Never commit to it.
- One commit per task, `feat(coach): …` / `fix(coach): …`. Stage paths by name, never `git add -A`.
- Upstream merges: follow `docs/coach/UPSTREAM.md`. The seam audit must stay green.

## Releases
- Push a `gympro-v<x.y.z>` tag on `coach`. `.github/workflows/coach-release.yml` builds per-ABI APKs signed with the KEYSTORE_* repo secrets.
- Phones update only from release-workflow APKs (per-ABI versionCode). Never hand the owner a local universal build as an update.
- The signing key lives outside the repo. Never regenerate it.

## How to work here (keep it cheap)
- Default: do the task inline in this session. No subagents unless a task is truly independent and large.
- Read only the files the task touches. Use Grep/Glob before opening big files (`lib/state/*.dart` are large).
- The engine's behaviour is defined by `packages/coach_*` and their fixture tests. Don't look for other sources.
- Historical plans and handoffs live outside the repo. Don't read them unless asked.
- Done means: analyze clean, full suite green, committed, docs/coach true. Then stop and report briefly.
