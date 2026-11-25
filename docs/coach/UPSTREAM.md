<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Merging upstream

How to bring new GymMane changes into this fork. The fork keeps its edits to
existing GymMane files down to a short list of seams, so a merge should
conflict in few places and each conflict should be small. The list is the
seams table in [ARCHITECTURE.md](ARCHITECTURE.md#seams).

## Remotes and branches

| Remote | Repository | Use |
|---|---|---|
| `upstream` | `https://github.com/InlitX/GymMane` | Fetch only. Never push to it. |
| `origin` | `https://github.com/EDermendjiev/GymPro` | The fork. |

| Branch | Policy |
|---|---|
| `main` | Mirrors `upstream/main`. Never commit to it. It only ever moves by fast-forward. |
| `coach` | All work lands here. |

A fresh clone of the fork has no `upstream` remote. Add it once:

```bash
git remote add upstream https://github.com/InlitX/GymMane.git
```

## Merge commands

```bash
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout coach && git merge main
```

The first line downloads upstream's commits. The second moves `main` to
upstream's head and publishes it. `--ff-only` refuses to continue if `main`
has commits of its own; that means something was committed to `main` by
mistake, and it must be moved to `coach` before going on. The third line
merges the new upstream code into `coach`.

## Resolving conflicts

1. Conflicts are expected only in the files listed in the seams table in
   ARCHITECTURE.md. A conflict anywhere else means a seam was added without
   being listed: fix the list or move the code into `lib/coach/`. The one
   exception is the generated localisation files
   (`lib/l10n/app_localizations*.dart`): take either side and let step 3
   regenerate them.
2. Resolve each conflict by taking upstream's version and re-applying the
   one-line seam.
3. Run `flutter gen-l10n`, `flutter analyze --no-fatal-infos`, `flutter test`,
   and the package tests:

   ```bash
   (cd packages/sync && dart pub get && dart test)
   for p in coach_kernel coach_progression coach_training coach_recovery coach_nutrition coach_planner; do
     if [ -d "packages/$p" ]; then
       (cd "packages/$p" && dart pub get && dart analyze --fatal-warnings && dart test) || break
     fi
   done
   ```

   The loop skips packages that do not exist yet and stops at the first one
   that fails.

4. `test/coach/seam_audit_test.dart` must pass before pushing. Until that
   test exists, compare the list of existing files the fork has modified
   against the seams table by hand:

   ```bash
   git diff --name-only --diff-filter=M main coach
   ```

5. If upstream changes a seam's host function substantially (for example
   rewrites `_nextPlan`), do not patch blindly. Read what the seam is for in
   ARCHITECTURE.md, re-apply it to the new code, and re-check that the seam's
   test still exercises it.

Pushing `coach` runs the analyzer, the app tests and the package tests again
in CI (`.github/workflows/coach-ci.yml`).

## Cadence

Merge at least every two weeks. Small merges keep the seam conflicts trivial.

## Fixes that are not coach-specific

A fix that is not specific to the coach should be offered upstream as a pull
request, so that the fork does not carry it.
