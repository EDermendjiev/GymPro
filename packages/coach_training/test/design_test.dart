// SPDX-License-Identifier: GPL-3.0-only
// generateBlock with a BlockDesign: the design sets the days, the split, the starting week and the targets.
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

late List<ExerciseDef> _exercises;

const _gym = [
  Equipment.barbell,
  Equipment.dumbbell,
  Equipment.machine,
  Equipment.cable,
  Equipment.bodyweight,
  Equipment.band,
];

BlockInput _input({
  Goal goal = Goal.leanGain,
  Status status = Status.intermediate,
  List<int> days = const [1, 2, 3, 4, 5],
  int minutes = 90,
  List<TrackedMuscle> specialization = const [],
}) => BlockInput(
  today: '2026-11-23',
  goal: goal,
  priority: Priority.lifting,
  status: status,
  availableDays: days,
  sessionMinutes: minutes,
  equipment: _gym,
  increments: const {},
  sports: const [],
  injuries: const [],
  exercises: _exercises,
  history: History(sets: const []),
  repVariation: RepVariation.withinSession,
  specialization: specialization,
);

/// Every non-main slot of each template at [sets] sets, except [drop] keys.
List<DesignSession> _weekOf(List<String> templates, {int sets = 3, Set<String> drop = const {}}) => [
  for (final key in templates)
    DesignSession(
      templateKey: key,
      slots: [
        for (final s in TEMPLATES[key]!.slots)
          if (s.mainLift == null && !drop.contains(s.key)) DesignSlot(key: s.key, sets: sets),
      ],
    ),
];

List<PlannedSession> _week0(BlockPlan b) => b.sessions.where((s) => s.weekIndex == 0).toList();

ExerciseDef _ex(String id) => _exercises.firstWhere((e) => e.id == id);

