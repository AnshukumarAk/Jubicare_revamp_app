/// Reading the queue as a delta instead of downloading it whole.
///
/// The Home screens pull four status-scoped queue endpoints, each capped at
/// 200 rows, every thirty seconds and again on every FCM ping — up to 800
/// rows to learn that one patient was registered, or that nothing happened
/// at all. `/mobile/sync/pull?updated_since=` answers the same question with
/// the rows that actually changed.
///
/// Why that endpoint and not `updated_since` on the queues themselves: the
/// queue views apply their status filter BEFORE the timestamp filter, so a
/// visit that moves from with_doctor to with_pharmacist simply stops
/// appearing. The handset would never learn to drop it and the patient would
/// sit in the doctor's queue for ever. The sync view filters only by team,
/// so a visit that moves comes back carrying its new status and the app
/// re-files it.
///
/// The two endpoints return the same `appointment_row()` underneath; three
/// fields are shaped differently, and [queueShapeFromSyncRow] is the whole
/// difference.
library;

import 'sync_api.dart';

/// One screen's place in the stream of changes.
///
/// Shared by all three role shells so the rules below are written once
/// rather than three times, each drifting on its own.
class QueueDelta {
  String? _cursor;

  /// False until a full load has seeded a starting point.
  bool get isReady => _cursor != null;

  /// Forget where we were — the next refresh loads everything. Called when a
  /// screen wants a clean slate, and implied at app start because this object
  /// is never persisted.
  void reset() => _cursor = null;

  /// Start the next delta from the newest row a full load actually returned.
  ///
  /// Never from the handset's clock: a cursor running behind the server costs
  /// a few duplicate rows, one running ahead skips rows permanently. When no
  /// row carries a stamp this stays unseeded and the caller keeps doing full
  /// loads — the safe direction.
  void seedFrom(Iterable<Map<String, dynamic>> rows) =>
      _cursor = newestUpdatedAt(rows);

  /// The rows that changed, already in queue shape.
  ///
  /// Returns null to mean "load everything instead", which is the answer to
  /// anything unexpected: no cursor yet, the request failed, or a full page
  /// came back meaning more is waiting. Paging through a large backlog would
  /// be slower than the full load and has more ways to go wrong.
  ///
  /// An empty list is a real answer — nothing changed — and is the common
  /// case. Measured on live, that response is 192 bytes against the 168 KB a
  /// full doctor refresh costs.
  Future<List<Map<String, dynamic>>?> changedRows(SyncApi api,
      {int perPage = 200}) async {
    final cursor = _cursor;
    if (cursor == null) return null;
    final PullResponse res;
    try {
      res = await api.pull(updatedSinceRaw: cursor, perPage: perPage);
    } catch (_) {
      return null;
    }
    if (res.hasMore) return null;
    if (res.cursor.isNotEmpty) _cursor = res.cursor;
    return [for (final r in res.appointments) queueShapeFromSyncRow(r)];
  }
}

/// One `/mobile/sync/pull` appointment row, in the shape the `/queues/*`
/// endpoints return — which is what `CounsellorState.mergeBackendPatients`
/// reads.
///
/// Only three fields differ. Everything else — patient_name, gender, age,
/// contact_number, unique_code, village_name, block_name, status,
/// appointment_date, the pregnancy block — comes straight out of the shared
/// `appointment_row()` and is already correct.
Map<String, dynamic> queueShapeFromSyncRow(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);

  // symptoms: [{symptom_id, symptom_name}] -> ["Fever", "Cough"]
  final syms = row['symptoms'];
  out['symptoms'] = syms is List
      ? <String>[
          for (final s in syms)
            if (s is Map && s['symptom_name'] != null)
              s['symptom_name'].toString()
            else if (s is String)
              s,
        ]
      : const <String>[];

  // primary_diagnosis: the flagged one, else the first. Same fallback the
  // queue view applies, so a visit whose doctor never marked a primary still
  // shows its diagnosis rather than a blank "Likely" label.
  final dx = row['diagnoses'];
  String? primary;
  if (dx is List) {
    for (final d in dx) {
      if (d is Map && d['is_primary'] == true && d['diagnosis_text'] != null) {
        primary = d['diagnosis_text'].toString();
        break;
      }
    }
    if (primary == null) {
      for (final d in dx) {
        if (d is Map && d['diagnosis_text'] != null) {
          primary = d['diagnosis_text'].toString();
          break;
        }
      }
    }
  }
  out['primary_diagnosis'] = primary;

  // medicine_count: the sync row's `prescriptions` is already a flat list of
  // items across every prescription on the visit, which is exactly what the
  // queue view counts.
  final rx = row['prescriptions'];
  out['medicine_count'] = rx is List ? rx.length : 0;

  return out;
}

/// The newest `updated_at` among [rows], as the server printed it.
///
/// Used to start a delta from a full load. The strings are ISO-8601 from a
/// single server clock, so comparing them as text orders them correctly and
/// avoids a parse per row.
///
/// Returns null when no row carries one, and the caller then keeps doing full
/// loads — the safe direction. A cursor that is too OLD costs a few extra
/// rows; one that is too NEW skips rows for ever, which is why this never
/// reaches for the local clock.
String? newestUpdatedAt(Iterable<Map<String, dynamic>> rows) {
  String? newest;
  for (final r in rows) {
    final v = r['updated_at'];
    if (v == null) continue;
    final s = v.toString();
    if (s.isEmpty) continue;
    if (newest == null || s.compareTo(newest) > 0) newest = s;
  }
  return newest;
}
