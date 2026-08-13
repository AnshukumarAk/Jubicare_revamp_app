import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_errors.dart';
import '../api/patients_api.dart';
import '../counsellor/cstate.dart';
import '../counsellor/cw.dart';

/// Full clinical record for one patient, one visit per accordion panel.
///
/// A patient can attend the MMU many times, and the doctor reviewing a
/// finished case needs the whole thread, not just the row that happened to be
/// in memory. GET /api/patients/{id}/history returns every visit with its
/// symptoms, diagnoses, vitals, lab tests and prescription in a single call,
/// so this screen is one request regardless of how many visits there are.
class PatientHistoryScreen extends StatefulWidget {
  final CPatient patient;
  const PatientHistoryScreen({super.key, required this.patient});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _visits = const [];

  CPatient get p => widget.patient;

  /// Backend rows are keyed 'B<patient_id>' by mergeBackendPatients; locally
  /// registered ('P…') and demo-seed (numeric) rows have no server record.
  int? get _backendPatientId {
    if (!p.id.startsWith('B')) return null;
    return int.tryParse(p.id.substring(1));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = _backendPatientId;
    if (pid == null) {
      // Nothing to fetch — fall back to the single visit held in memory so
      // demo and offline-registered patients still render something useful.
      setState(() {
        _loading = false;
        _visits = [_visitFromLocal()];
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<PatientsApi>().history(pid);
      if (!mounted) return;
      final visits = <Map<String, dynamic>>[
        for (final v in (res['visits'] as List? ?? const []))
          if (v is Map) v.cast<String, dynamic>(),
      ];
      setState(() {
        // Already ordered newest-first by the server.
        _visits = visits.isEmpty ? [_visitFromLocal()] : visits;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Shape the in-memory CPatient like a server visit so one renderer covers
  /// both paths.
  Map<String, dynamic> _visitFromLocal() => {
        'appointment_date': p.regDate,
        'status': p.status,
        'symptoms': p.symptoms,
        'diagnoses': [
          for (final d in p.disease.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty))
            {'diagnosis_text': d},
        ],
        'lab_tests': [for (final t in p.tests) {'test_name': t}],
        'prescription': [
          for (final m in p.prescription)
            {
              'medicine_name': m.name,
              'dosage': m.dosage,
              'frequency': m.interval,
              'duration_days': m.days,
              'qty': m.qty,
              'dispensed': m.dispensed,
            },
        ],
        'observation': p.observations,
        'doctor_remarks': p.doctorRemarks,
        'counsellor_remarks': p.remarks,
        for (final e in p.vitals.entries) _localVitalKeys[e.key] ?? e.key: e.value,
      };

  static const _localVitalKeys = {
    'Systolic BP': 'systolic_bp',
    'Diastolic BP': 'diastolic_bp',
    'Blood Sugar': 'blood_sugar',
    'Body Temp (°F)': 'body_temp',
    'Oxygen Saturation': 'oxygen',
    'Hemoglobin': 'hemoglobin',
  };

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('Patient Record', style: ct(16, FontWeight.w700, C2.navy)),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(14), children: [
            _header(),
            if (_loading)
              const Padding(padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Could not load history', style: ct(13, FontWeight.w700, C2.danger)),
                const SizedBox(height: 4),
                Text(_error!, style: ct(12, FontWeight.w400, C2.text2)),
                const SizedBox(height: 10),
                COutlineButton('Retry', icon: Icons.refresh, onTap: _load),
              ]))
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Text(
                  _visits.length == 1 ? '1 visit' : '${_visits.length} visits · newest first',
                  style: ct(11.5, FontWeight.w500, C2.text2)),
              ),
              // Newest visit starts open — that's the one being reviewed.
              for (var i = 0; i < _visits.length; i++) _visitCard(_visits[i], open: i == 0),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _header() => CCard(child: Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center,
            decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle),
            child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
          Text('${p.gender}, ${p.age}y${p.contact.isEmpty ? '' : ' · ${p.contact}'}',
              style: ct(12, FontWeight.w400, C2.text2)),
          Text('${p.village.isEmpty ? '—' : p.village}'
              '${p.uniqueCode.isEmpty ? '' : ' · ${p.uniqueCode}'}',
              style: ct(11.5, FontWeight.w400, C2.text2)),
        ])),
      ]));

  Widget _visitCard(Map<String, dynamic> v, {required bool open}) {
    final date = _fmtDate('${v['appointment_date'] ?? ''}');
    final status = '${v['status'] ?? ''}';
    final dx = _diagnoses(v);
    final (advised, remarks) = _splitAdvisedTests('${v['doctor_remarks'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CCard(
        child: Theme(
          // ExpansionTile draws its own dividers; the card already has an edge.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: open,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            title: Row(children: [
              Expanded(child: Text(date.isEmpty ? 'Visit' : date,
                  style: ct(13.5, FontWeight.w700, C2.navy))),
              if (status.isNotEmpty) _statusChip(status),
            ]),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(dx.isEmpty ? 'No diagnosis recorded' : dx.join(', '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: ct(11.5, FontWeight.w400, C2.text2)),
            ),
            children: [
              _kv('Symptoms', _symptoms(v).join(', ')),
              _kv('Diagnosis', dx.join(', ')),
              _vitalsLine(v),
              _testsBlock(v, advised),
              _rxBlock(v),
              _kv('Observation', '${v['observation'] ?? ''}'),
              _kv('Doctor Remarks', remarks),
              _kv('Counsellor Remarks', '${v['counsellor_remarks'] ?? ''}'),
              if ('${v['doctor_name'] ?? ''}'.isNotEmpty)
                _kv('Seen by', '${v['doctor_name']}'),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _symptoms(Map<String, dynamic> v) => [
        for (final s in (v['symptoms'] as List? ?? const []))
          if (s is String) s.trim() else if (s is Map) '${s['symptom_name'] ?? ''}'.trim(),
      ]..removeWhere((s) => s.isEmpty);

  List<String> _diagnoses(Map<String, dynamic> v) => [
        for (final d in (v['diagnoses'] as List? ?? const []))
          if (d is Map) '${d['diagnosis_text'] ?? ''}'.trim(),
      ]..removeWhere((s) => s.isEmpty);

  /// Vitals render as one wrapped line — seven separate rows pushed the
  /// prescription off the screen on a phone.
  Widget _vitalsLine(Map<String, dynamic> v) {
    const specs = [
      ('BP', 'systolic_bp', 'diastolic_bp'),
      ('Sugar', 'blood_sugar', null),
      ('Temp', 'body_temp', null),
      ('SpO₂', 'oxygen', null),
      ('Hb', 'hemoglobin', null),
      ('Ht', 'height', null),
      ('Wt', 'weight', null),
    ];
    final parts = <String>[];
    for (final (label, a, b) in specs) {
      final va = _num(v[a]);
      if (va.isEmpty) continue;
      final vb = b == null ? '' : _num(v[b]);
      parts.add(vb.isEmpty ? '$label $va' : '$label $va/$vb');
    }
    return _kv('Vitals', parts.join('  ·  '));
  }

  /// Split a "Tests advised: A, B" line out of the doctor's remarks.
  ///
  /// This MMU has no lab desk, so the doctor advises tests rather than
  /// ordering them, and DoctorSubmitIn has no field for that — dcase.dart
  /// appends the line to doctor_remarks. Pulling it back out here keeps the
  /// record honest: the tests read under Tests, where someone looks for them,
  /// instead of showing '—' there while sitting in the remarks below.
  static (List<String>, String) _splitAdvisedTests(String raw) {
    const marker = 'tests advised:';
    final kept = <String>[];
    final tests = <String>[];
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.toLowerCase().startsWith(marker)) {
        tests.addAll(t
            .substring(marker.length)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty));
      } else {
        kept.add(line);
      }
    }
    return (tests, kept.join('\n').trim());
  }

  Widget _testsBlock(Map<String, dynamic> v, List<String> advised) {
    final tests = [
      for (final t in (v['lab_tests'] as List? ?? const []))
        if (t is Map) t.cast<String, dynamic>(),
    ];
    // No formally ordered tests, but the doctor advised some — render those.
    if (tests.isEmpty && advised.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TESTS ADVISED', style: ct(10.5, FontWeight.w700, C2.text2)),
          const SizedBox(height: 3),
          ...advised.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3, right: 6),
                      child: Icon(Icons.science_outlined, size: 13, color: C2.cyan)),
                  Expanded(child: Text(t, style: ct(12.5, FontWeight.w600, C2.text))),
                ]),
              )),
        ]),
      );
    }
    if (tests.isEmpty) return _kv('Tests', '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TESTS', style: ct(10.5, FontWeight.w700, C2.text2)),
        const SizedBox(height: 3),
        ...tests.map((t) {
          final result = '${t['result'] ?? ''}'.trim();
          final paid = t['paid'] == true;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 3, right: 6),
                  child: Icon(Icons.science_outlined, size: 13, color: C2.cyan)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['test_name'] ?? '—'}', style: ct(12.5, FontWeight.w600, C2.text)),
                Text(
                  result.isEmpty
                      ? (paid ? 'Paid · result pending' : 'Payment pending')
                      : 'Result: $result',
                  style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _rxBlock(Map<String, dynamic> v) {
    final rx = [
      for (final r in (v['prescription'] as List? ?? const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];
    if (rx.isEmpty) return _kv('Prescription', '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PRESCRIPTION', style: ct(10.5, FontWeight.w700, C2.text2)),
        const SizedBox(height: 3),
        ...rx.map((m) {
          final dosage = '${m['dosage'] ?? ''}'.trim();
          final freq = '${m['frequency'] ?? ''}'.trim();
          final days = '${m['duration_days'] ?? ''}'.trim();
          final qty = '${m['qty'] ?? ''}'.trim();
          final sub = [
            if (freq.isNotEmpty) freq,
            if (days.isNotEmpty) days.endsWith('Days') ? days : '$days Days',
            if (qty.isNotEmpty) 'Qty $qty',
          ].join(' · ');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 3, right: 6),
                  child: Icon(Icons.medication_outlined, size: 13, color: C2.cyan)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dosage.isEmpty
                        ? '${m['medicine_name'] ?? '—'}'
                        : '${m['medicine_name'] ?? '—'} · $dosage',
                    style: ct(12.5, FontWeight.w600, C2.text)),
                if (sub.isNotEmpty) Text(sub, style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              if (m['dispensed'] == true)
                CBadge('Dispensed', bg: const Color(0xFFEDF7E0), fg: C2.green),
            ]),
          );
        }),
      ]),
    );
  }

  /// Blank values still render a row so the record reads as "nothing recorded"
  /// rather than silently omitting a field the doctor expects to see.
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 108, child: Text(k, style: ct(11.5, FontWeight.w500, C2.text2))),
          Expanded(child: Text(v.trim().isEmpty ? '—' : v, style: ct(12.5, FontWeight.w400, C2.text))),
        ]),
      );

  Widget _statusChip(String status) {
    final (label, bg, fg) = switch (status) {
      'completed'       => ('Completed', const Color(0xFFEDF7E0), C2.green),
      'with_pharma'     => ('At Pharmacy', C2.cyanLight, C2.cyan),
      'with_counsellor' => ('Awaiting Test Payment', const Color(0xFFFEF7E0), const Color(0xFFB8860B)),
      'with_lab'        => ('At Lab', C2.cyanLight, C2.cyan),
      'with_doctor'     => ('In Progress', C2.cyanLight, C2.cyan),
      'registered'      => ('Waiting', const Color(0xFFFEF7E0), const Color(0xFFB8860B)),
      _                 => (status, C2.cyanLight, C2.cyan),
    };
    return CBadge(label, bg: bg, fg: fg);
  }

  /// Trailing .0 on a numeric column reads as a typo on a clinical record.
  static String _num(Object? v) {
    if (v == null) return '';
    if (v is num) return v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    final n = num.tryParse(s);
    return n != null ? _num(n) : s;
  }

  /// '2026-08-13' → '13-08-2026', matching fmtDate. Values already in the
  /// app's own format (local rows) pass through untouched.
  static String _fmtDate(String v) {
    if (v.length < 10) return v;
    final p = v.substring(0, 10).split('-');
    if (p.length != 3 || p[0].length != 4) return v;
    return '${p[2]}-${p[1]}-${p[0]}';
  }
}