void main() {
  setUpAll(() {
    final seed =
        loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List<Object?>;
    _exercises = [for (final x in seed) ExerciseDef.fromJson(x as Map<String, dynamic>)];
  });

  const fb3 = SplitDef(key: 'FB3', name: 'Full Body ×3', templates: ['full_a', 'full_b', 'full_c']);

  test('no design and a null design give the same block', () {
    final a = jsonEncode(generateBlock(_input()).toJson());
    expect(jsonEncode(generateBlock(_input(), design: null).toJson()), a);
  });

  test('the design sets the days, the split and the explanations', () {
    final design = BlockDesign(
      split: fb3,
      explanations: [
        Explanation(text: 'Three full-body days.', ruleIds: ['T-PLN-03']),
      ],
      warnings: [
        Warning(code: WarningCode.lowFrequency, message: 'A planner warning.', ruleIds: ['T-PLN-01']),
      ],
    );
    final b = generateBlock(_input(), design: design);
    expect(b.splitKey, 'FB3');
    expect(b.liftDays, 3);
    expect(b.schedule.placements, hasLength(3));
    expect({for (final s in _week0(b)) s.templateKey}, {'full_a', 'full_b', 'full_c'});
    expect(b.explanations.first.text, 'Three full-body days.');
    expect(b.explanations.any((e) => e.text.contains('the fewest that keep')), isFalse);
    expect(b.explanations.any((e) => e.text.startsWith('Starting volume')), isFalse);
    expect(b.warnings.map((w) => w.message), contains('A planner warning.'));
  });

  test('the design targets replace the generator volume', () {
    final targets = {for (final m in TRACKED_MUSCLES) m: 8.0}..[MuscleId.sideDelts] = 12;
    final b = generateBlock(
      _input(),
      design: BlockDesign(split: fb3, targets: targets),
    );
    for (final t in b.targets) {
      expect(t.target, targets[t.muscle], reason: t.muscle.wire);
    }
    final withBase = generateBlock(
      _input(),
      design: BlockDesign(split: fb3, targets: targets, base: 9),
    );
    expect(withBase.targets.every((t) => t.base == 9), isTrue);
    expect(
      b.targets.every((t) => t.base == withBase.targets.first.base),
      isFalse,
      reason: 'without a base, the generator sets its own',
    );
    // Fractional sets, as the generator counts them: target −0.5 … target +1.
    final sideDelts = [
      for (final s in _week0(b))
        for (final e in s.exercises) e.sets * muscleWeight(_ex(e.exerciseId), MuscleId.sideDelts),
    ].fold(0.0, (a, n) => a + n);
    expect(sideDelts, inInclusiveRange(11.5, 13));
  });

  test('the starting week leaves out dropped slots and adds the extra exercises', () {
    final week = _weekOf(fb3.templates, drop: {'calf'});
    week[0] = DesignSession(
      templateKey: 'full_a',
      slots: [
        ...week[0].slots,
        const DesignSlot(key: 'extra', sets: 2, muscle: MuscleId.biceps, tags: [SlotTag.bicepsIso]),
      ],
    );
    final targets = {for (final m in TRACKED_MUSCLES) m: 6.0};
    final b = generateBlock(
      _input(),
      design: BlockDesign(split: fb3, week: week, targets: targets),
    );
    final sessions = _week0(b);
    for (final s in sessions) {
      expect(s.exercises.map((e) => e.slotKey), isNot(contains('calf')), reason: s.templateKey);
    }
    final a = sessions.firstWhere((s) => s.templateKey == 'full_a');
    final extra = a.exercises.where((e) => e.slotKey == 'extra_biceps').toList();
    expect(extra, hasLength(1));
    expect(_ex(extra.single.exerciseId).slotTags, contains(SlotTag.bicepsIso));
  });

  test('a design template the generator lacks is built, titled and scheduled', () {
    const legs = Template(
      key: 'legs_test',
      title: 'Legs Test',
      region: Region.lower,
      slots: [
        Slot(key: 'squat', label: 'Squat', tags: [SlotTag.squatFree, SlotTag.squatMachine]),
        Slot(key: 'leg_curl', label: 'Leg curl', tags: [SlotTag.legCurl, SlotTag.legCurlSeated]),
        Slot(key: 'calf', label: 'Calf raise', tags: [SlotTag.calf]),
      ],
    );
    final design = BlockDesign(
      split: const SplitDef(key: 'T2', name: 'Test', templates: ['upper_a', 'legs_test']),
      templates: {'legs_test': legs},
    );
    final b = generateBlock(_input(days: [1, 2, 4]), design: design);
    expect(b.splitKey, 'T2');
    final s = _week0(b).firstWhere((s) => s.templateKey == 'legs_test');
    expect(s.title, 'Legs Test');
    expect(s.exercises.map((e) => e.slotKey), containsAll(['squat', 'leg_curl', 'calf']));
    expect(moveWarnings('legs_test', 1, const [], extraTemplates: {'legs_test': legs}), isEmpty);
  });

  test('focus muscles go first, after main-lift work', () {
    final b = generateBlock(
      _input(),
      design: const BlockDesign(split: fb3, focus: [MuscleId.biceps]),
    );
    var checked = 0;
    for (final s in _week0(b)) {
      final i = s.exercises.indexWhere(
        (e) =>
            _ex(e.exerciseId).muscles.any((x) => x.muscle == MuscleId.biceps && x.role == MuscleRole.primary),
      );
      if (i < 0) continue;
      checked++;
      expect(i, 0, reason: s.templateKey);
    }
    expect(checked, greaterThan(0));
  });

  test('a design the input cannot follow is ignored', () {
    final plain = jsonEncode(generateBlock(_input(days: [1, 3])).toJson());
    // Three sessions on two days.
    expect(
      jsonEncode(
        generateBlock(
          _input(days: [1, 3]),
          design: const BlockDesign(split: fb3),
        ).toJson(),
      ),
      plain,
    );
    // An unknown template.
    const unknown = SplitDef(key: 'X', name: 'X', templates: ['nope', 'full_a']);
    expect(
      jsonEncode(
        generateBlock(
          _input(days: [1, 3]),
          design: const BlockDesign(split: unknown),
        ).toJson(),
      ),
      plain,
    );
    // A week that doesn't match the split.
    final wrong = BlockDesign(
      split: const SplitDef(key: 'FB2', name: 'Full Body ×2', templates: ['full_a', 'full_b']),
      week: _weekOf(['full_b', 'full_a']),
    );
    expect(jsonEncode(generateBlock(_input(days: [1, 3]), design: wrong).toJson()), plain);
  });

  test('a design that overruns the session length is trimmed to fit, and says so', () {
    final targets = {for (final m in TRACKED_MUSCLES) m: 16.0};
    final b = generateBlock(
      _input(minutes: 45),
      design: BlockDesign(split: fb3, targets: targets),
    );
    expect(b.liftDays, 3);
    final fits = _week0(b).every((s) => s.estMinutes <= 45 * 1.15);
    final warned = b.warnings.any((w) => w.code == WarningCode.timeTooShort);
    expect(fits || warned, isTrue);
    expect(b.targets.every((t) => t.target < 16), isTrue);
    if (!warned) expect(b.explanations.map((e) => e.text), contains(startsWith('Volume was trimmed')));
  });

  test('a long session pairs isolation exercises as supersets before sets are cut', () {
    final targets = {for (final m in TRACKED_MUSCLES) m: 12.0};
    BlockPlan build(bool supersets) => generateBlock(
      _input(minutes: 50),
      design: BlockDesign(split: fb3, targets: targets, supersets: supersets),
    );
    final plain = build(false);
    final paired = build(true);
    final sessions = _week0(paired);
    var pairs = 0;
    for (final s in sessions) {
      for (final (i, e) in s.exercises.indexed) {
        if (e.supersetWithNext != true) continue;
        pairs++;
        final a = _ex(e.exerciseId);
        final b = _ex(s.exercises[i + 1].exerciseId);
        expect(a.category, Category.isolation);
        expect(b.category, Category.isolation);
        expect(
          a.muscles.map((m) => m.muscle).toSet().intersection(b.muscles.map((m) => m.muscle).toSet()),
          isEmpty,
        );
        expect(s.exercises[i + 1].supersetWithNext, isNot(isTrue), reason: 'pairs, not chains');
      }
    }
    expect(pairs, greaterThan(0));
    expect(paired.explanations.map((e) => e.text), contains(supersetExplanation(50)));
    // Fewer sets cut than without supersets.
    double total(BlockPlan b) => b.targets.fold(0.0, (a, t) => a + t.target);
    expect(total(paired), greaterThan(total(plain)));
    // No supersets without the design flag, or when the session already fits.
    expect(_week0(plain).expand((s) => s.exercises).any((e) => e.supersetWithNext == true), isFalse);
    final roomy = generateBlock(
      _input(minutes: 120),
      design: BlockDesign(split: fb3, targets: targets, supersets: true),
    );
    expect(_week0(roomy).expand((s) => s.exercises).any((e) => e.supersetWithNext == true), isFalse);
  });

  test('the design follows the strength phases for main lifts', () {
    final b = generateBlock(
      _input(goal: Goal.strength, days: [1, 3, 5]),
      design: BlockDesign(split: SPLITS['FB3']!, week: _weekOf(SPLITS['FB3']!.templates, sets: 2)),
    );
    expect(b.splitKey, 'FB3');
    expect(_week0(b).expand((s) => s.exercises).any((e) => e.isMainLiftSingle == true), isTrue);
  });

  test('JSON round trip', () {
    final design = BlockDesign(
      split: fb3,
      templates: {'full_a': TEMPLATES['full_a']!},
      week: [
        ..._weekOf(['full_a', 'full_b']),
        const DesignSession(
          templateKey: 'full_c',
          slots: [
            DesignSlot(key: 'x', sets: 2, muscle: MuscleId.calves, tags: [SlotTag.calf]),
          ],
        ),
      ],
      targets: {for (final m in TRACKED_MUSCLES) m: 10.0},
      focus: const [MuscleId.glutes],
      explanations: [
        Explanation(text: 'e', ruleIds: ['T-PLN-03']),
      ],
      warnings: [
        Warning(code: WarningCode.lowFrequency, message: 'w', ruleIds: ['T-PLN-01']),
      ],
    );
    final json = jsonEncode(design.toJson());
    expect(jsonEncode(BlockDesign.fromJson(jsonDecode(json) as Map<String, dynamic>).toJson()), json);
  });
}
