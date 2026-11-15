// SPDX-License-Identifier: GPL-3.0-only

// The same file in every coach package: it checks the `lib` directory of the package it runs in.
import 'dart:io';

import 'package:coach_testkit/purity.dart';
import 'package:test/test.dart';

void main() {
  final lib = Directory('lib');
  const reword = 'Whole lines are scanned, comments and strings included: the fix is to reword the line.';
  test('lib is pure Dart', () => expect(impurities(lib), isEmpty, reason: reword));
  test('lib carries no source citations', () => expect(citations(lib), isEmpty, reason: reword));
  test('lib declares the licence', () => expect(unlicensed(lib), isEmpty, reason: 'Line 1: $licenceLine'));
}
