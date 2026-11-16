// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_recovery/coach_recovery.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

import 'seed.dart';

List<Proposal> _call(Map<String, dynamic> i) {
  final state = WeeklyState.fromJson(expandSeed(i['state'], seedJson) as Map<String, dynamic>);
  switch (i['call'] as String) {
    case 'injuryProposals':
      return injuryProposals(state);
    case 'volumeProposals':
      return volumeProposals(state, i['yesCount'] as int);
    case 'dislikeSwapProposals':
      return dislikeSwapProposals(state);
    case 'stalePlanProposals':
      return stalePlanProposals(state);
    case 'introWeekProposals':
      return introWeekProposals(state);
    case 'planReview':
      return planReview(state, i['yesCount'] as int);
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('plan_review.json', fn: 'planReview')) {
    test(c.name, () => expect(jsonDiff([for (final p in _call(c.input)) p.toJson()], c.output), isNull));
  }
}
