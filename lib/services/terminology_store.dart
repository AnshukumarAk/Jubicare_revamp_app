import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// The master disease/symptom terminology (the "JubiCare disease list"
/// sheet), downloaded from GET /mobile/terminology and cached locally so
/// synonym matching, Related-symptoms and Likely-Conditions work offline.
///
/// Nothing medical is hardcoded here — the data is whatever the server's
/// imported sheet says. Matching mirrors the backend's rules:
/// lowercase + punctuation stripped + whitespace collapsed, exact synonym
/// equality first, then keyword containment (>= 4 chars, both directions).
class TerminologyStore extends ChangeNotifier {
  static const _kEntries = 'terminology_v1:entries';
  static const _kVersion = 'terminology_v1:version';

  final ApiClient client;
  TerminologyStore(this.client);

  List<TermEntry> _entries = const [];
  String? _version;
  bool _loading = false;

  List<TermEntry> get entries => _entries;
  bool get isLoaded => _entries.isNotEmpty;
  String? get version => _version;

  /// Test seam — inject entries without network/prefs (scoring tests).
  @visibleForTesting
  void debugSetEntries(List<TermEntry> list) {
    _entries = list;
  }

  /// Load the cached copy (instant, offline) — call once at startup.
  Future<void> loadCache() async {
    if (_entries.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kEntries);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _entries = list.map(TermEntry.fromJson).toList();
      _version = p.getString(_kVersion);
      notifyListeners();
    } catch (_) {/* corrupt cache — refresh() will rebuild it */}
  }

  /// Download the sheet if the server has a newer version. Safe to call on
  /// every app start; offline failures keep the cached copy.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final res = await client.get('/mobile/terminology');
      if (res is! Map) return;
      final version = res['version']?.toString();
      final list = (res['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (list.isEmpty) return;
      _entries = list.map(TermEntry.fromJson).toList();
      _version = version;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kEntries, jsonEncode(list));
      if (version != null) await p.setString(_kVersion, version);
      notifyListeners();
    } catch (_) {/* offline — cache keeps serving */} finally {
      _loading = false;
    }
  }

  // ── matching (mirrors backend mobile/terminology.py) ──────────────────

  // Keep every letter/number of every script (Devanagari included — Dart's
  // \w is ASCII-only, which silently deleted Hindi text before 2026-08-21).
  static final _punct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final _ws = RegExp(r'\s+');

  static String normalize(String? text) {
    if (text == null) return '';
    return transliterateDevanagari(text)
        .toLowerCase()
        .replaceAll(_punct, ' ')
        .replaceAll(_ws, ' ')
        .trim();
  }

  // ── Devanagari → Roman, so spoken/typed Hindi (बुखार) matches the
  // sheet's Roman-Hindi synonyms (bukhar). Pragmatic scheme: consonant
  // keeps its inherent 'a' unless followed by a matra/halant or ends the
  // word (schwa deletion); with `loose()` this lands on the sheet's
  // spellings. Same table lives in the backend's terminology.py.
  static const _dvCons = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n',
    'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n',
    'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
    'ष': 'sh', 'स': 's', 'ह': 'h', 'ज़': 'z', 'फ़': 'f',
    'ड़': 'r', 'ढ़': 'rh', 'क़': 'q', 'ख़': 'kh', 'ग़': 'g',
  };
  static const _dvVowel = {
    'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'i', 'उ': 'u', 'ऊ': 'u',
    'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
  };
  static const _dvMatra = {
    'ा': 'aa', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u', 'ृ': 'ri',
    'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
  };

  static String transliterateDevanagari(String text) {
    if (!text.codeUnits.any((c) => c >= 0x0900 && c <= 0x097F)) return text;
    final out = StringBuffer();
    final chars = text.split('');
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      if (_dvCons.containsKey(ch)) {
        out.write(_dvCons[ch]);
        final next = i + 1 < chars.length ? chars[i + 1] : '';
        final wordEnds = next.isEmpty ||
            !(next.codeUnits.first >= 0x0900 && next.codeUnits.first <= 0x097F);
        if (!_dvMatra.containsKey(next) && next != '्' && !wordEnds) {
          out.write('a'); // inherent vowel mid-word
        }
      } else if (_dvVowel.containsKey(ch)) {
        out.write(_dvVowel[ch]);
      } else if (_dvMatra.containsKey(ch)) {
        out.write(_dvMatra[ch]);
      } else if (ch == '्' || ch == '़' || ch == 'ः') {
        // halant / nukta / visarga — silent for matching purposes
      } else if (ch == 'ं' || ch == 'ँ') {
        out.write('n');
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  static final _repeat = RegExp(r'(.)\1+');

  /// Romanised-Hindi spelling tolerance: 'bukhaar' == 'bukhar'.
  static String loose(String text) =>
      text.replaceAllMapped(_repeat, (m) => m.group(1)!);

  /// Every (input → entry) match. One synonym may hit several entries
  /// ("saans phoolna" → COPD / Asthma / Wheezing) — all are returned.
  List<TermMatch> matchInputs(List<String> inputs) {
    if (_entries.isEmpty) return const [];
    final seen = <String>{};
    final out = <TermMatch>[];
    final emitted = <String>{};

    void emit(String raw, String norm, TermEntry e, String synonym) {
      final key = '$norm|${e.entryId}';
      if (!emitted.add(key)) return;
      out.add(TermMatch(input: raw, normalizedInput: norm,
          matchedSynonym: synonym, entry: e));
    }

    for (final raw in inputs) {
      final norm = normalize(raw);
      if (norm.isEmpty || !seen.add(norm)) continue;
      // Prefer entries whose standard_term overlaps with the input
      // (user 2026-08-27: sheet had "anxiety" and "cough." embedded as
      // SYNONYMS of "Open wound of the thorax" — a data leak — which
      // then let those chips inflate that unrelated entry's score. Keep
      // only leak-free exact matches when at least one exists; fall
      // back to all matches when none does.)
      final inputWords = norm.split(' ').where((w) => w.isNotEmpty).toSet();
      final primary = <MapEntry<TermEntry, int>>[];
      final secondary = <MapEntry<TermEntry, int>>[];
      for (final e in _entries) {
        for (var i = 0; i < e.normalizedSynonyms.length; i++) {
          if (e.normalizedSynonyms[i] == norm) {
            final stWords = normalize(e.standardTerm)
                .split(' ').where((w) => w.isNotEmpty).toSet();
            (inputWords.intersection(stWords).isNotEmpty
                ? primary : secondary).add(MapEntry(e, i));
          }
        }
      }
      final keep = primary.isNotEmpty ? primary : secondary;
      for (final pair in keep) {
        emit(raw.trim(), norm, pair.key, pair.key.synonyms[pair.value]);
      }
      if (keep.isNotEmpty) continue;
      // A dictated sentence matches through its words too, with
      // spelling-tolerant comparison ("bukhaar ho raha hai" → "bukhar").
      final candidates = <String>[
        norm,
        ...norm.split(' ').where((w) => w.length >= 4 && w != norm),
      ];
      // Stage 2: loose (spelling-tolerant) equality — with the same
      // standard-term-overlap preference so leaked synonyms can't slip
      // through this channel either (user 2026-08-27 — "Open wound of
      // the abdomen" was still trending after the stage-1 fix; leak
      // was via stage 2/3).
      final loosePrimary = <MapEntry<TermEntry, int>>[];
      final looseSecondary = <MapEntry<TermEntry, int>>[];
      for (final cand in candidates) {
        final lc = loose(cand);
        for (final e in _entries) {
          for (var i = 0; i < e.normalizedSynonyms.length; i++) {
            if (loose(e.normalizedSynonyms[i]) == lc) {
              final stWords = normalize(e.standardTerm)
                  .split(' ').where((w) => w.isNotEmpty).toSet();
              (inputWords.intersection(stWords).isNotEmpty
                  ? loosePrimary : looseSecondary).add(MapEntry(e, i));
            }
          }
        }
      }
      final looseKeep = loosePrimary.isNotEmpty ? loosePrimary : looseSecondary;
      var loose_ = false;
      for (final pair in looseKeep) {
        emit(raw.trim(), norm, pair.key, pair.key.synonyms[pair.value]);
        loose_ = true;
      }
      if (loose_) continue;
      // Stage 3: keyword containment — same overlap preference. A
      // containment hit to a completely unrelated standard_term is
      // almost always a data leak.
      for (final cand in candidates) {
        if (cand.length < 4) continue;
        if (kGenericMatchWords.contains(cand)) continue;
        final lc = loose(cand);
        final kwPrimary = <MapEntry<TermEntry, int>>[];
        final kwSecondary = <MapEntry<TermEntry, int>>[];
        for (final e in _entries) {
          for (var i = 0; i < e.normalizedSynonyms.length; i++) {
            final s = e.normalizedSynonyms[i];
            if (s.length < 4) continue;
            final ls = loose(s);
            if (s.contains(cand) || cand.contains(s) ||
                ls.contains(lc) || lc.contains(ls)) {
              final stWords = normalize(e.standardTerm)
                  .split(' ').where((w) => w.isNotEmpty).toSet();
              (inputWords.intersection(stWords).isNotEmpty
                  ? kwPrimary : kwSecondary).add(MapEntry(e, i));
            }
          }
        }
        for (final pair in (kwPrimary.isNotEmpty ? kwPrimary : kwSecondary)) {
          emit(raw.trim(), norm, pair.key, pair.key.synonyms[pair.value]);
        }
      }
    }
    return out;
  }

  /// Related symptoms by CO-OCCURRENCE (spec 2026-08-21): find the
  /// patient's symptoms in the sheet's Symptoms column; the OTHER
  /// symptoms of those same conditions are related. Patient's own
  /// symptoms excluded, duplicates collapsed, ranked by how many matched
  /// conditions share the symptom (stronger association first).
  List<String> relatedTerms(List<String> selected) {
    final matches = matchInputs(selected);
    final patientKeys = {
      for (final s in selected)
        if (normalize(s).isNotEmpty) loose(normalize(s)),
    };
    // Also consider entries whose SYMPTOMS column carries a patient
    // chip as a word — same fix as likely_conditions() (user 2026-08-27).
    final patientWordSets = <Set<String>>[
      for (final s in selected)
        {
          for (final w in normalize(s).split(' '))
            if (w.trim().isNotEmpty) loose(w.trim()),
        },
    ];
    final candidates = <TermEntry>[];
    final seenIds = <int>{};
    for (final m in matches) {
      if (seenIds.add(m.entry.entryId)) candidates.add(m.entry);
    }
    for (final e in _entries) {
      if (seenIds.contains(e.entryId)) continue;
      var matched = false;
      for (final sym in e.symptoms) {
        for (final chunk in sym.split(';')) {
          final ph = {
            for (final w in normalize(chunk).split(' '))
              if (w.trim().isNotEmpty) loose(w.trim()),
          };
          if (ph.isEmpty) continue;
          if (patientWordSets
              .any((chip) => chip.isNotEmpty && chip.every(ph.contains))) {
            seenIds.add(e.entryId);
            candidates.add(e);
            matched = true;
            break;
          }
        }
        if (matched) break;
      }
    }
    if (candidates.isEmpty) return const [];
    final freq = <String, int>{};
    final label = <String, String>{};
    for (final entry in candidates) {
      for (final sym in entry.symptoms) {
        // The sheet's Symptoms column mixes short names ("sore throat")
        // with full clinical sentences; only the names belong on a chip
        // (user 2026-08-22 "related symptoms showing wrong").
        if (sym.trim().length > 40) continue;
        final key = loose(normalize(sym));
        if (key.isEmpty) continue;
        if (patientKeys.any((p) =>
            key == p || key.contains(p) || p.contains(key))) {
          continue; // already on the patient
        }
        freq[key] = (freq[key] ?? 0) + 1;
        label.putIfAbsent(key, () => sym);
      }
    }
    // Precision filter (user 2026-08-26): with 3+ patient symptoms
    // matching many conditions, a plain union surfaces random long-tail
    // symptoms (e.g. Low mood + body pain + Fatigue was showing bleeding,
    // swelling, palpitations). Require the term to CO-OCCUR in ≥2
    // matched conditions before we call it "related". Fall back to the
    // old top-N only when nothing crosses the co-occurrence bar (so
    // single-symptom cases keep working).
    final coOccurring = freq.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (coOccurring.isNotEmpty) {
      return [for (final e in coOccurring.take(8)) label[e.key]!];
    }
    final keys = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    return [for (final k in keys.take(8)) label[k]!];
  }

  /// Which of [entry]'s red flags appear in the patient's symptoms /
  /// transcript — word-level, spelling-tolerant containment.
  List<String> redFlagHits(List<String> inputs, TermEntry entry) {
    final cands = <String>{};
    for (final raw in inputs) {
      final norm = normalize(raw);
      if (norm.isEmpty) continue;
      cands.add(loose(norm));
      for (final w in norm.split(' ')) {
        if (w.length >= 4) cands.add(loose(w));
      }
    }
    return [
      for (final flag in entry.redFlags)
        if (cands.any((c) =>
            c.isNotEmpty && loose(normalize(flag)).contains(c)))
          flag,
    ];
  }

  /// The entry whose standard term matches [name] (case-insensitive).
  TermEntry? entryByTerm(String name) {
    final key = normalize(name);
    for (final e in _entries) {
      if (normalize(e.standardTerm) == key) return e;
    }
    return null;
  }

  /// Rank conditions for the case. Mirrors the server formula so the two
  /// agree when both run:
  ///   score = round(100 * (0.7 * caseMatch + 0.3 * villageShare))
  /// caseMatch    — matched inputs for the condition / all matched inputs.
  /// villageShare — the condition's slice of the village trending
  ///                frequencies (from /appointments/{id}/advisory), 0 when
  ///                no trend data is cached.
  List<ScoredCondition> likelyConditions(List<String> selected,
      {List<Map<String, dynamic>> trending = const []}) {
    final matches = matchInputs(selected);

    final entryInputs = <int, Set<String>>{};
    final entryOf = <int, TermEntry>{};
    for (final m in matches) {
      entryInputs.putIfAbsent(m.entry.entryId, () => <String>{})
          .add(m.normalizedInput);
      entryOf[m.entry.entryId] = m.entry;
    }
    // Also make every entry whose SYMPTOMS column carries any patient
    // chip a scoring candidate (user 2026-08-27: users type presenting
    // words like "Retro-orbital pain" or "sardi-zukam" that live in the
    // Symptoms column, not just Synonyms — matching should honour
    // both). Scoring below then decides how strongly each candidate
    // fits — a Symptoms-only match still counts, a Synonyms match may
    // stack on top.
    final patientLooseWords = <Set<String>>[
      for (final s in selected)
        {
          for (final w in normalize(s).split(' '))
            if (w.trim().isNotEmpty) loose(w.trim()),
        },
    ];
    for (final e in _entries) {
      if (entryOf.containsKey(e.entryId)) continue;
      var matched = false;
      for (final sym in e.symptoms) {
        for (final chunk in sym.split(';')) {
          final ph = {
            for (final w in normalize(chunk).split(' '))
              if (w.trim().isNotEmpty) loose(w.trim()),
          };
          if (ph.isEmpty) continue;
          if (patientLooseWords
              .any((chip) => chip.isNotEmpty && chip.every(ph.contains))) {
            entryOf[e.entryId] = e;
            entryInputs[e.entryId] = <String>{};
            matched = true;
            break;
          }
        }
        if (matched) break;
      }
    }
    if (entryOf.isEmpty) return const [];
    final totalInputs =
        entryInputs.values.expand((s) => s).toSet().length;

    // Village share by matching trending terms to entries.
    final trendFreq = <int, int>{};
    var trendTotal = 0;
    for (final t in trending) {
      final freq = (t['frequency'] as num?)?.toInt() ?? 0;
      trendTotal += freq;
      for (final m in matchInputs([t['term']?.toString() ?? ''])) {
        trendFreq[m.entry.entryId] = (trendFreq[m.entry.entryId] ?? 0) + freq;
      }
    }

    // Patient chips as WORD lists, for the SYMPTOMS-column signal.
    // Word-boundary matching only (user 2026-08-27: substring containment
    // let the condition symptom "Pain" hit the chip "Leg pain" and the
    // chip "anxiety" hit any long sentence mentioning anxiety, inflating
    // Traumatic wound / Hypertension to the top). A chip counts against
    // a condition when EVERY content word of the chip appears as a word
    // in at least one of that condition's symptom phrases — and we count
    // DISTINCT MATCHED CHIPS (÷ patientN), never condition phrases, so
    // one chip can contribute at most 1.
    final patientChips = <List<String>>[];
    for (final s in selected) {
      final ws = [
        for (final w in normalize(s).split(' '))
          if (w.trim().isNotEmpty) loose(w.trim()),
      ];
      // Chip must carry at least one non-generic word ("pain" alone
      // can't implicate every painful condition).
      if (ws.isNotEmpty && ws.any((w) => !kGenericMatchWords.contains(w))) {
        patientChips.add(ws);
      }
    }
    final patientN = patientChips.length;

    final out = <ScoredCondition>[];
    entryInputs.forEach((id, inputs) {
      final entry = entryOf[id]!;
      // Denominator = ALL content chips of the case, not just the ones
      // that happened to match some synonym (user 2026-08-27: with
      // chips Fever+Headache, a fever-only condition scored the same
      // 70% as a fever+headache condition because headache never
      // entered the matched-inputs denominator).
      final synDen = patientN > 0 ? patientN : totalInputs;
      final synMatch = synDen == 0
          ? 0.0
          : (inputs.length > synDen ? 1.0 : inputs.length / synDen);
      final share = trendTotal == 0 ? 0.0 : (trendFreq[id] ?? 0) / trendTotal;
      // Flat phrase matching — every phrase gives full 1.0 per matched
      // chip regardless of length (user 2026-08-29: two-tier was
      // penalising narrative-buried genuine symptoms like Dengue's Fever
      // and the standalone Fever entry). The 30% village_share bonus
      // suppresses AIDS-type paragraph noise once real diagnosis data
      // lands — noisy entries have 0 village diagnoses, real conditions
      // pick up 10%+ share and dominate.
      final phrases = <Set<String>>[];
      for (final sym in entry.symptoms) {
        for (final chunk in sym.split(';')) {
          final ph = {
            for (final w in normalize(chunk).split(' '))
              if (w.trim().isNotEmpty) loose(w.trim()),
          };
          if (ph.isNotEmpty) phrases.add(ph);
        }
      }
      var chipHits = 0;
      for (final chip in patientChips) {
        if (phrases.any((ph) => chip.every(ph.contains))) chipHits++;
      }
      final symMatch = patientN == 0 ? 0.0 : chipHits / patientN;
      final caseMatch = synMatch > symMatch ? synMatch : symMatch;
      // 70/30 (user 2026-08-28 final) — mirrors the server's
      // CASE_WEIGHT / VILLAGE_WEIGHT.
      final pct = (100 * (0.7 * caseMatch + 0.3 * share)).round();
      if (pct <= 0) return;
      out.add(ScoredCondition(
        name: entry.standardTerm,
        icd11: entry.icd11Code,
        pct: pct.clamp(0, 100),
        caseMatch: caseMatch,
        villageShare: share,
      ));
    });
    // Final rule (user 2026-08-28): village-diagnosed conditions ride
    // their 30% bonus to the top; symptom-only matches stay visible
    // below — no hard filtering.
    out.sort((a, b) => b.pct != a.pct
        ? b.pct.compareTo(a.pct)
        : a.name.compareTo(b.name));
    return out.take(5).toList(); // top five (spec 2026-08-21)
  }
}

class TermEntry {
  final int entryId;
  final String category;
  final String subCategory;
  final String standardTerm;
  final String? icd11Code;
  final List<String> synonyms;
  final List<String> normalizedSynonyms;
  // Clinical knowledge columns of the master sheet (2026-08-21):
  // the condition's symptom profile, escalation red flags, and the
  // literature reference — the only approved advisory sources.
  final List<String> symptoms;
  final List<String> redFlags;
  final String reference;
  final Set<String> normalizedSymptomKeys;

  TermEntry({required this.entryId, required this.category,
      required this.subCategory, required this.standardTerm,
      required this.icd11Code, required this.synonyms,
      this.symptoms = const [], this.redFlags = const [],
      this.reference = ''})
      : normalizedSynonyms =
            synonyms.map(TerminologyStore.normalize).toList(),
        normalizedSymptomKeys = {
          for (final s in symptoms)
            TerminologyStore.loose(TerminologyStore.normalize(s)),
        };

  factory TermEntry.fromJson(Map<String, dynamic> j) => TermEntry(
        entryId: (j['entry_id'] as num?)?.toInt() ?? 0,
        category: (j['category'] ?? '').toString(),
        subCategory: (j['sub_category'] ?? '').toString(),
        standardTerm: (j['standard_term'] ?? '').toString(),
        icd11Code: j['icd11_code']?.toString(),
        synonyms: (j['synonyms'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        symptoms: (j['symptoms'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        redFlags: (j['red_flags'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        reference: (j['reference'] ?? '').toString(),
      );
}

/// Words too generic to identify a condition on their own — shared by
/// the containment matcher and the scoring chip filter (2026-08-27).
const Set<String> kGenericMatchWords = {'pain', 'ache', 'dard', 'of',
  'the', 'and', 'or', 'in', 'on', 'at', 'to', 'a', 'an', 'with'};

class TermMatch {
  final String input;
  final String normalizedInput;
  final String matchedSynonym;
  final TermEntry entry;
  const TermMatch({required this.input, required this.normalizedInput,
      required this.matchedSynonym, required this.entry});
}

class ScoredCondition {
  final String name;
  final String? icd11;
  final int pct;
  // Raw components — the village-first filter reads these (2026-08-28).
  final double? caseMatch;
  final double? villageShare;
  const ScoredCondition({required this.name, this.icd11, required this.pct,
      this.caseMatch, this.villageShare});
  String get level => pct >= 60 ? 'h' : (pct >= 35 ? 'm' : 'l');
}
