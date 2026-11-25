// SPDX-License-Identifier: GPL-3.0-only
// Rule registry. One entry per rule ID.
// Summaries are written in our own words and stay ≤ 280 characters.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/// 'evidence' = rule taken from training/nutrition evidence; 'heuristic' = product heuristic.
enum RuleBasis {
  evidence('evidence'),
  heuristic('heuristic');

  const RuleBasis(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, RuleBasis> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static RuleBasis fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown RuleBasis: "$wire"'));
}

class RuleDef {
  /// Positional, unlike the other model classes, so that the table below stays short.
  const RuleDef(this.id, this.basis, this.summary);

  factory RuleDef.fromJson(Map<String, dynamic> json) =>
      RuleDef(json['id'] as String, RuleBasis.fromWire(json['basis'] as String), json['summary'] as String);

  final String id;
  final RuleBasis basis;
  final String summary;

  Map<String, dynamic> toJson() => {'id': id, 'basis': basis.wire, 'summary': summary};
}

const List<RuleDef> RULE_LIST = [
  // Training status
  RuleDef(
    'T-STA-01',
    RuleBasis.evidence,
    'Training status is judged by how fast you progress, not by years or strength: novices improve almost every session, intermediates week to week, advanced lifters month to month.',
  ),
  RuleDef(
    'T-STA-02',
    RuleBasis.heuristic,
    'If you are unsure of your status: under a year of consistent training counts as novice; 5+ years with heavy lifts that barely move month to month counts as advanced; otherwise intermediate.',
  ),
  RuleDef(
    'T-STA-03',
    RuleBasis.heuristic,
    'After 8+ weeks of logs the app checks how often your anchor lifts improve and suggests a status change if your logs disagree with your setting twice in a row.',
  ),
  RuleDef(
    'T-STA-04',
    RuleBasis.evidence,
    'Status can differ between body regions. The app stores one status for now.',
  ),
  RuleDef(
    'T-PRI-01',
    RuleBasis.evidence,
    'When you lift and play a sport, one has to come first. If the sport comes first, lifting stays lower in volume, further from failure and avoids risky exercises and heavy soreness.',
  ),
  // Volume
  RuleDef(
    'T-VOL-01',
    RuleBasis.evidence,
    'About 4 hard sets per muscle per week is the minimum that reliably grows muscle. Targets never go below this.',
  ),
  RuleDef(
    'T-VOL-02',
    RuleBasis.evidence,
    'For most people 10–20 hard sets per muscle per week is the practical range; more is reserved for specialisation phases.',
  ),
  RuleDef(
    'T-VOL-03',
    RuleBasis.evidence,
    'Extra sets give smaller and smaller returns around 30 per week, so 30 is the hard ceiling for a specialised muscle.',
  ),
  RuleDef(
    'T-VOL-04',
    RuleBasis.evidence,
    'More weekly sets cost more time: roughly 4–8 sets per muscle ≈ 1–2.5 h/week, up to 9+ h/week at 21–30 sets. Fewer sets give more growth per set.',
  ),
  RuleDef(
    'T-VOL-05',
    RuleBasis.evidence,
    'Sets are counted fractionally: 1 set for each muscle an exercise mainly trains and half a set for each muscle it trains secondarily.',
  ),
  RuleDef(
    'T-VOL-06',
    RuleBasis.evidence,
    'A set only counts toward muscle growth if it has at least 4 reps and ends within about 4 reps of failure. Warm-ups never count.',
  ),
  RuleDef(
    'T-VOL-07',
    RuleBasis.evidence,
    'Start with the least volume that still drives progress and add sets only after a real plateau with good recovery.',
  ),
  RuleDef(
    'T-VOL-08',
    RuleBasis.evidence,
    'Advanced lifters can specialise: raise 1–2 muscles by about half and cut the rest by a third to a half for 8–12 weeks, then return to a balanced phase.',
  ),
  // Frequency
  RuleDef(
    'T-FRQ-01',
    RuleBasis.evidence,
    'Keep any single session at or below about 11 sets for one muscle; spread more volume over more sessions.',
  ),
  RuleDef(
    'T-FRQ-02',
    RuleBasis.evidence,
    'Weekly sets set the frequency: 4–10 sets → 1–2 sessions per week, 11–20 → 2–3, 21–30 → 3 or more.',
  ),
  RuleDef(
    'T-FRQ-03',
    RuleBasis.evidence,
    'For strength, train each main lift 2–6 times a week with 1–2 direct sets per session, spread over as many sessions as possible.',
  ),
  RuleDef(
    'T-FRQ-04',
    RuleBasis.evidence,
    'Three to five lifting days with each muscle trained 2–4 times a week suits most lifters. Two days is the minimum and fine for maintenance.',
  ),
  // Scheduling
  RuleDef(
    'T-SCH-01',
    RuleBasis.heuristic,
    'The app picks the fewest lifting days that keep every session within your time limit and every muscle at a workable frequency.',
  ),
  RuleDef(
    'T-SCH-02',
    RuleBasis.evidence,
    'Keep at least one full rest day per week with no lifting and no hard sport.',
  ),
  RuleDef(
    'T-SCH-03',
    RuleBasis.evidence,
    'Cardio interferes least with lifting when done after lifting, at least 3 hours apart, or best of all on a different day.',
  ),
  RuleDef(
    'T-SCH-04',
    RuleBasis.evidence,
    'Avoid hard leg sessions within about 24 hours before a leg-heavy match or hard session, and the day after a match.',
  ),
  RuleDef(
    'T-SCH-05',
    RuleBasis.evidence,
    'Avoid lots of work for a muscle the day before a main lift that relies on it (for example heavy quad work the day before squats).',
  ),
  RuleDef(
    'T-SCH-06',
    RuleBasis.evidence,
    'Back-to-back hard days happen; on the second day simply expect to use a bit less load.',
  ),
  // Split
  RuleDef(
    'T-SPL-01',
    RuleBasis.evidence,
    'Choose a split that keeps sessions practical and no muscle above about 11 sets per session; higher weekly volume needs more frequency.',
  ),
  RuleDef(
    'T-SPL-02',
    RuleBasis.evidence,
    'Lower-body sessions are the most draining, so when leg volume is high, spread it over more days.',
  ),
  // Plan design
  RuleDef(
    'T-PLN-01',
    RuleBasis.evidence,
    'The plan uses the days you can keep up week after week; a schedule you can follow beats one that looks better on paper.',
  ),
  RuleDef(
    'T-PLN-02',
    RuleBasis.evidence,
    'Weekly sets per muscle follow the time you have: about 4-8 for up to 2.5 h of lifting a week, 9-12 for 3-4.5 h, 13-16 for 5-6.5 h and 17-20 for 7-8.5 h.',
  ),
  RuleDef(
    'T-PLN-03',
    RuleBasis.evidence,
    'Among the splits for your days, the plan keeps every muscle at a workable frequency, no muscle above about 11 sets in a session and sessions within your time, then weighs your preferences.',
  ),
  RuleDef(
    'T-PLN-04',
    RuleBasis.evidence,
    'Muscles you want to bring up get more sets and more frequency; advanced lifters do this in phases while other muscles run lower volume.',
  ),
  RuleDef(
    'T-PLN-05',
    RuleBasis.evidence,
    'Novices vary reps within each session, intermediates between sessions, advanced lifters from week to week.',
  ),
  RuleDef(
    'T-PLN-06',
    RuleBasis.heuristic,
    'From about 50, volume starts a little lower, heavy leg work favours supported and machine variations, and hard leg days get more time between them.',
  ),
  RuleDef(
    'T-PLN-07',
    RuleBasis.heuristic,
    'The training style you prefer and the split you already use weigh in the choice, because a plan you enjoy is a plan you keep.',
  ),
  RuleDef(
    'T-PLN-08',
    RuleBasis.evidence,
    'When a session runs long, isolation exercises for different muscles are paired as supersets, one rest for each pair, before any sets are cut.',
  ),
  RuleDef(
    'T-PLN-09',
    RuleBasis.heuristic,
    'When the weekly recovery check flagged fatigue in two or more of the last four weeks, the next block starts 2 sets per muscle lower.',
  ),
  // Exercise selection
  RuleDef(
    'T-SEL-01',
    RuleBasis.evidence,
    'Use 1–3 exercises per main movement and cover the gaps: an incline press, a wide-elbow row and a lat-focused pull, plus isolation for quads, hamstrings, biceps, triceps, side delts and calves.',
  ),
  RuleDef('T-SEL-02', RuleBasis.evidence, 'An exercise must actually train the muscle it is meant to grow.'),
  RuleDef(
    'T-SEL-03',
    RuleBasis.evidence,
    'When options are otherwise equal, prefer exercises that load the muscle hard in its stretched position.',
  ),
  RuleDef(
    'T-SEL-04',
    RuleBasis.evidence,
    'Exercises must be practical: available equipment, no injury conflict, something you do not hate, quick to set up.',
  ),
  RuleDef(
    'T-SEL-05',
    RuleBasis.evidence,
    'Order sessions with free-weight compounds first, machines next and isolation last, unless a lagging muscle needs priority.',
  ),
  RuleDef(
    'T-SEL-06',
    RuleBasis.evidence,
    'Keep the same exercises for a whole block so progress is measurable; change only one or two per session between blocks.',
  ),
  RuleDef(
    'T-SEL-07',
    RuleBasis.evidence,
    'For strength, the main lifts provide their own volume; extra muscle work uses quicker, less fatiguing exercises.',
  ),
  RuleDef(
    'T-SEL-08',
    RuleBasis.evidence,
    'Work around pain: drop exercises that load a painful area heavily, favour machines and higher reps, and see a professional for persistent or red-flag pain.',
  ),
  // Intensity
  RuleDef(
    'T-INT-01',
    RuleBasis.evidence,
    'Muscle grows from roughly 4–30 rep loads when sets end close to failure; the lower the reps, the more reps you can leave in the tank. Strength needs heavy loads (1–8 reps).',
  ),
  RuleDef(
    'T-INT-02',
    RuleBasis.evidence,
    'Hypertrophy sets need at least 4 reps. Avoid going to complete failure on free-weight squats, hinges and presses.',
  ),
  RuleDef(
    'T-INT-03',
    RuleBasis.evidence,
    'Each exercise type has its own rep and effort range: heavy lower-body free weights 4–8 reps at 2–4 RIR, presses and leg machines 4–12, machines and rows 6–15, isolation 8–20 close to failure.',
  ),
  RuleDef(
    'T-INT-04',
    RuleBasis.evidence,
    'Vary rep ranges (within a session, between sessions or between weeks), but do not spend more than about 3 weeks outside hypertrophy ranges.',
  ),
  RuleDef(
    'T-INT-05',
    RuleBasis.evidence,
    'When your sport comes first, every lifting set stops one rep further from failure and the heaviest rep range on leg compounds is dropped.',
  ),
  RuleDef(
    'T-RIR-01',
    RuleBasis.evidence,
    'RPE 10 = 0 reps in reserve, 9 = 1, 8 = 2, 7 = 3. Most people underestimate how many reps they have left by about one, especially on high-rep sets.',
  ),
  // Rest, tempo, warm-up
  RuleDef(
    'T-RST-01',
    RuleBasis.evidence,
    'For strength main lifts rest until ready: at least 2 minutes, usually about 3.',
  ),
  RuleDef(
    'T-RST-02',
    RuleBasis.evidence,
    'For hypertrophy rest at least 90 seconds on average; longer for big lower-body lifts.',
  ),
  RuleDef(
    'T-RST-03',
    RuleBasis.evidence,
    'Supersets and drop sets save time; a four-drop drop set counts as about three normal sets.',
  ),
  RuleDef(
    'T-TMP-01',
    RuleBasis.evidence,
    'Lower the weight under control in about 1–4 seconds and lift with intent; any lifting speed works as long as the set gets close to failure.',
  ),
  RuleDef(
    'T-WUP-01',
    RuleBasis.evidence,
    'Warm up generally, then ramp up on the first compound. Dynamic stretching is fine; keep static stretching brief for muscles you are about to train.',
  ),
  // Progression
  RuleDef(
    'T-PRG-01',
    RuleBasis.evidence,
    'Pick a first-set load that lands in the rep range at the top of the RIR range and stop the set there.',
  ),
  RuleDef(
    'T-PRG-02',
    RuleBasis.evidence,
    'If the first set lands in range, keep the load for the remaining sets and aim for the same reps. Reps falling on later sets is fine.',
  ),
  RuleDef(
    'T-PRG-03',
    RuleBasis.evidence,
    'If the first set misses the rep range, change the load by about 4% per rep you missed or exceeded and keep that load for the rest of the sets.',
  ),
  RuleDef(
    'T-PRG-04',
    RuleBasis.evidence,
    'When the first set hits the top of the rep range at the top of the RIR range, add load next session.',
  ),
  RuleDef(
    'T-PRG-05',
    RuleBasis.evidence,
    'Session-to-session swings are normal. On a strong day you can jump ahead; on a flat day drop a step and chase reps.',
  ),
  RuleDef(
    'T-PRG-06',
    RuleBasis.evidence,
    'Typical pace: novices add load every 2–3 sessions, intermediates about every 5, advanced lifters about half as often.',
  ),
  // Strength phases
  RuleDef(
    'T-STR-01',
    RuleBasis.evidence,
    'Strength training cycles a Volume phase and a Load phase (and a Peak phase before a test), with an easier intro week when coming back to volume.',
  ),
  RuleDef(
    'T-STR-02',
    RuleBasis.evidence,
    'Volume phase: 1–3 top singles per lift per week getting harder (RPE 5 → 8), then normal working sets; 10–20 weekly sets for the supporting muscles.',
  ),
  RuleDef(
    'T-STR-03',
    RuleBasis.evidence,
    'Load phase: 2–4 singles per lift per week (RPE 6 → 9), each followed by 2 back-off sets of 5 → 3 reps; supporting volume drops to 5–10 sets.',
  ),
  RuleDef(
    'T-STR-04',
    RuleBasis.evidence,
    'Peak phase (only before a test): heavy singles up to RPE 10, few back-off sets and very little extra volume for 2–4 weeks.',
  ),
  RuleDef(
    'T-EST-01',
    RuleBasis.evidence,
    'Estimated 1-rep max (e1RM) uses a Brzycki-style formula on effective reps (reps + RIR): load × 36 ÷ (37 − effective reps). Sets above 12 effective reps are too far from a max to estimate, so they are left out.',
  ),
  RuleDef(
    'T-STR-05',
    RuleBasis.evidence,
    'Train each main lift 2–4 times a week; a session that works the same muscles with another lift counts as half an exposure.',
  ),
  // Fatigue
  RuleDef(
    'T-FAT-01',
    RuleBasis.evidence,
    'Each week answer five quick recovery questions. Two or more “yes” answers means a deload next week.',
  ),
  RuleDef('T-FAT-02', RuleBasis.evidence, 'Deloads happen when you need them, not on a fixed calendar.'),
  RuleDef(
    'T-FAT-03',
    RuleBasis.evidence,
    'A standard deload cuts sets on every exercise by about 30–50% while keeping loads, effort and number of sessions.',
  ),
  RuleDef(
    'T-FAT-04',
    RuleBasis.evidence,
    'If only one area is beaten up, deload just that area: drop or reduce the exercises that load it and train everything else normally.',
  ),
  RuleDef(
    'T-FAT-05',
    RuleBasis.evidence,
    'If aches flare with heavy loads but not with high reps, use a week of higher reps on those exercises.',
  ),
  RuleDef(
    'T-FAT-06',
    RuleBasis.evidence,
    'After a big volume jump, time off, or moving from heavy work back to volume, run the first week at about 75% of the sets and one rep further from failure.',
  ),
  RuleDef(
    'T-FAT-07',
    RuleBasis.evidence,
    'Missed a session? Move it to the next free day, never stack two missed hard sessions on one day, and drop the least important one if the week runs out.',
  ),
  RuleDef(
    'T-FAT-08',
    RuleBasis.evidence,
    'Feeling drained? Swap today for the lightest session of the week.',
  ),
  // Sports
  RuleDef(
    'S-01',
    RuleBasis.heuristic,
    'Every sport session at moderate effort or harder counts as one hard session in your weekly load.',
  ),
  RuleDef(
    'S-02',
    RuleBasis.evidence,
    'Each weekly sport session trims lifting volume for the muscles that sport works hardest: 0.5–1.5 sets per session, at most 4 per muscle, never below 4 sets.',
  ),
  RuleDef(
    'S-03',
    RuleBasis.evidence,
    'Sport days are fixed; lifting days move around them using the scheduling rules.',
  ),
  RuleDef(
    'S-04',
    RuleBasis.evidence,
    'Extra conditioning should be low-impact (bike, rower, swimming), short and hard or under an hour, after lifting or on other days.',
  ),
  RuleDef(
    'S-05',
    RuleBasis.evidence,
    'When the sport comes first, leg muscles are capped at 8 sets, sets stop further from failure and high-risk lifts are avoided.',
  ),
  RuleDef('S-06', RuleBasis.evidence, 'Energy burned in sports is added to your calorie target.'),
  // Nutrition: phase
  RuleDef(
    'N-PHS-01',
    RuleBasis.heuristic,
    'Your nutrition phase follows your goal (gain, maintain or lose) and you can override it.',
  ),
  RuleDef(
    'N-PHS-02',
    RuleBasis.evidence,
    'Spend at least four times as long gaining or maintaining as cutting.',
  ),
  RuleDef(
    'N-PHS-03',
    RuleBasis.evidence,
    'Muscle can be built at maintenance or in a small deficit, especially by newer lifters; higher body fat does not stop gains.',
  ),
  // Maintenance
  RuleDef(
    'N-MNT-01',
    RuleBasis.evidence,
    'Resting energy use is roughly 22 kcal per kg of bodyweight per day.',
  ),
  RuleDef(
    'N-MNT-02',
    RuleBasis.evidence,
    'Multiply by an activity factor for lifters: sedentary 1.3–1.6, lightly active 1.5–1.8, active 1.7–2.0, very active 1.9–2.2.',
  ),
  RuleDef(
    'N-MNT-03',
    RuleBasis.evidence,
    'Any maintenance estimate is rough; adjusting from your weight trend is what makes it accurate.',
  ),
  RuleDef(
    'N-MNT-04',
    RuleBasis.heuristic,
    'Your lifestyle factor excludes sports; those are added separately so they are not counted twice.',
  ),
  // Rate
  RuleDef(
    'N-RAT-01',
    RuleBasis.evidence,
    'Lose 0.5–1% of bodyweight per week; leaner people should stay near 0.5%.',
  ),
  RuleDef(
    'N-RAT-02',
    RuleBasis.evidence,
    'Gain per month: novices 1–2% of bodyweight, intermediates 0.5–1.5%, advanced up to 0.5%.',
  ),
  RuleDef(
    'N-RAT-03',
    RuleBasis.evidence,
    'About 7,700 kcal per kg of bodyweight change, so the daily calorie change ≈ weekly kg change × 1,100.',
  ),
  RuleDef(
    'N-RAT-04',
    RuleBasis.evidence,
    'Deficits much bigger than 500 kcal/day cost more muscle; the app warns above 750.',
  ),
  // Sport energy
  RuleDef(
    'N-SPT-01',
    RuleBasis.evidence,
    'Extra energy per 10 minutes of activity: light ≈ 0.44 kcal/kg, moderate ≈ 0.99, vigorous ≈ 1.54. Watches usually overestimate.',
  ),
  RuleDef(
    'N-SPT-02',
    RuleBasis.heuristic,
    'Sport intensity maps to cardio intensity: light → light, moderate → moderate, hard → vigorous, match → between moderate and vigorous.',
  ),
  RuleDef(
    'N-SPT-03',
    RuleBasis.heuristic,
    'Sport calories are averaged over the week and added to every day.',
  ),
  // Macros
  RuleDef(
    'N-PRO-01',
    RuleBasis.evidence,
    'Eat at least 1.6 g of protein per kg of bodyweight when gaining or maintaining.',
  ),
  RuleDef(
    'N-PRO-02',
    RuleBasis.evidence,
    'In a deficit, lean people (or anyone with unknown body fat) should eat at least 2.0 g/kg.',
  ),
  RuleDef(
    'N-FAT-01',
    RuleBasis.evidence,
    'Eat at least 40–60 g of fat per day depending on size; around a quarter of maintenance calories is a good default.',
  ),
  RuleDef(
    'N-CHO-01',
    RuleBasis.evidence,
    'Eat at least 2 g/kg of carbohydrate when gaining or maintaining and at least 1 g/kg in a deficit.',
  ),
  RuleDef(
    'N-MAC-01',
    RuleBasis.evidence,
    'Set protein first, then fat, then fill the rest of your calories with carbohydrate.',
  ),
  // Weigh-ins
  RuleDef(
    'N-WGT-01',
    RuleBasis.evidence,
    'Weigh in the morning after the bathroom and before eating. Daily swings of 1–2% are normal.',
  ),
  RuleDef(
    'N-WGT-02',
    RuleBasis.evidence,
    'Use the weekly average. A week needs at least 3 weigh-ins including a weekend day to be trusted.',
  ),
  RuleDef('N-WGT-03', RuleBasis.evidence, 'A 14–21-day running average shows the long-term trend.'),
  RuleDef(
    'N-WGT-04',
    RuleBasis.evidence,
    'Ignore the first week of a new gain or loss phase for rate decisions: water and food volume shift.',
  ),
  // Adjustments
  RuleDef(
    'N-ADJ-01',
    RuleBasis.evidence,
    'If weight did not move in the right direction in week one of a phase, adjust the activity factor by 0.2.',
  ),
  RuleDef(
    'N-ADJ-02',
    RuleBasis.evidence,
    'Judge rate over 2 weeks when losing (3 if light) and 3–4 weeks when gaining; adjust by 100–200 kcal if off target.',
  ),
  RuleDef(
    'N-ADJ-03',
    RuleBasis.evidence,
    'Wait at least 2 weeks after a calorie change before changing again.',
  ),
  RuleDef('N-ADJ-04', RuleBasis.evidence, 'Calorie cuts come from carbs and fat; protein stays the same.'),
  RuleDef(
    'N-ADJ-05',
    RuleBasis.evidence,
    'A stalled cut can also be fixed with about 2,500 more steps a day or a few short cardio sessions, kept apart from lifting.',
  ),
  RuleDef(
    'N-ADJ-06',
    RuleBasis.heuristic,
    'At maintenance, if weight drifts more than 0.25% per week over 3 weeks, adjust by 100–150 kcal.',
  ),
  RuleDef(
    'N-ACT-01',
    RuleBasis.evidence,
    'While losing fat or recomposing, walk at least about 7,000 steps a day. About 2,500 extra steps burn roughly 100 kcal; raise your daily count by no more than half at a time.',
  ),
  RuleDef(
    'N-ACT-02',
    RuleBasis.evidence,
    'Cardio is optional and comes second to lifting: keep it low-impact, on days without lifting and not the day before a leg day. Hard intervals count as hard training.',
  ),
];

final Map<String, RuleDef> RULES = {for (final x in RULE_LIST) x.id: x};
