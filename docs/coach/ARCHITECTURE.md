<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Coach architecture

GymPro is a fork of GymMane that adds a training and nutrition coach. The
coach is built as independent modules that sit beside the existing app instead
of inside it, so that each module can be switched off, the coaching logic can
be tested without the app, and changes from upstream GymMane keep merging
cleanly.

This document describes the **target architecture**. It is written in the
present tense, but most of what it describes is not built yet. The
[status table](#status) at the end says what exists so far. How to merge
upstream changes is covered in [UPSTREAM.md](UPSTREAM.md).

## Principles

1. **The packages are pure.** They use no Flutter, do no file or network I/O,
   never read the clock and never use randomness. Anything that depends on the
   date or time is passed in as a parameter (`today`, `now`), so the same input
   always produces the same output.
2. **The packages contain no exercise catalog.** The host app passes exercises
   in, so the packages work with any catalog.
3. **Only the adapter layer imports the packages.** `lib/coach/` translates
   between GymMane's types and the packages' types. Screens, widgets and state
   classes never import a coach package.
4. **Existing GymMane files are touched only at the listed seams.** Each seam
   is a change of one to three lines marked `// coach-seam`, and the full list
   is the [seams table](#seams) below. Everything else lives in new files.
5. **Every module has its own switch.** With all switches off, the app behaves
   exactly like upstream GymMane.

## Layers

```
┌──────────────────────── Flutter app (existing GymMane code) ────────────────────────┐
│  screens/  widgets/          state/*.dart (FitState mixins)                          │
│      │                            │   ▲                                              │
│      │  reads `fit.coach…`        │   │ coach seams: no-op virtual methods on        │
│      ▼                            ▼   │ FitCore, overridden by CoachState            │
│  lib/coach/ui/            lib/state/coach_state.dart ── persists one key: "coach"    │
│                                   │                                                  │
│                           lib/coach/  (adapters, host models, autonomy policy)       │
└───────────────────────────────────┼──────────────────────────────────────────────────┘
                                    │ the ONLY place that imports package:coach_*
        ┌───────────────┬───────────┴────────┬──────────────────┬──────────────────┐
        ▼               ▼                    ▼                  ▼                  │
 coach_nutrition   coach_recovery ──► coach_training ──► coach_progression         │
        │               │                    │                  │                  │
        └───────────────┴────────────────────┴──────────────────┴──► coach_kernel ◄┘
                       (pure Dart: no Flutter, no dart:io, no DateTime.now)
```

There are three layers:

- **Packages** hold the coaching rules. They know nothing about GymMane.
- **The adapter layer** (`lib/coach/`) converts GymMane objects into package
  values and package results back into GymMane objects.
- **The state mixin** (`CoachState`) connects the adapter layer to the app's
  state. `FitCore` declares a small set of coach methods that do nothing.
  `CoachState` overrides them. Existing code asks the seam first and falls
  back to its own logic when the seam has no answer, which is always the case
  when the module's switch is off.

## Packages

The packages live under `packages/` and follow the same convention as the
existing `packages/sync`: a path dependency, `publish_to: 'none'`, and their
own tests run with `dart test`.

| Package | Owns | Depends on |
|---|---|---|
| `coach_kernel` | Shared vocabulary: ids and enums, value types with JSON, date and rounding helpers, rule registry, all numeric constants, estimated one-rep max, set counting | nothing |
| `coach_progression` | Rep and effort prescription per exercise type, next-session and next-set load suggestions, training-status inference, warm-up ramp | kernel |
| `coach_training` | Block generation: split choice, volume targets, day placement, exercise selection, set distribution, strength phases, sport trims, carry-over of user edits, one-off session generator | kernel, progression |
| `coach_recovery` | Weekly review, fatigue flags, plateau detection, plan proposals, proposal validation and application (plan diffs) | kernel, progression, training |
| `coach_nutrition` | Calorie and macro targets, weigh-in trend, nutrition review | kernel |
| `coach_testkit` (dev only) | Fixture loader and JSON diff used by the five packages' tests | nothing |

Dependency rules:

- Dependencies point one way only, as in the table. There are no cycles, and
  a package never depends on a package that depends on it.
- `coach_kernel` depends on nothing. Every other coach package depends on it.
- `coach_nutrition` shares only the kernel with the training packages.
- `coach_testkit` is a dev dependency of the five packages. The app does not
  depend on it and it is not shipped.
- No package depends on Flutter or on the app.
- The packages contain no exercise catalog. The host passes exercises in as
  `ExerciseDef` values.

## Host integration

Everything the app adds for the coach is in `lib/coach/` and one state mixin.

```
lib/coach/
  coach.dart                  barrel; the only coach file screens and state import
  facade.dart                 CoachFacade: GymMane types in, GymMane or Coach* types out
  model/coach_data.dart       everything persisted under the "coach" key
  model/coach_profile.dart    goal, status, days, minutes, priority, lifestyle
  model/coach_targets.dart    host values the progression module answers with (CoachRx, CoachSessionTarget, …)
  adapters/muscle_map.dart    16 coach muscles <-> 14 GymMane muscles
  adapters/equipment_map.dart GymMane equipment names -> coach equipment
  adapters/catalog_adapter.dart  Exercise -> ExerciseDef (uses coach_meta)
  adapters/history_adapter.dart  LoggedSession -> kernel LoggedSet
  adapters/exposure_adapter.dart LoggedSession -> one exercise's ExerciseHistory (exposures per session)
  adapters/category_adapter.dart Exercise -> coach Category (fallback guess until coach_meta exists)
  adapters/plan_writer.dart   BlockPlan -> Routine + weeklyPlan
  data/coach_meta.dart        generated: coaching attributes per GymMane exercise id
  policy/autonomy.dart        which proposals apply silently / with undo / on request
  ui/                         onboarding pages, why-sheet, proposal card, settings section
lib/state/coach_state.dart    `part of 'fit_state.dart'`: mixin CoachState
dev/coach_meta_gen.dart       regenerates data/coach_meta.dart
test/coach/                   host-side tests
docs/coach/                   ARCHITECTURE.md, UPSTREAM.md, BASELINE.md
```

### Naming rule for the boundary

The packages and GymMane both define types called `LoggedSet`, and helpers
such as `daysBetween`. Package symbols must therefore never be visible inside
`fit_state.dart` and its parts. The rule has three parts:

- `lib/coach/coach.dart` exports host-side symbols only, using explicit `show`
  lists. Every exported symbol is prefixed `Coach` (or `coach` for functions).
- Package types stay behind `CoachFacade`. The state mixin hands it GymMane
  objects (`LoggedSession`, `Exercise`, `Profile`, `Routine`) and gets back
  GymMane objects or `Coach*` values.
- Only files under `lib/coach/adapters/`, `lib/coach/facade.dart` and
  `lib/coach/model/` import `package:coach_*`.

## Modules and switches

| Module switch | Needs | User-visible effect when on |
|---|---|---|
| `progression` | nothing | Any exercise set to progression kind "Auto" gets coach load and rep targets, a first-set correction, and a reason line. Works on the user's own routines. |
| `plan` | `progression` | A generated block appears as routines in a "Coach" group with a weekly schedule; quick workouts target lagging muscles. |
| `recovery` | `plan` | Weekly review runs from logged data; deloads, swaps and volume changes arrive as proposals. Calendar deloads are superseded. |
| `nutrition` | nothing | Suggested calorie and macro goals come from the coach; weigh-in trend proposes adjustments. Manually set goals always win. |

Switches live in `coach.on` inside the persisted state. An absent `coach` key
means all switches are off. That is the state of every existing GymMane
backup, so restoring an upstream backup changes nothing.

## Seams

A seam is an edit to a file that already exists in GymMane. This table is the
complete list. Each edit is one to three lines and carries the comment
`// coach-seam`. A test, `test/coach/seam_audit_test.dart`, counts the markers
per file against this table, so an unplanned touch point fails CI.

If a change needs to touch an existing file that is not listed here, either
move the code into `lib/coach/` or add a row to this table in the same change.

| File | Seam | Status |
|---|---|---|
| `pubspec.yaml` | five path dependencies | done |
| `lib/state/fit_core.dart` | block of no-op virtual methods (`coachNextPlan`, `coachOpeningSets`, `coachSetLogged`, `coachWarmupSets`, `coachTargetLabel`, `coachWhy`, `coachWeeklySetTarget`, `coachDeloadWeek`, `coachNutritionGoals`) | done |
| `lib/state/fit_state.dart` | import of `lib/coach/coach.dart`, `part`, mixin in the `with` list, one line each in `loadFromStore`, `toJson`, `applyBackup`, `resetAllData` | done |
| `packages/sync/lib/sync.dart` | `coach` merges atomically (newest wins) | done |
| `lib/models/progression.dart` | `ProgressKind.auto` appended at the end of the enum | done |
| `lib/state/workout_state.dart` | `_nextPlan`, `toggleSet`, `nextWhy` and `_warmupFor` each ask the seam first; `_nextPlan` lets Auto fall back to Linear while the progression module is off; `_openingSetsRaw` asks the seam first | done, except `_openingSetsRaw` (planned for the plan module) |
| `lib/widgets/progression_sheet.dart` | "Auto" option: its name, its hint, offered only while the progression module is on (or already chosen), and choosing it stores the coach's rep range | done |
| `lib/screens/session_screen.dart` | import of the barrel; `build` hands the coach's one-shot requests (first-set correction toast with Undo, the effort question) to `coachSessionPrompts`; the coach's target line (`CoachTargetLine`, which opens the why-sheet) right under `_nextRow` | done |
| `lib/screens/onboarding_screen.dart` | two pages inserted in the `PageView` list | planned |
| `lib/screens/home_screen.dart` | coach card slot | planned |
| `lib/state/settings_state.dart` | `deloadWeek` asks the seam first | planned |
| `lib/state/stats_state.dart` | `muscleTargetFor` asks the seam first | planned |
| `lib/state/nutrition_state.dart` | `suggestedGoals` asks the seam first | done |
| `lib/screens/nutrition_screen.dart`, `lib/screens/nutrition/settings.dart` | import of the barrel (for its part `nutrition/settings.dart`); the coach's goals card (`CoachGoalsCard`) under the goals sheet's title | done |
| `lib/screens/settings_screen.dart` | "Coach" category: import of the barrel, the category, its title, its place in the Home group, its section | done |
| `lib/screens/about_screen.dart`, `README.md` | credit line, fork links | done |
| `lib/app/gymmane_app.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/shortcuts.xml`, `ios/Runner/Info.plist`; unmarked: `ios/Runner.xcodeproj/project.pbxproj`, `fastlane/metadata/android/*/title.txt`, `web/index.html`, `web/manifest.json` | app identity (name and application id) | done |
| `lib/l10n/app_en.arb`, `test/pending_translation_keys.txt` | new strings, added as each module needs them | in use (the credit, Settings › Coach) |
| `.github/workflows/coach-ci.yml` | new file, not a seam: analyzer, app tests and package tests on the `coach` branch | done |

Notes on the table:

- The files `lib/l10n/app_localizations*.dart` are generated from the ARB
  files by `flutter gen-l10n` and are committed. They change whenever a string
  is added. They are regenerated, never edited by hand, so they are not seams.
- `test/coach/seam_audit_test.dart` counts the literal text `coach-seam` per
  file (`// coach-seam` in Dart and Kotlin, `# coach-seam` in YAML, an XML
  comment in XML) and compares it with a map of expected counts. Files that
  cannot carry a comment (`README.md`, `lib/l10n/app_en.arb`,
  `test/pending_translation_keys.txt`) are exempt by path, as are the
  generated `lib/l10n/app_localizations*.dart`.

## Persisted state

All coach data is stored under one key, `coach`, in the existing state blob.

```jsonc
"coach": {
  "v": 1,
  "on": { "progression": true, "plan": true, "recovery": true, "nutrition": false },
  "profile": { "goal": "lean_gain", "status": "intermediate", "days": [1,2,4,5], "minutes": 60,
               "priority": "lifting", "lifestyle": "lightly_active", "maxLiftDays": null },
  "sports": [],  "injuries": [],  "disliked": [],
  "soreness": { "2026-11-12": { "hamstrings": "sore" } },
  "block": { /* BlockPlan.toJson(): kind, startsOn, weeks, splitKey, targets, weeklyTargets, sessions, selections */ },
  "routineIds": { "upper_a": "r1731…", "lower_a": "r1731…" },
  "proposals": [ { "id": "…", "kind": "standard_deload", "state": "pending|applied|dismissed", "payload": {}, "undo": {} } ],
  "review": { "lastWeekStart": "2026-11-09", "previousYesCount": 0 },
  "nutrition": { "phase": "gain", "multiplier": 1.65, "kcal": 2990, "lastAdjustOn": null }
}
```

| Key | Holds |
|---|---|
| `v` | Version of this shape |
| `on` | The four module switches |
| `profile` | The user's coaching profile: goal, training status, training days, session length, priority, lifestyle |
| `sports`, `injuries`, `disliked` | Lists the block generator takes into account |
| `soreness` | Soreness reports, by date and muscle |
| `block` | The current generated block, as written by `BlockPlan.toJson()` |
| `routineIds` | The GymMane routine each block session was written to |
| `proposals` | Proposals with their state and the data needed to undo them |
| `review` | Bookkeeping for the weekly review |
| `nutrition` | Current nutrition phase and targets |

Rules for this key:

- An absent key means the coach is off. Existing backups and upstream backups
  have no `coach` key and load unchanged.
- The key is read and written at four places in `FitState` (`loadFromStore`,
  `toJson`, `applyBackup`, `resetAllData`), each a seam.
- In folder sync the whole `coach` value merges atomically: the newest copy
  wins and the two sides are never mixed field by field.
- Reading the key never fails. A part the app cannot read counts as absent,
  and its stored value is kept and written back unchanged until the app
  replaces it. Keys the app does not know (at the top level, in `on` and in
  `profile`) are kept the same way, so data written by a newer version
  survives a round trip through an older one.
- A module whose prerequisite is off counts as off, whatever was stored.
  Switching a module off also switches off the modules that need it.
- The key is left out entirely while the coach holds nothing and every
  switch is off.

## Progression module

With the `progression` switch on, the progression sheet offers a sixth kind,
"Auto". Choosing it stores the rep range the coach prescribes for the
exercise's category (the middle of the category's range). From then on, for
that exercise:

| Where | What the coach does | Through |
|---|---|---|
| NEXT line, opening sets, exercise card | Load and reps for the next session, from the exercise's logged history (deload sessions left out); a changed load is put on the exercise's weight stack or load step | `coachNextPlan` in `_nextPlan` |
| Ticking the first working set | Once per exercise of a workout: a set outside the rep range moves the load of the remaining undone sets by about 4 % per rep; the workout screen shows the app's toast with Undo | `coachSetLogged` in `toggleSet`, `coachSessionPrompts` |
| Same moment | When that set has no effort, the workout screen's effort picker opens once; skipping means "on target" | same |
| Under the NEXT line | The rep and effort range; tapping it opens the why-sheet with the plain-words summary of every rule behind the numbers | `coachTargetLabel`, `CoachTargetLine` |
| NEXT line reason | The coach's reason replaces the stock one | `coachWhy` in `nextWhy` |
| Warm-ups of a compound | The coach's ramp (50, 70 and 85 % of the working load, from 40 kg up) replaces the stock one wherever the app adds warm-ups | `coachWarmupSets` in `_warmupFor` |

The coach leaves timed, cardio, body-weight-only and assisted exercises to the
stock rules, and does nothing when the exercise's progression is switched off.
With the switch off, an Auto exercise progresses like Linear and the sheet no
longer offers Auto for other exercises.

The state cannot open UI, so the first-set correction and the effort question
are queued by `CoachState` and taken by the workout screen in `build`
(`coachSessionPrompts`), which shows them after the frame. Requests belong to
the workout they were made in.

Until the per-exercise coaching attributes exist, the exercise's category is
guessed by `coachCategoryFor` (`lib/coach/adapters/category_adapter.dart`)
from its equipment, primary muscle and name.

## Nutrition module

With the `nutrition` switch on, the app's suggested calorie and macro goals
come from the coach. The module needs no plan and no onboarding: the switch
alone is enough.

| Input | Taken from |
|---|---|
| Bodyweight | the latest weigh-in, else the profile's weight (the app's own `nutritionWeightKg`) |
| Sex | the profile's sex (`male`, `female`; anything else counts as unspecified) |
| Training status | the coaching profile, else novice |
| Phase | the phase the user picked (`coach.nutrition.phase`), else the one that follows from the coaching goal, else maintain |
| Activity band | the profile's activity multiplier, by rank (below) |
| Sports | `coach.sports` |
| Body fat, target rate, logged sport efforts, calorie override | left at the coach's defaults |

