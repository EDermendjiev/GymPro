// SPDX-License-Identifier: GPL-3.0-only
// Task 5.5: the proposal card in the Home slot, and the "Ask me before any change" switch in Settings › Coach.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2340); // 360 logical px wide
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: child))),
  ));
  await tester.pumpAndSettle();
}

void _recovery() {
  fit.coach = CoachData.fromJson({
    'on': {'progression': true, 'plan': true, 'recovery': true},
    'profile': {
      'goal': 'lean_gain',
      'status': 'intermediate',
      'days': [1, 3, 5],
      'minutes': 60,
      'priority': 'lifting',
      'lifestyle': 'lightly_active',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = () => DateTime(2026, 11, 16, 9);
  });

  tearDown(() => fit.coachClock = DateTime.now);

  testWidgets('nothing to show while the recovery module is off', (tester) async {
    await _pump(tester, const CoachHomeSlot());
    expect(find.byType(CoachProposalCard), findsNothing);
    expect(find.byKey(const ValueKey('coach-soreness-row')), findsNothing);
  });

  testWidgets('a pending proposal shows its title and reason with Apply and Not now; applied, it offers Undo',
      (tester) async {
    _recovery();
    fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: [1, 3, 5]));
    fit.setCoachModule(CoachModule.recovery, true);
    fit.coach = fit.coach.copyWith(proposals: [
      {
        'id': 'p1',
        'kind': 'plan_regenerate',
        'state': 'pending',
        'createdOn': '2026-11-16',
        'title': 'Rebuild your plan to match your settings',
        'rationale': 'Your plan is out of date: 2 sessions next week fall on days you are not available.',
        'payload': {'reason': 'days'},
      },
    ]);
    await _pump(tester, const CoachHomeSlot());
    expect(find.text('Rebuild your plan to match your settings'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-proposal-apply-p1')));
    await tester.pumpAndSettle();
    expect(find.text('Changed by the coach'.toUpperCase()), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-proposal-undo-p1')));
    await tester.pumpAndSettle();
    expect(fit.coachProposals.single.state, CoachProposalState.pending);
    await tester.tap(find.byKey(const ValueKey('coach-proposal-later-p1')));
    await tester.pumpAndSettle();
    expect(find.byType(CoachProposalCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Settings › Coach has the "Ask me before any change" switch while the module is on', (tester) async {
    _recovery();
    await _pump(tester, const CoachSettings());
    await tester.tap(find.byKey(const ValueKey('coach-ask-first')));
    await tester.pumpAndSettle();
    expect(fit.coachAskFirst, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
