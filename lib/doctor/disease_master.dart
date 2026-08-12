import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One ICD-11 diagnosis from the bundled JubiCare disease master.
class Disease {
  final String category;
  final String sub;
  final String term;
  final String icd;
  final String title;
  final List<String> synonyms;
  const Disease({required this.category, required this.sub, required this.term, required this.icd, required this.title, required this.synonyms});

  factory Disease.fromJson(Map<String, dynamic> j) => Disease(
        category: (j['category'] ?? '') as String,
        sub: (j['sub'] ?? '') as String,
        term: (j['term'] ?? '') as String,
        icd: (j['icd'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        synonyms: ((j['synonyms'] ?? const []) as List).map((e) => e.toString()).toList(),
      );

  /// "Acute nasopharyngitis · CA00"
  String get display => icd.isEmpty ? term : '$term · $icd';
}

/// Loads + caches the ICD-11 disease master from assets/diseases.json.
class DiseaseMaster {
  static List<Disease>? _all;
  static List<Disease> get all => _all ?? const [];
  static bool get isLoaded => _all != null;

  static Future<List<Disease>> load() async {
    if (_all != null) return _all!;
    final raw = await rootBundle.loadString('assets/diseases.json');
    final list = (jsonDecode(raw) as List).map((e) => Disease.fromJson(e as Map<String, dynamic>)).toList();
    list.sort((a, b) {
      final c = a.category.compareTo(b.category);
      return c != 0 ? c : a.term.compareTo(b.term);
    });
    _all = list;
    return list;
  }

  /// Search by clinical name / sub-category / ICD title / ICD code AND synonyms
  /// (so a lay/Hindi synonym like "sardi" suggests the standard term + code).
  static List<Disease> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((d) =>
        d.term.toLowerCase().contains(q) ||
        d.sub.toLowerCase().contains(q) ||
        d.title.toLowerCase().contains(q) ||
        d.icd.toLowerCase().contains(q) ||
        d.synonyms.any((s) => s.toLowerCase().contains(q))).toList();
  }

  /// Resolve a clinical-DB disease name to an ICD entry (used to ICD-code the
  /// AI advisory's "Apply"). Returns null when there is no confident match so
  /// the caller keeps the original name rather than a wrong ICD term.
  static Disease? resolve(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    final key = n.split('(').first.trim(); // drop any trailing "(...)"
    if (key.isEmpty) return null;
    // 1. Exact match on term / title / sub.
    for (final d in all) {
      if (d.term.toLowerCase() == key || d.title.toLowerCase() == key || d.sub.toLowerCase() == key) return d;
    }
    // 2. Exact synonym match (ignore blank synonyms — they would match anything).
    for (final d in all) {
      if (d.synonyms.any((s) => s.trim().isNotEmpty && s.trim().toLowerCase() == key)) return d;
    }
    // 3. Word-safe contains on term/sub (the whole key appears as a word run).
    bool hasWord(String hay) => hay == key || hay.startsWith('$key ') || hay.endsWith(' $key') || hay.contains(' $key ');
    for (final d in all) {
      if (hasWord(d.term.toLowerCase()) || hasWord(d.sub.toLowerCase())) return d;
    }
    return null;
  }
}
