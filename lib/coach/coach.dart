// SPDX-License-Identifier: GPL-3.0-only
// The coach layer's public face. Screens, widgets and state import this file and nothing else under lib/coach/.
//
// Rules, enforced by test/coach/boundary_test.dart:
//  - every export has a `show` list;
//  - every exported name starts with `Coach` (or `coach` for functions), so nothing here can clash with the
//    app's own names;
//  - a coach package is never re-exported.
library;

export 'model/coach_data.dart' show CoachData, CoachModule;
export 'model/coach_profile.dart' show CoachProfile;
export 'model/coach_targets.dart' show CoachRx, CoachSessionTarget, CoachSetTarget, CoachWarmupSet;
export 'facade.dart' show CoachFacade;
export 'ui/coach_settings.dart' show CoachSettings, CoachSettingsRow, coachSettingsIcon, coachSettingsSearchRows;
