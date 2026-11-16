// SPDX-License-Identifier: GPL-3.0-only
// The coach's Home slot appears in both Home layouts: the phone's list and the desktop's card flow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/desktop.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/screens/home_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {required bool desktop}) async {
  tester.view.physicalSize = desktop ? const Size(1440, 1000) : const Size(1080, 2340);
  tester.view.devicePixelRatio = desktop ? 1 : 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: DesktopScope(wide: desktop, child: const Scaffold(body: HomeScreen())),
  ));
  await tester.pump(const Duration(seconds: 4)); // past the desktop layout's medal warm-up
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  for (final desktop in [false, true]) {
    final layout = desktop ? 'desktop' : 'phone';
    testWidgets('$layout: nothing while the coach modules are off', (tester) async {
      await _pump(tester, desktop: desktop);
      expect(find.byType(CoachHomeSlot), desktop ? findsNothing : findsOneWidget);
      expect(find.byType(CoachHomeHint), findsNothing);
    });

    testWidgets('$layout: the slot shows the coach hint while the plan module is on', (tester) async {
      fit.coach = CoachData.empty().withModule(CoachModule.progression, true).withModule(CoachModule.plan, true);
      await _pump(tester, desktop: desktop);
      expect(find.byType(CoachHomeHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
