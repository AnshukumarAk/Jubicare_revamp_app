import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'ddata.dart';

/// Loads the JubiCare clinical decision-support database
/// (assets/kdoctordb.json — 158 conditions with symptom weights, tests,
/// red flags, first-line text and sourced regimens) and swaps it in over
/// the small built-in [kDoctorDb] (user 2026-08-22 "use this json for the
/// AI Clinical Advisory card"). The advisory card, its Apply button and
/// the likely-condition scoring all read [doctorDb], so one load makes
/// every surface dynamic. Asset unreadable → the built-in map stays.
class DoctorDbLoader {
  DoctorDbLoader._();

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/kdoctordb.json');
      final data = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final out = <String, DPlan>{};
      for (final e in (data['conditions'] as List? ?? const [])) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final plan = DPlan(
          symptoms: {
            for (final s in ((m['symptoms'] as Map?) ?? const {}).entries)
              s.key.toString(): (s.value as num?)?.toInt() ?? 1,
          },
          tests: [
            for (final t in (m['tests'] as List? ?? const [])) t.toString()
          ],
          redFlags: [
            for (final t in (m['redFlags'] as List? ?? const [])) t.toString()
          ],
          firstLine: (m['firstLine'] ?? '').toString(),
          rx: [
            for (final l in (m['rx'] as List? ?? const []))
              if (l is Map)
                DRx(
                  (l['drug'] ?? '').toString(),
                  '${(l['durationDays'] as num?)?.toInt() ?? 5}',
                  (l['frequency'] ?? 'OD').toString(),
                  (l['qty'] as num?)?.toInt() ?? 0,
                ),
          ],
        );
        // Index by EVERY safe key (user 2026-08-26 "Acute sinusitis
        // advisory was showing Viral Fever's tests/Rx"): the terminology
        // sheet's ScoredCondition.name can carry either `standardTerm`
        // or a sub-name, and case/whitespace can drift between JSON
        // sources. Register the plan under all of these so lookup finds
        // it whichever name the advisory carries.
        final std = (m['standardTerm'] ?? '').toString().trim();
        final common = (m['condition'] ?? '').toString().trim();
        final icd = (m['icd11'] ?? '').toString().trim();
        for (final k in {std, common, icd}) {
          if (k.isNotEmpty) out.putIfAbsent(k, () => plan);
          if (k.isNotEmpty) out.putIfAbsent(k.toLowerCase(), () => plan);
        }
      }
      if (out.isNotEmpty) {
        doctorDb = out;
        _loaded = true;
      }
    } catch (_) {
      // Asset missing/corrupt — the built-in kDoctorDb keeps working.
    }
  }
}
