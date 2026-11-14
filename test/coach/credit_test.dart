// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const credit = 'Based on GymMane by InlitX';

  test('the credit is an English UI string', () {
    expect(File('lib/l10n/app_en.arb').readAsStringSync(), contains('"basedOnGymMane": "$credit"'));
  });

  test('the About screen shows the credit', () {
    expect(File('lib/screens/about_screen.dart').readAsStringSync(), contains('t.basedOnGymMane'));
  });

  test('the README and licence files carry it', () {
    expect(File('README.md').readAsStringSync(), contains(credit));
    expect(File('ADDITIONAL_TERMS.md').readAsStringSync(), contains(credit));
    expect(File('LICENSE').readAsStringSync(), contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
