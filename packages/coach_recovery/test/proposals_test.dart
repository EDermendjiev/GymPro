// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_recovery/coach_recovery.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

import 'seed.dart';

StoredPlan _plan(Object? json) => StoredPlan.fromJson(expandSeed(json, seedJson) as Map<String, dynamic>);
Proposal _proposal(Object? json) => Proposal.fromJson(json as Map<String, dynamic>);

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'validateProposal':
      return validateProposal(_proposal(i['proposal'])).toJson();
    case 'applyProposal':
      return applyProposal(_plan(i['plan']), _proposal(i['proposal'])).toJson();
    case 'deloadDiff':
      return deloadDiff(
        _plan(i['plan']),
        i['weekStart'] as String,
        i['cutPct'] as num,
        DeloadMode.fromWire(i['mode'] as String),
      ).toJson();
    case 'proposalKey':
      return proposalKey(i['kind'] as String, i['payload']);
    case 'stableJson':
      return stableJson(i['value']);
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final cases = loadFixture('apply_proposal.json', fn: 'proposals');
  for (final c in cases) {
    test(c.name, () {
      if (c.output case {'threw': final String _}) {
        // The reference's schema library words its own messages; only the failure itself has to match.
        expect(() => _call(c.input), throwsFormatException);
      } else {
        expect(jsonDiff(_call(c.input), c.output), isNull);
      }
    });
  }

  test('every payload kind has an invalid case', () {
    final kinds = {
      for (final c in cases)
        if (c.input['call'] == 'validateProposal' && c.output is Map && (c.output as Map).containsKey('threw'))
          (c.input['proposal'] as Map)['kind'],
    };
    expect(kinds, {for (final k in ProposalKind.values) k.wire});
  });

  test('valid payloads parse to typed payloads that write the same JSON back', () {
    for (final c in cases.where((c) => c.input['call'] == 'validateProposal')) {
      if (c.output case {'threw': final String _}) continue;
      final p = _proposal(c.input['proposal']);
      final typed = ProposalPayload.parse(p.kind, p.payload);
      expect(typed.kind, p.kind);
      final known = typed.toJson();
      // The typed payload drops keys the validator does not know, like the schema library does.
      expect(jsonDiff(known, {for (final k in known.keys) k: p.payload[k]}), isNull, reason: c.name);
      expect(jsonDiff(ProposalPayload.parse(p.kind, known).toJson(), known), isNull, reason: c.name);
    }
  });

  test('plan diffs survive a JSON round trip, so they can be stored as undo records', () {
    for (final c in cases.where((c) => c.input['call'] == 'applyProposal' || c.input['call'] == 'deloadDiff')) {
      if (c.output case {'threw': final String _}) continue;
      final encoded = jsonEncode(_call(c.input));
      final back = PlanDiff.fromJson(jsonDecode(encoded) as Map<String, dynamic>).toJson();
      expect(jsonDiff(back, c.output), isNull, reason: c.name);
      expect(jsonEncode(back), encoded, reason: c.name);
    }
    final plan = cases.firstWhere((c) => c.input['call'] == 'deloadDiff').input['plan'];
    final json = expandSeed(plan, seedJson) as Map<String, dynamic>;
    expect(jsonDiff(StoredPlan.fromJson(json).toJson(), json), isNull);
  });

  test('payload checks the schema makes and a fixture cannot show', () {
    Object? parse(ProposalKind kind, Map<String, dynamic> map) => ProposalPayload.parse(kind, map).toJson();
    // Payloads the engine builds in Dart (typed lists and maps, not decoded JSON) parse too.
    expect(
      parse(ProposalKind.plateauAction, {
        'exerciseId': 'x',
        'step': 'add_volume',
        'details': 'd',
        'changes': [
          {'muscle': 'chest', 'from': 10, 'to': 12.0},
        ],
      }),
      {
        'exerciseId': 'x',
        'step': 'add_volume',
        'details': 'd',
        'changes': [
          {'muscle': 'chest', 'from': 10.0, 'to': 12.0},
        ],
      },
    );
    expect(() => parse(ProposalKind.multiplierAdjust, {'from': double.nan, 'to': 1, 'reason': 'x'}), throwsFormatException);
    expect(
      () => parse(ProposalKind.multiplierAdjust, {'from': double.infinity, 'to': 1, 'reason': 'x'}),
      throwsFormatException,
    );
    expect(
      () => parse(ProposalKind.statusChange, {'from': 'novice', 'to': Status.advanced, 'evidence': 'x'}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"to"'))),
    );
    expect(() => DeloadMode.fromWire('none'), throwsFormatException);
    expect(() => TargetedDeloadMode.fromWire('none'), throwsFormatException);
    expect(() => PlateauStep.fromWire('none'), throwsFormatException);
  });
}
