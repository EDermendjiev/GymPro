// SPDX-License-Identifier: GPL-3.0-only
// Task 7.1: the coach ships in English. Its strings live in app_en.arb and wait in test/pending_translation_keys.txt
// for translators; every other language falls back to the English text for them, and no coach widget writes its
// own English.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/screens/nutrition_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys the coach adds to the app's strings.
final List<String> _coachKeys = [
  for (final k in (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map).keys.cast<String>())
    if (!k.startsWith('@') && (k.startsWith('coach') || k == 'sectionCoach' || k == 'basedOnGymMane')) k,
];

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

void _coachOn() {
  fit.coach = CoachData.fromJson({
    'on': {'progression': true, 'plan': true, 'recovery': true, 'nutrition': true},
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every string the coach adds is in app_en.arb and waits in the pending list', () {
    expect(_coachKeys.length, greaterThan(100));
    final pending = File('test/pending_translation_keys.txt').readAsLinesSync().toSet();
    expect([for (final k in _coachKeys) if (!pending.contains(k)) k], isEmpty);
  });

  test('no coach widget hard-codes English', () {
    // The same rule test/i18n_test.dart applies to lib/screens, lib/widgets and lib/app.
    final pattern = RegExp(r"""(?:Text\(\s*|label:\s*|hintText:\s*|ScreenTitle\(\s*|title:\s*)'([^']{2,})'""");
    final offenders = <String>[];
    for (final f in Directory('lib/coach/ui').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        final text = m.group(1)!;
        if (text.contains(r'$') || !RegExp(r'[A-Za-z]{2}').hasMatch(text)) continue;
        if (RegExp(r'^[A-Z]').hasMatch(text) || text.contains(' ')) offenders.add('${f.uri.pathSegments.last}: "$text"');
      }
      for (final word in const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Jan', 'Feb', 'Dec']) {
        if (f.readAsStringSync().contains("'$word'")) offenders.add('${f.uri.pathSegments.last}: "$word"');
      }
    }
    expect(offenders, isEmpty);
  });

  for (final code in const ['de', 'ja']) {
    group('in $code', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await Store.instance.init();
        fit.resetAllData();
        fit.onboarded = true;
        fit.coachClock = () => DateTime(2026, 11, 16, 9);
        setAppLanguage(code);
      });

      tearDown(() {
        fit.coachClock = DateTime.now;
        setAppLanguage('en');
      });

      test('the coach\'s strings fall back to English, the app\'s own are translated', () {
        expect(t.localeName, code);
        expect(t.coachPlanHint, _en.coachPlanHint);
        expect(t.coachGoalsSetBy, _en.coachGoalsSetBy);
        expect(t.coachOnbGoalTitle, _en.coachOnbGoalTitle);
        expect(t.nutritionGoals, isNot(_en.nutritionGoals));
      });

      testWidgets('Settings › Coach renders', (tester) async {
        _coachOn();
        await _pump(tester, const CoachSettings());
        expect(find.text(_en.coachPlanHint), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the coach\'s onboarding pages render', (tester) async {
        fit.onboarded = false;
        fit.coachDraft = CoachAnswers();
        Widget frame(int step, String title, String why, Widget child) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(title), Text(why), child],
            );
        final pages = coachOnboardingPages(first: 7, frame: frame, skip: () {});
        await _pump(tester, pages.first);
        expect(find.text(_en.coachOnbGoalTitle), findsOneWidget);
        await _pump(tester, pages.last);
        expect(tester.takeException(), isNull);
        fit.onboarded = true;
      });

      testWidgets('the proposal card renders', (tester) async {
        _coachOn();
        fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: [1, 3, 5]));
        fit.coach = fit.coach.copyWith(proposals: [
          {
            'id': 'p1',
            'kind': 'plan_regenerate',
            'state': 'pending',
            'createdOn': '2026-11-16',
            'title': 'Rebuild your plan to match your settings',
            'rationale': 'Your plan is out of date.',
            'payload': {'reason': 'days'},
          },
        ]);
        await _pump(tester, const CoachHomeSlot());
        expect(find.byType(CoachProposalCard), findsOneWidget);
        expect(find.text(_en.coachProposalNotNow), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('the nutrition card renders in the goals sheet', (tester) async {
        _coachOn();
        tester.view.physicalSize = const Size(2400, 2700);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(onPressed: () => showGoalsSheet(context), child: const Text('open')),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(CoachGoalsCard), findsOneWidget);
        expect(find.text(_en.coachGoalsSetBy), findsOneWidget);
        expect(find.text(t.nutritionGoals), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
