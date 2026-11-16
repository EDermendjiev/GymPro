<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Upstream baseline for the coach fork

How the unmodified upstream code analyses and tests on the development machine,
measured before any change was made on the `coach` branch.

## Environment

| Item | Value |
| --- | --- |
| Date | 2026-11-14 |
| OS | Windows 10 Pro 10.0.19045 |
| Flutter | 3.41.9 (framework revision 00b0c91f06, engine revision 42d3d75a56) |
| Dart | 3.11.5 |
| CI pin | `FLUTTER_VERSION: '3.41.9'` in `.github/workflows/build-apk.yml` (matches) |

## Commit measured

- `git rev-parse upstream/main`: `37fb00d0b1a123589ad50b39b16d3e100ece33d7`
- `coach` HEAD was the same commit, the working tree was clean, and
  `git diff --stat upstream/main` was empty when the measurements were taken.

## Commands run

From the repository root, on branch `coach`:

```
flutter --version
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Then in `packages/sync`:

```
dart pub get
dart test
```

`flutter test` was run twice, each time with `--file-reporter json:<file>` added
so the counts below come from the machine-readable report, not from the console.

## Results

| Check | Result |
| --- | --- |
| `flutter pub get` | OK, exit 0 |
| `flutter analyze --no-fatal-infos` | 0 errors, 0 warnings, 0 infos ("No issues found!"), exit 0 |
| `flutter test` | 1121 passed, 0 failed, 3 skipped, across 102 test files, exit 0 |
| `packages/sync`: `dart pub get` | OK, exit 0 |
| `packages/sync`: `dart test` | 4 passed, 0 failed, 0 skipped (1 test file), exit 0 |

Both `flutter test` runs gave identical counts; no flaky test was seen. Wall
time was 141 s for the first run and 107 s for the second.

No tracked file was modified by `pub get`, the analyzer or the tests
(`git status` stayed clean throughout).

`flutter pub get` prints ICU plural warnings for `app_ru.arb` and `app_uk.arb`
and reports untranslated messages for 21 locales while generating the
localizations. These are upstream messages, not analyzer issues.

## Skipped tests

No test failed. Three placeholder tests are skipped:

| File | Test name | Skip reason | Environment-specific? |
| --- | --- | --- | --- |
| `test/fitnotes_backup_test.dart` | `sin fixture` | `test/fixtures no se publica` | No. The fixture `test/fixtures/import/fitnotes_backup.fitnotes` is not in the repository (`test/fixtures/` is git-ignored), so this skips on any checkout. |
| `test/import_real_files_test.dart` | `sin fixtures` | `test/fixtures no se publica` | No. The directory `test/fixtures/import` is not in the repository; same on any checkout. |
| `test/stats_realdata_test.dart` | `sin fixture` | `test/fixtures no se publica` | No. The fixture `test/fixtures/seed_backup.json` is not in the repository; same on any checkout. |

In each of these files the real tests are only registered when the private
fixture exists, so their content is not exercised by this baseline.

## Coach parity gate (`coach-parity-v1`, 2026-11-16)

The five coach packages were proven equal to the fixture generator and tagged
`coach-parity-v1`. From this tag on the Dart packages are the source of truth;
the fixture generator is frozen at commit
`1e559398316f14db0a994edd6154d114fe80f60d` and its engine is not changed again.
Any later behaviour change is a separate commit with its own test.

| Package | Tests | Line coverage |
| --- | --- | --- |
| `coach_kernel` | 649 | 99.0% (1076/1087) |
| `coach_progression` | 400 | 100% (216/216) |
| `coach_training` | 2895 | 99.7% (1477/1482) |
| `coach_recovery` | 983 | 100% (1106/1106) |
| `coach_nutrition` | 410 | 95.9% (493/514) |

Coverage was measured with `dart pub global run coverage:test_with_coverage`
in each package. Regenerating every fixture from the frozen generator commit
reproduced all 34 committed fixture files byte for byte.

Deliberate differences from the fixture generator, each pinned by a Dart test:
- `setsInLast48h` reads a timestamp without a zone as UTC (the generator read
  it in the host's local time).
- `checkinSoreness` rejects an unknown muscle key with a `FormatException`.
- `block_transition` rejects an unknown target block kind with a
  `FormatException`.
- Proposal payloads are checked by hand-written validators that throw
  `FormatException`.

## Upstream merge: GymMane v2.3.0 (2026-11-16)

`upstream/main` moved from `37fb00d` to `e774a0443d3d75127d4e619ed7e17706c6135baf`
(tag v2.3.0, 31 commits, `pubspec.yaml` version 2.3.0+14). `main` was
fast-forwarded to it and merged into `coach`, following
[UPSTREAM.md](UPSTREAM.md).

| Check | Result |
| --- | --- |
| Conflicts | `lib/screens/train_screen.dart`, `lib/l10n/app_en.arb`, the generated `lib/l10n/app_localizations*.dart`; all in the seams table |
| `flutter analyze --no-fatal-infos` | No issues found |
| `flutter test` | 1551 passed, 0 failed, 3 skipped (the three fixture placeholders above) |
| Package tests (`dart test`) | `sync` 6, `coach_kernel` 649, `coach_progression` 400, `coach_training` 2895, `coach_recovery` 983, `coach_nutrition` 410; all passed |
| `test/coach/seam_audit_test.dart` | passed, no seam added or moved |

Upstream v2.3.0 ships 52 new English keys translated into Spanish only, and
its own `test/i18n_test.dart` fails on that commit ("faltan claves en ar").
The fork lists those keys in `test/pending_translation_keys.txt`, which is
what the file is for; no upstream test was changed.
