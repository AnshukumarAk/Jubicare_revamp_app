import 'package:flutter_test/flutter_test.dart';
import 'package:jubicare_mmu/api/queue_delta.dart';

/// The adapter is the whole risk in reading the queue as a delta: get a field
/// wrong and a patient shows up on the doctor's screen with no symptoms, no
/// diagnosis, or a medicine count of zero. These pin the three fields that
/// differ between /mobile/sync/pull and /queues/* against the shapes the
/// backend actually returns (mobile/shapes.py).
void main() {
  group('queueShapeFromSyncRow', () {
    test('symptom objects become the plain names the queue sends', () {
      final out = queueShapeFromSyncRow({
        'symptoms': [
          {'symptom_id': 1, 'symptom_name': 'Fever'},
          {'symptom_id': 2, 'symptom_name': 'Cough'},
        ],
      });
      expect(out['symptoms'], ['Fever', 'Cough']);
    });

    test('a visit with no symptoms gets an empty list, never null', () {
      // CounPatientDetail does symptoms.clear()..addAll(), so a null here
      // would throw rather than render an empty section.
      expect(queueShapeFromSyncRow({})['symptoms'], isEmpty);
      expect(queueShapeFromSyncRow({'symptoms': null})['symptoms'], isEmpty);
    });

    test('the flagged diagnosis wins, wherever it sits in the list', () {
      final out = queueShapeFromSyncRow({
        'diagnoses': [
          {'diagnosis_text': 'Anaemia', 'is_primary': false},
          {'diagnosis_text': 'Dengue Fever', 'is_primary': true},
        ],
      });
      expect(out['primary_diagnosis'], 'Dengue Fever');
    });

    test('with none flagged it falls back to the first, as the queue does', () {
      // Matches the queue view's next(primary, next(any, None)) — a visit
      // whose doctor never marked a primary still shows a "Likely" label.
      final out = queueShapeFromSyncRow({
        'diagnoses': [
          {'diagnosis_text': 'Anaemia', 'is_primary': false},
          {'diagnosis_text': 'Typhoid', 'is_primary': false},
        ],
      });
      expect(out['primary_diagnosis'], 'Anaemia');
    });

    test('no diagnoses leaves it null, which reads as an empty disease', () {
      expect(queueShapeFromSyncRow({})['primary_diagnosis'], isNull);
      expect(queueShapeFromSyncRow({'diagnoses': []})['primary_diagnosis'],
          isNull);
    });

    test('medicine_count counts items, not prescriptions', () {
      // sync/pull flattens every prescription's items into one list, which is
      // what the queue view sums.
      final out = queueShapeFromSyncRow({
        'prescriptions': [
          {'prescription_item_id': 1, 'medicine_name': 'Paracetamol'},
          {'prescription_item_id': 2, 'medicine_name': 'Vitamin C'},
          {'prescription_item_id': 3, 'medicine_name': 'ORS'},
        ],
      });
      expect(out['medicine_count'], 3);
    });

    test('no prescriptions is a count of zero, not null', () {
      expect(queueShapeFromSyncRow({})['medicine_count'], 0);
    });

    test('every other field is carried through untouched', () {
      // These come from the shared appointment_row() and are already in the
      // shape mergeBackendPatients reads — the adapter must not disturb them.
      final row = {
        'appointment_id': 4021,
        'patient_id': 915,
        'patient_name': 'Sunita Devi',
        'gender': 'Female',
        'age': 34,
        'contact_number': '9876543210',
        'unique_code': 'GN-0915',
        'village_name': 'Burablee',
        'block_name': 'Hasanpur',
        'status': 'with_doctor',
        'appointment_date': '2026-09-26',
        'pregnant': true,
        'lmp_date': '2026-06-01',
        'edd_date': '2027-03-08',
        'updated_at': '2026-09-26T16:38:53Z',
      };
      final out = queueShapeFromSyncRow(Map<String, dynamic>.from(row));
      for (final e in row.entries) {
        expect(out[e.key], e.value, reason: 'field ${e.key} was changed');
      }
    });

    test('the source row is not mutated', () {
      // The caller keeps the pull response for its cursor; rewriting its rows
      // underneath would be a nasty surprise.
      final src = <String, dynamic>{
        'symptoms': [
          {'symptom_id': 1, 'symptom_name': 'Fever'}
        ],
      };
      queueShapeFromSyncRow(src);
      expect(src['symptoms'], isA<List>());
      expect((src['symptoms'] as List).first, isA<Map>());
    });
  });

  group('newestUpdatedAt', () {
    test('picks the latest stamp regardless of row order', () {
      final newest = newestUpdatedAt([
        {'updated_at': '2026-09-26T10:00:00Z'},
        {'updated_at': '2026-09-26T16:38:53Z'},
        {'updated_at': '2026-09-26T12:15:00Z'},
      ]);
      expect(newest, '2026-09-26T16:38:53Z');
    });

    test('ignores rows with no stamp', () {
      final newest = newestUpdatedAt([
        {'updated_at': null},
        {'patient_id': 1},
        {'updated_at': ''},
        {'updated_at': '2026-09-26T09:00:00Z'},
      ]);
      expect(newest, '2026-09-26T09:00:00Z');
    });

    test('returns null when nothing carries one, so the caller stays full', () {
      // A null cursor means "keep doing full loads" — the safe direction. A
      // cursor guessed from the local clock could sit AHEAD of the server's
      // and skip rows permanently.
      expect(newestUpdatedAt([]), isNull);
      expect(newestUpdatedAt([{'patient_id': 1}]), isNull);
    });
  });
}