The two activity scales are not comparable number for number (the app
multiplies a resting rate built from age and height, the coach one built from
bodyweight only), so only their order is used. The app's four choices, lowest
first, map to the coach's four bands in order: Sedentary (1.2) to sedentary,
Light (1.375) to lightly active, Moderate (1.55) to active, Active (1.725) to
very active. Any other value takes the band of the nearer choice (a tie goes to
the more active one), so anything below Sedentary is sedentary and anything
above Active is very active. The choices are listed in
`lib/coach/adapters/nutrition_adapter.dart`; a test checks them against the
profile screen.

`coachNutritionGoals` answers `suggestedGoals` with the coach's calories,
protein, fat and carbs. Water, fibre, sugar, sodium and glass size are the
app's own suggestion, worked out by the stock code path (the seam stands aside
while `CoachState` asks for it). Goals the user has set by hand always win:
`activeGoals` only asks for the suggestion when none are set.

While the coach supplies the goals in force (module on, no goals of the
user's own), the goals sheet shows the coach's card (`CoachGoalsCard`): "Set
by coach", a reason that opens a sheet with the phase, the bodyweight and
upkeep the targets rest on, the coach's warnings and the plain-words summary of
every rule behind them, and a phase picker (gain, maintain, lose). A picked
phase is stored under `coach.nutrition.phase` and replaces the one that follows
from the coaching goal. Editing any goal in the sheet makes the goals the
user's own. The card then says so and offers "Use coach's goals", noting that
this replaces all of the user's own goals, water and sodium included. That
action (`CoachState.useCoachGoals`) puts the goals back as a fresh install has
them and clears the "set by hand" flag, so the coach's goals are in force
again, rest days included (rest-day goals are dropped too). It writes the existing fields from
`CoachState`, so it needs no seam.

## Muscle and equipment mapping

The packages use 16 muscles and their own equipment names. GymMane uses 14
muscles and its own equipment names. The adapters in `lib/coach/adapters/`
translate in both directions.

### Coach muscle to GymMane muscle

| Coach muscle | GymMane muscle |
|---|---|
| `chest` | chest |
| `back` | back |
| `front_delts`, `side_delts`, `rear_delts` | shoulders |
| `biceps` | biceps |
| `triceps` | triceps |
| `quads` | quads |
| `hamstrings` | hamstrings |
| `glutes` | glutes |
| `calves` | calves |
| `abs` | abdomen |
| `forearms` | forearm |
| `traps` | trapezius |
| `erectors` | lowerback |
| `adductors` | not shown (untracked; it has no weekly target) |

### GymMane muscle to coach muscle

The reverse of the table above, with two additions:

| GymMane muscle | Coach muscle |
|---|---|
| obliques | `abs` |
| shoulders | resolved per exercise, see below |

How `shoulders` is resolved for one exercise:

| Condition | Coach muscle |
|---|---|
| The exercise is annotated in `coach_meta` | the annotated muscle |
| The name contains "press" | `front_delts` |
| The name contains "rear", "reverse" or "face pull" | `rear_delts` |
| Anything else | `side_delts` |

### GymMane equipment to coach equipment

| GymMane equipment | Coach equipment |
|---|---|
| Barbell | `barbell` |
| Dumbbell | `dumbbell` |
| Kettlebell | `dumbbell` |
| Machine | `machine` |
| Cable | `cable` |
| Bodyweight, Weighted, Rings | `bodyweight` |
| Band | `band` |
| Other | none (such exercises are never plan-eligible) |

The coach equipment `sled` has no GymMane equivalent and is never used.

## Exercise attributes

Exercise selection needs attributes the app's catalog does not have: movement
pattern, category, coach muscles with their roles, slot tags, long-length bias,
axial load, lower-body impact, unilateral, main-lift key, substitutions and a
load step. They live in `lib/coach/data/coach_meta.dart`, a generated,
import-free `const Map<String, CoachMeta>` keyed by the app's exercise id.
`dev/coach_meta_gen.dart` builds it from the coach's exercise annotations (the
kernel's exercise fixture) and the app's catalog:

| Step | Result |
|---|---|
| Exact name match | 22 |
| Close match (word sets without parentheses, plurals and the equipment word; or an alias of the app exercise) | 22 |
| Manual table in the generator | 28 |
| Merged into another entry (one app exercise, one winner: the main lift, then the most common) | 3 (`low-bar-squat`, `safety-bar-squat`, `single-arm-cable-pulldown`) |
| Dropped, no app equivalent and no template slot needs them | 2 (`backwards-sled-drag`, `tibialis-raise`) |
| Annotations of the app's own, each copying an annotated exercise | 12 |

That gives 81 annotated exercises. The app's own annotations exist because the
annotated exercises leave template slots empty with dumbbells only, or with
bodyweight and bands only (leg extension, lateral raise, a second row, a second
biceps and triceps exercise, ...). They never carry a main-lift key and rank
after every annotated exercise. Substitutions are stored as app ids and turned
into the coach's slugs by the adapter. Equipment is not stored: it always comes
from the app's exercise through the equipment table above, so the `sled` is
never used.

`lib/coach/adapters/catalog_adapter.dart` turns the app's exercises into the
kernel's `ExerciseDef`. The kernel has no "plan eligible" flag, so the adapter
has two entry points:

| Function | Holds | Used for |
|---|---|---|
| `coachPlanLibrary(all, archived:)` | annotated exercises that are not archived | the library given to `generateBlock` and `generateSession`: the generator only picks annotated exercises |
| `coachExercises(all)` | every exercise, archived and the user's own included | logged sets, weekly volume, swap options |

Exercises without annotations get derived attributes: category from
`coachCategoryFor`, muscles from the muscle table, equipment from the equipment
table, pattern guessed from the name and category, slot tags from the training
package's `deriveSlotTags`, and the lowest popularity. The user's own exercises
take this path and are marked `custom`.
`test/coach/catalog_adapter_test.dart` checks that `generateBlock` over the plan
library fills every template slot for each equipment preset and 2 to 6 lifting
days.

## Autonomy tiers

The coach changes some things by itself and asks before others. The tier of a
change decides which. `lib/coach/policy/autonomy.dart` holds this policy.

| Change | Tier |
|---|---|
| Next-session load and reps; first-set correction; moving a missed session to the next free day | Silent (always visible in the session, never a prompt) |
| `intro_week`, `standard_deload`, `targeted_deload`, `exercise_swap`, `plan_regenerate`, `block_transition` | Applied, shown with Undo for seven days |
| `volume_change`, `plateau_action`, `status_change`, `injury_adjust`, `calorie_adjust`, `multiplier_adjust` | Ask first |

The setting "Ask me before any change" in Settings › Coach moves the middle
tier to "ask first".

## Status

| Part | Location | Status |
|---|---|---|
| `coach_kernel` | `packages/coach_kernel` | not started |
| `coach_progression` | `packages/coach_progression` | not started |
| `coach_training` | `packages/coach_training` | not started |
| `coach_recovery` | `packages/coach_recovery` | not started |
| `coach_nutrition` | `packages/coach_nutrition` | not started |
| `coach_testkit` | `packages/coach_testkit` | not started |
| Adapter layer | `lib/coach/` | in progress: muscle, equipment, history, exposure and category adapters, persisted model, progression and nutrition entry points of `CoachFacade` |
| `CoachState` mixin | `lib/state/coach_state.dart` | module switches and persistence; progression module (Phase 3); nutrition goals and phase (Phase 6) |

What exists today is groundwork: the attribution credit in the About screen
and README, the CI workflow for the `coach` branch, the upstream baseline in
[BASELINE.md](BASELINE.md), and these documents. The Status column of the
[seams table](#seams) tracks the seams one by one.
