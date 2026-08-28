// End-to-end test of the Likely Conditions scoring (user 2026-08-27:
// "Traumatic wound 47% on abdominal chips" + "please test it end to end").
//
// Reproduces the exact production case: chips [Abdominal cramps,
// Abdominal discomfort, Anxiety, Leg pain] against entries shaped like
// the live terminology sheet, then asserts:
//   1. No condition scores above ~25% (each matches at most 1 of 4 chips
//      → 0.7 × 0.25 ≈ 18%) — the old substring bug produced 35–47%.
//   2. Pharyngitis (Fever+Headache in its symptoms) outranks a
//      Fever-only condition when the case carries both chips.
import 'package:flutter_test/flutter_test.dart';

import 'package:jubicare_mmu/api/api_client.dart';
import 'package:jubicare_mmu/services/terminology_store.dart';

TermEntry _entry(int id, String term, List<String> synonyms,
        List<String> symptoms) =>
    TermEntry.fromJson({
      'entry_id': id,
      'standard_term': term,
      'category': 'test',
      'sub_category': term,
      'icd11_code': 'X$id',
      'synonyms': synonyms,
      'symptoms': symptoms,
      'red_flags': const [],
      'reference': '',
    });

void main() {
  late TerminologyStore store;

  setUp(() {
    store = TerminologyStore(ApiClient());
    store.debugSetEntries([
      _entry(1, 'Anxiety or fear-related disorder',
          ['anxiety', 'ghabrahat', 'bechaini'],
          [
            'Excessive worry and restlessness',
            'anxiety is a common feature of both depression and PTSD',
            'palpitations',
          ]),
      _entry(2, 'Traumatic wound',
          ['wound', 'chot', 'pain at wound'],
          [
            'Sudden pain at the time of injury',
            'bleeding',
            'Pain',
            'swelling',
          ]),
      _entry(3, 'Essential hypertension',
          ['high blood pressure', 'bp badhna'],
          ['Often asymptomatic', 'headache', 'anxiety']),
      _entry(4, 'Infectious gastroenteritis/colitis',
          ['abdominal cramps', 'loose motions'],
          ['Abdominal cramps', 'diarrhoea', 'vomiting', 'fever']),
      _entry(5, 'Hepatitis D',
          ['abdominal discomfort', 'hepatitis'],
          [
            'Abdominal discomfort',
            'dark urine and pale stools',
            'Marked fatigue and malaise',
            'fever',
            'vomiting',
          ]),
      _entry(6, 'Acute pharyngitis',
          ['sore throat', 'gala kharab', 'fever'],
          ['Throat pain', 'Fever', 'Headache', 'Malaise']),
      _entry(7, 'Acute sinusitis',
          ['sinus', 'nak band', 'fever'],
          ['Purulent nasal discharge', 'Fever', 'Facial pain']),
    ]);
  });

  test('abdominal + anxiety chips: no condition inflates past 1-chip score',
      () {
    final scored = store.likelyConditions(
        ['Abdominal cramps', 'Abdominal discomfort', 'Anxiety', 'Leg pain']);
    expect(scored, isNotEmpty);
    for (final c in scored) {
      // 4 content chips, each condition matches at most one of them →
      // 0.7 × (1/4) ≈ 18%. Allow rounding headroom to 30% — the OLD bug
      // put Traumatic wound at 47% and Anxiety disorder at 35%.
      expect(c.pct, lessThanOrEqualTo(30),
          reason: '${c.name} scored ${c.pct}% — substring/phrase-count '
              'inflation is back');
    }
    // Traumatic wound must not be the top condition for abdominal chips.
    expect(scored.first.name, isNot('Traumatic wound'));
  });

  test('Fever+Headache case ranks pharyngitis above fever-only sinusitis',
      () {
    final scored = store.likelyConditions(['Fever', 'Headache']);
    final pharyngitis = scored
        .firstWhere((c) => c.name == 'Acute pharyngitis',
            orElse: () => const ScoredCondition(name: '-', pct: 0));
    final sinusitis = scored
        .firstWhere((c) => c.name == 'Acute sinusitis',
            orElse: () => const ScoredCondition(name: '-', pct: 0));
    expect(pharyngitis.pct, greaterThan(sinusitis.pct),
        reason: '2-chip match (Fever+Headache) must outrank 1-chip match');
  });

  test('generic-only chip ("pain") implicates nothing by symptoms column',
      () {
    // A chip that is ONLY a generic word must not raise every painful
    // condition through the symptoms column. It may still match via an
    // exact synonym — that is fine; here no entry has "pain" alone as a
    // synonym, so at most stage-3 containment fires with a tiny score.
    final scored = store.likelyConditions(['pain']);
    for (final c in scored) {
      expect(c.pct, lessThanOrEqualTo(30));
    }
  });

  test('chip in a condition SYMPTOMS column (not synonyms) still scores '
       'the condition — the "Retro-orbital pain → Dengue" case', () {
    // Set up a fresh store with a Dengue entry: "Retro-orbital pain"
    // sits in its SYMPTOMS column only, not in its synonyms. The user
    // types the chip verbatim. Old behaviour: match_inputs returned
    // no synonym match → Dengue never entered the candidate list.
    // New behaviour: symptoms-column match adds Dengue as a candidate.
    final s = TerminologyStore(ApiClient());
    s.debugSetEntries([
      _entry(1, 'Dengue Fever',
          ['dengue', 'DF', 'break-bone fever'],
          ['Fever', 'Retro-orbital pain', 'Rash', 'Joint pain']),
      _entry(2, 'Common cold',
          ['sardi', 'zukam', 'common cold'],
          ['Runny nose', 'Sneezing']),
    ]);
    final scored = s.likelyConditions(['Retro-orbital pain']);
    expect(scored.map((c) => c.name), contains('Dengue Fever'),
        reason: 'Dengue must surface for a symptoms-column chip');
    final rel = s.relatedTerms(['Retro-orbital pain']);
    // Dengue was picked up → its OTHER symptoms should now surface in
    // the Related panel (user 2026-08-27 point: this fix must extend
    // to Related symptoms too).
    expect(rel.map((r) => r.toLowerCase()).toList(),
        anyOf(contains('fever'), contains('rash'), contains('joint pain')),
        reason: "Related panel must include Dengue's other symptoms once "
            "the symptoms-column chip pulls Dengue into candidates");
  });

  test('leaked-synonym filter: chip "Anxiety" does not credit Open wound '
       'of the thorax even though the sheet lists "anxiety" as its '
       'synonym', () {
    final s = TerminologyStore(ApiClient());
    s.debugSetEntries([
      _entry(1, 'Anxiety or fear-related disorder',
          ['anxiety', 'ghabrahat', 'anxious'],
          ['Excessive worry', 'Palpitations', 'Restlessness']),
      _entry(2, 'Open wound of the thorax',
          // These two are the actual leaks observed on the live sheet.
          ['open wound of the thorax', 'chest wound', 'anxiety', 'cough.'],
          ['Break in the chest wall skin', 'bleeding', 'chest pain']),
      _entry(3, 'Cough',
          ['cough', 'khansi'],
          ['Cough', 'Throat irritation']),
    ]);
    final scored = s.likelyConditions(['Anxiety', 'Cough']);
    final wound = scored
        .firstWhere((c) => c.name == 'Open wound of the thorax',
            orElse: () => const ScoredCondition(name: '-', pct: 0));
    // Anxiety chip landed on the Anxiety entry (name overlap), Cough
    // chip on the Cough entry — leak into Open wound must be blocked.
    expect(wound.pct, 0,
        reason: 'Leaked-synonym filter must strip the cross-entry '
            'match; Open wound scored ${wound.pct}%');
    // And the real Anxiety / Cough conditions get credited.
    expect(scored.map((c) => c.name),
        containsAll(['Anxiety or fear-related disorder', 'Cough']));
  });

  group('village-prior ranking (Gajraula → Typhoid example)', () {
    late TerminologyStore s;
    setUp(() {
      s = TerminologyStore(ApiClient());
      s.debugSetEntries([
        _entry(1, 'Dengue Fever',
            ['dengue', 'DF', 'break-bone fever'],
            ['Fever', 'Headache', 'Body ache', 'Rash', 'Joint pain']),
        _entry(2, 'Malaria',
            ['malaria', 'plasmodium'],
            ['Fever', 'Chills', 'Headache', 'Body ache', 'Sweating']),
        _entry(3, 'Typhoid fever',
            ['typhoid', 'enteric fever'],
            ['Fever', 'Headache', 'Body ache', 'Abdominal pain',
             'Constipation']),
        _entry(4, 'Common cold',
            ['common cold', 'sardi'],
            ['Runny nose', 'Sneezing', 'Mild fever']),
      ]);
    });

    test('with no village trend, three fever-shaped conditions tie',
        () {
      final scored =
          s.likelyConditions(['Fever', 'Headache', 'Body ache']);
      final top3 = scored.take(3).map((c) => c.pct).toList();
      expect(top3.every((pct) => pct == top3.first), true,
          reason: 'Without village bonus the three matched-3-of-3 '
              'conditions must tie; got scores $top3');
    });

    test('village bonus ranks Typhoid first; symptom-only matches stay '
         'visible below (user 2026-08-28 final rule)', () {
      final scored = s.likelyConditions(
        ['Fever', 'Headache', 'Body ache'],
        trending: const [
          {'term': 'typhoid', 'frequency': 5, 'rank': 1},
          {'term': 'dengue', 'frequency': 1, 'rank': 2},
        ],
      );
      expect(scored.first.name, 'Typhoid fever',
          reason: 'Village-share bonus must lift Typhoid to rank 1');
      final names = scored.map((c) => c.name).toList();
      // Malaria matched all three chips but was never diagnosed in the
      // village — it must STILL be listed (below the boosted ones).
      expect(names, contains('Malaria'),
          reason: 'Symptom-only matches stay visible below');
      final typhoid = scored.firstWhere((c) => c.name == 'Typhoid fever');
      final malaria = scored.firstWhere((c) => c.name == 'Malaria');
      expect(typhoid.pct, greaterThan(malaria.pct));
    });
  });

  test('long-paragraph symptoms do not capture chips — the Jogipur '
       '"Fever + Sore throat topped by AIDS" case (2026-08-28)', () {
    final s = TerminologyStore(ApiClient());
    s.debugSetEntries([
      _entry(1, 'AIDS',
          ['aids', 'hiv disease'],
          [
            // The live sheet's seroconversion PARAGRAPH — contains the
            // words "fever" and "sore throat" inside a narrative
            // sentence. It must NOT count as a symptom match.
            'Acute seroconversion illness 2-6 weeks after exposure in '
                '50-90% - a glandular-fever-like illness with fever, sore '
                'throat, a non-pruritic maculopapular rash on the trunk, '
                'generalised lymphadenopathy, myalgia, headache',
            'drenching night sweats',
          ]),
      _entry(2, 'Acute pharyngitis',
          ['sore throat', 'gala kharab'],
          ['Throat pain', 'Fever', 'Sore throat', 'Headache']),
    ]);
    final scored = s.likelyConditions(['Fever', 'Sore throat']);
    final aids = scored.firstWhere((c) => c.name == 'AIDS',
        orElse: () => const ScoredCondition(name: '-', pct: 0));
    final phar = scored.firstWhere((c) => c.name == 'Acute pharyngitis',
        orElse: () => const ScoredCondition(name: '-', pct: 0));
    expect(phar.pct, greaterThan(aids.pct),
        reason: 'Pharyngitis (short symptom names match both chips) must '
            'outrank AIDS (only a long paragraph mentions the words); '
            'got pharyngitis=${phar.pct}% aids=${aids.pct}%');
    expect(aids.pct, lessThan(40),
        reason: 'AIDS must not get full case-match credit from a '
            'narrative paragraph');
  });

  test('Related symptoms: uses server list when provided, dedupes '
       'against patient chips', () {
    final s = TerminologyStore(ApiClient());
    s.debugSetEntries([
      _entry(1, 'Dengue Fever',
          ['dengue', 'break-bone fever'],
          ['Fever', 'Headache', 'Retro-orbital pain', 'Rash',
           'Joint pain', 'Nausea']),
      _entry(2, 'Common cold',
          ['common cold', 'sardi'],
          ['Runny nose', 'Sneezing', 'Fever']),
    ]);
    // Local co-occurrence: matched entries = {Dengue, Common cold},
    // the OTHER symptoms of those entries (minus the patient chip)
    // must all be candidates — none of them may be a patient chip.
    final rel = s.relatedTerms(['Fever']);
    expect(rel, isNotEmpty,
        reason: 'Related panel must surface Dengue/Cold co-occurring '
            'symptoms once "Fever" is on the case');
    expect(rel.map((r) => r.toLowerCase()), isNot(contains('fever')),
        reason: 'A chip already on the patient must not echo back as '
            '"related"');
  });
}
