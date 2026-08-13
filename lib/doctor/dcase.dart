import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/appointments_api.dart';
import '../api/sync_service.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/symptom_field.dart';
import '../services/connectivity_service.dart';
import 'ddata.dart';
import 'disease_master.dart';
import 'voice.dart';

class DoctorCaseDetails extends StatefulWidget {
  final CPatient patient;
  const DoctorCaseDetails({super.key, required this.patient});
  @override
  State<DoctorCaseDetails> createState() => _DoctorCaseDetailsState();
}

// The vitals keys the counsellor Register form writes into CPatient.vitals.
// Doctor's editable Vitals card mirrors the same set + order so the update
// overwrites the same map keys and the values flow onward unchanged.
const List<({String key, String label, String hint})> _kVitalSpecs = [
  (key: 'Systolic BP',       label: 'Systolic BP',        hint: 'e.g. 120'),
  (key: 'Diastolic BP',      label: 'Diastolic BP',       hint: 'e.g. 80'),
  (key: 'Blood Sugar',       label: 'Blood Sugar',        hint: 'e.g. 110'),
  (key: 'Body Temp (°F)',    label: 'Body Temp (°F)',     hint: 'e.g. 98.6'),
  (key: 'Oxygen Saturation', label: 'Oxygen Saturation',  hint: '%'),
  (key: 'Heart Rate',        label: 'Heart Rate',         hint: 'bpm'),
  (key: 'Hemoglobin',        label: 'Hemoglobin',         hint: 'g/dL'),
];

// _kVitalSpecs label -> the column GET /api/appointments/{id} returns it as.
// Heart Rate has no counterpart: the appointment table stores no heart-rate
// column, so that field stays empty for the doctor to fill in.
const Map<String, String> _kVitalColumns = {
  'Systolic BP':       'systolic_bp',
  'Diastolic BP':      'diastolic_bp',
  'Blood Sugar':       'blood_sugar',
  'Body Temp (°F)':    'body_temp',
  'Oxygen Saturation': 'oxygen',
  'Hemoglobin':        'hemoglobin',
};

/// Readings come back as int, double or numeric string depending on column.
/// Render 120.0 as '120' so the field reads the way it was typed, and treat
/// 0 as "not recorded" rather than a real measurement.
String _fmtVital(Object? v) {
  if (v == null) return '';
  if (v is num) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null') return '';
  final n = num.tryParse(s);
  return n != null ? _fmtVital(n) : s;
}

class _DoctorCaseDetailsState extends State<DoctorCaseDetails> {
  late List<String> symptoms;
  final List<String> diagnoses = []; // multi-select; master "Term · ICD" or typed free text
  final List<String> tests = [];
  final List<RxItem> rx = [];
  final _obs = TextEditingController();
  final _remarks = TextEditingController();
  final _pastHistory = TextEditingController();
  // Per-vital editable controllers (rule 2026-07-29). Seeded from the
  // patient's counsellor-captured values in initState. Fields sit inside a
  // collapsible section mirroring the Counsellor Register form — the
  // switch in the header shows / hides them. Values commit to p.vitals
  // when the page-level Submit Case button fires.
  late final Map<String, TextEditingController> _vitals;
  bool _showVitals = false;
  bool _advisoryDismissed = false;
  // True while GET /api/appointments/{id} is in flight — see
  // _loadRegistrationDetail. Without it the Registration Details card shows
  // a bare '—' during the round-trip, which reads as "none recorded".
  bool _loadingRegDetail = false;
  // Page-level focus sink. Picker buttons (Add Diagnosis / Add Test / Add
  // Medicine) move focus to this BEFORE opening the bottom-sheet AND right
  // after it closes, so Flutter's focus restoration can't land back on the
  // Symptoms TextField and trigger Scrollable.ensureVisible — which was the
  // root cause of the page jumping to Symptoms after picking.
  final FocusNode _focusSink = FocusNode(skipTraversal: true, debugLabel: 'doctor-case-focus-sink');

  CPatient get p => widget.patient;

  @override
  void initState() {
    super.initState();
    symptoms = List.from(p.symptoms);
    _pastHistory.text = p.pastHistory;
    _vitals = {
      for (final v in _kVitalSpecs)
        v.key: TextEditingController(text: p.vitals[v.key] ?? ''),
    };
    // Prefill diagnosis + previously-prescribed medicines (rule 2026-07-31).
    // Doctor can tweak either before submitting — sending re-appointment
    // patients through with fewer clicks.
    if (p.disease.isNotEmpty) {
      for (final d in p.disease.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        if (!diagnoses.contains(d)) diagnoses.add(d);
      }
    }
    if (p.prescription.isNotEmpty) {
      // Copy each RxItem so edits don't mutate the source until Submit.
      for (final m in p.prescription) {
        rx.add(RxItem(
          name: m.name, dosage: m.dosage,
          days: m.days, interval: m.interval, qty: m.qty,
        ));
      }
    }
    DiseaseMaster.load().then((_) { if (mounted) setState(() {}); });
    _loadRegistrationDetail();
  }

  /// Pull what the counsellor recorded at registration for a backend patient.
  ///
  /// /api/queues/doctor returns one flat appointment row — no symptoms, no
  /// vitals — so a CPatient built by mergeBackendPatients always arrives with
  /// an empty `symptoms` list and an empty `vitals` map however much the
  /// counsellor entered. GET /api/appointments/{id} is the only endpoint that
  /// joins `appointment_symptom` and returns the vitals columns. Demo-seed
  /// rows already carry their own values and are skipped.
  Future<void> _loadRegistrationDetail() async {
    final apptId = p.backendAppointmentId;
    if (apptId == null) return;
    // Assigned directly, not via setState — initState runs before first build.
    _loadingRegDetail = true;
    try {
      final d = await context.read<AppointmentsApi>().detail(apptId);
      if (!mounted) return;
      final freshSymptoms = <String>[
        for (final s in (d['symptoms'] as List? ?? const []))
          if (s is Map)
            (s['symptom_name'] ?? s['name'] ?? '').toString().trim()
      ]..removeWhere((s) => s.isEmpty);
      // Keyed by the labels _kVitalSpecs uses, so the values land in the
      // matching editable field. Blank/zero readings are left out — an empty
      // box for the doctor to fill beats a bogus 0.
      final freshVitals = <String, String>{};
      for (final spec in _kVitalSpecs) {
        final raw = d[_kVitalColumns[spec.key]];
        final val = _fmtVital(raw);
        if (val.isNotEmpty) freshVitals[spec.key] = val;
      }
      setState(() {
        if (freshSymptoms.isNotEmpty) {
          p.symptoms = freshSymptoms;
          // `symptoms` was seeded from the (empty) p.symptoms above and drives
          // both the editable chips and the AI advisory scoring, so it has to
          // be refreshed too — not just the read-only card.
          symptoms = List.from(freshSymptoms);
        }
        final cRemarks = (d['counsellor_remarks'] ?? '').toString().trim();
        if (cRemarks.isNotEmpty) p.remarks = cRemarks;
        if (freshVitals.isNotEmpty) {
          p.vitals = {...p.vitals, ...freshVitals};
          // Fill only fields the doctor hasn't already typed into, so a slow
          // response can never overwrite a reading being entered right now.
          for (final e in freshVitals.entries) {
            final c = _vitals[e.key];
            if (c != null && c.text.trim().isEmpty) c.text = e.value;
          }
          // Counsellor readings exist — open the section so they're visible
          // and editable instead of hidden behind the collapsed toggle.
          _showVitals = true;
        }
      });
    } catch (_) {
      // Non-blocking by design: offline is the normal case in an MMU. The
      // card falls back to '—' and empty vitals the doctor can fill in.
    } finally {
      if (mounted) setState(() => _loadingRegDetail = false);
    }
  }

  @override
  void dispose() {
    for (final c in _vitals.values) { c.dispose(); }
    _focusSink.dispose();
    super.dispose();
  }

  /// Commit the current controller values into p.vitals. Called from the
  /// page-level Submit Case handler so the updated readings ship along with
  /// the diagnosis / Rx / observations. Blanks are dropped so a cleared
  /// field removes that vital rather than storing '' for it.
  void _commitVitalsToPatient() {
    p.vitals.clear();
    for (final v in _kVitalSpecs) {
      final t = _vitals[v.key]!.text.trim();
      if (t.isNotEmpty) p.vitals[v.key] = t;
    }
  }

  void _parkFocus() {
    if (_focusSink.canRequestFocus) _focusSink.requestFocus();
  }

  /// Doctor's remarks with any advised tests appended.
  ///
  /// Tests are advice here, not lab orders (see the submit payload), and
  /// DoctorSubmitIn has no free-text field for them — so without this they
  /// would be recorded nowhere and the patient would leave with no written
  /// note of what to get done. Remarks is the right home: the field is
  /// labelled "Advice / follow-up" on this screen.
  String _remarksWithTests() {
    final base = _remarks.text.trim();
    if (tests.isEmpty) return base;
    final line = 'Tests advised: ${tests.join(', ')}';
    return base.isEmpty ? line : '$base\n$line';
  }

  /// '5 Days' -> 5. The server requires a positive int and defaults to 5,
  /// so an unparseable label falls back to the same value rather than
  /// failing the whole push.
  static int _daysToInt(String days) {
    final n = int.tryParse(RegExp(r'\d+').firstMatch(days)?.group(0) ?? '');
    return (n == null || n <= 0) ? 5 : n;
  }

  static const _perDay = {'OD': 1, 'BD': 2, 'TDS': 3, 'QID': 4, 'SOS': 1, 'HS': 1};
  void _recalcQty(RxItem m) {
    final perDay = _perDay[m.interval] ?? 1;
    final days = int.tryParse(RegExp(r'\d+').firstMatch(m.days)?.group(0) ?? '') ?? 0;
    m.qty = perDay * days;
  }

  void _applyAdvisory(String name, DPlan plan) {
    final resolved = DiseaseMaster.resolve(name);
    final dxStr = resolved?.display ?? name;
    setState(() {
      if (!diagnoses.contains(dxStr)) diagnoses.add(dxStr);
      tests..clear()..addAll(plan.tests);
      // Apply puts the medicine name in the name field and its strength in Dosage.
      rx..clear()..addAll(plan.rx.map((r) {
        final (mn, md) = splitMedicine(r.name);
        return RxItem(name: mn, dosage: md, days: r.days, interval: r.interval, qty: r.qty);
      }));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Applied $name protocol'), backgroundColor: C2.green));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<CounsellorState>();
    // Watch connectivity — the AI advisory panel is only shown when the doctor
    // is online (user rule: no AI/ML surfaces when offline).
    final online = context.watch<ConnectivityService>().isOnline;
    final scored = scoreDoctor(symptoms, p.block);
    final top = scored.isNotEmpty ? scored.first : null;
    final plan = top == null ? null : kDoctorDb[top.name];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)), title: Text('Case Details', style: ct(16, FontWeight.w700, C2.navy))),
        body: Focus(
          focusNode: _focusSink,
          // Attached but invisible — never participates in tab traversal and
          // doesn't trigger Scrollable.ensureVisible like a TextField would.
          child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // patient header
          CCard(child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
              Text('${p.gender}, ${p.age}y · ${p.contact}', style: ct(12, FontWeight.w400, C2.text2)),
              Text('${p.village.isEmpty ? "—" : p.village}${p.uniqueCode.isNotEmpty ? " · ${p.uniqueCode}" : ""}', style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
          ])),
          // registration details (read-only, filled by counsellor)
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: SecBar('Registration Details')), CBadge('By Counsellor', bg: C2.cyanLight, fg: C2.cyan)]),
            _kv('Symptoms', p.symptoms.isNotEmpty
                ? p.symptoms.join(', ')
                : (_loadingRegDetail ? 'Loading…' : '—')),
            if (p.remarks.isNotEmpty) _kv('Remarks', p.remarks),
          ])),
          // Editable Vitals card (rule 2026-07-31). Collapsible — same
          // switch pattern as the Counsellor Register form's Vitals section.
          // Values commit to p.vitals via the page-level Submit Case handler.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SecBar('Vitals', trailing: _vitalsToggle()),
            if (_showVitals) ...[
              const SizedBox(height: 4),
              Text('Edit any reading — updated values save when you tap Submit Case.',
                  style: ct(11, FontWeight.w400, C2.text2)),
              const SizedBox(height: 8),
              for (var i = 0; i < _kVitalSpecs.length; i += 2) Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: _vitalField(_kVitalSpecs[i])),
                  const SizedBox(width: 8),
                  Expanded(child: i + 1 < _kVitalSpecs.length
                      ? _vitalField(_kVitalSpecs[i + 1])
                      : const SizedBox()),
                ]),
              ),
            ] else
              Text('Turn on to view or update BP, sugar, temperature and more.',
                  style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
          // observation box (voice transcript) — between Registration & Symptoms
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Observation'),
            VoiceTranscriptBox(controller: _obs, hint: 'Tap to record, or type observations'),
          ])),
          // past medical history
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Past Medical History'),
            Text('Chronic illness, past surgeries, ongoing treatment.', style: ct(11, FontWeight.w400, C2.text2)),
            const SizedBox(height: 6),
            TextField(controller: _pastHistory, minLines: 2, maxLines: 5, decoration: cInput('e.g. Hypertension, diabetes, prior surgery, current meds')),
          ])),
          // Prescription and Reports — two chip-buttons (Px + Rx) that open
          // a tabular history dialog (rule 2026-08-05). Doctor sees a
          // structured view of past consultations and past prescriptions
          // instead of two long stacked lists inline.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Prescription and Reports'),
            Text('Tap Px for past consultations, Rx for past prescriptions.',
              style: ct(11.5, FontWeight.w400, C2.text2)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _historyChip(
                label: 'Px', subtitle: 'Past Consultations',
                icon: Icons.history_edu_outlined,
                count: _pxCount(),
                onTap: () => _openPxHistory(),
              )),
              const SizedBox(width: 8),
              Expanded(child: _historyChip(
                label: 'Rx', subtitle: 'Past Prescriptions',
                icon: Icons.medication_outlined,
                count: p.previousRx.length,
                onTap: () => _openRxHistory(),
              )),
            ]),
            if (_pxCount() == 0 && p.previousRx.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8),
                child: Text('No prescriptions or reports on record.',
                    style: ct(12, FontWeight.w400, C2.text2))),
          ])),
          // symptoms & diagnosis
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Symptoms & Diagnosis'),
            CField('Symptoms', SymptomField(selected: symptoms, block: p.block, onChanged: (v) => setState(() { symptoms..clear()..addAll(v); _advisoryDismissed = false; }))),
            if (online && plan != null && !_advisoryDismissed) _advisory(top!.name, top.pct, plan),
            CField('Diagnosis (ICD-11)', _diagnosisField()),
            CField('Tests to Order', _testsField()),
          ])),
          // prescription
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Prescription'),
            if (rx.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('No medicines added', style: ct(12, FontWeight.w400, C2.text2))),
            ...rx.map(_medCard),
            const SizedBox(height: 4),
            COutlineButton('Add Medicine', icon: Icons.add_circle_outline, onTap: _addMed),
          ])),
          // doctor remarks (with speech-to-text)
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Doctor Remarks'),
            TextField(controller: _remarks, minLines: 2, maxLines: 4, decoration: cInput('Advice / follow-up').copyWith(
              suffixIcon: VoiceMicButton(controller: _remarks))),
          ])),
          const SizedBox(height: 4),
          CPrimaryButton('Submit Case', icon: Icons.check_circle_outline, onTap: () {
            if (diagnoses.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one diagnosis'), backgroundColor: C2.danger)); return; }
            p.pastHistory = _pastHistory.text.trim();
            // Commit any edited vitals so the update rides along with the
            // rest of the case submission.
            _commitVitalsToPatient();
            s.doctorSubmit(p, disease: diagnoses.join(', '), rx: rx, tests: tests, observations: _obs.text.trim(), remarks: _remarks.text.trim());
            // Enqueue appointment.doctor_submit (v2 §4). Server decides
            // the next status based on tests vs medicines.
            context.read<SyncService>().enqueue(kind: 'appointment.doctor_submit', payload: {
              // The server resolves the case by appointment_id and rejects the
              // push outright without it ("appointment_id is required", 422 —
              // mobile.py `_doctor_submit`). p.id is the local row key ('B71'),
              // never an appointment id, so sending only client_appointment_ref
              // meant every consultation was rejected: the phone showed the
              // case as done while the server kept it at 'with_doctor', and the
              // next queue refresh pulled that stale status back as In Progress.
              if (p.backendAppointmentId != null)
                'appointment_id': p.backendAppointmentId,
              'client_appointment_ref': p.id,
              'observation':            _obs.text.trim(),
              'doctor_remarks':         _remarksWithTests(),
              'past_history':           _pastHistory.text.trim(),
              // DoctorSubmitIn reads `diagnosis_text`; a bare `text` key was
              // dropped on the floor, losing the diagnosis on every case.
              'diagnoses': [
                for (var i = 0; i < diagnoses.length; i++)
                  {'diagnosis_text': diagnoses[i], 'is_primary': i == 0},
              ],
              // lab_test_ids is deliberately NOT sent. This MMU runs
              // Counsellor -> Doctor -> Pharmacist with no lab desk and no test
              // payment, but the server routes any formally-ordered test to
              // 'with_counsellor' to collect a fee — a state nothing in this app
              // can clear, which stranded the patient short of the pharmacist.
              // The doctor only *advises* tests here, so they ride along as text
              // (see _remarksWithTests) and the case routes on medicines alone.
              'lab_test_names': [ for (final t in tests) t ],
              'prescription': [
                for (final m in rx)
                  {
                    'medicine_name': m.name,
                    'dosage':        m.dosage,
                    'frequency':     m.interval,
                    // Schema wants a day count, not a label like '5 Days'.
                    'duration_days': _daysToInt(m.days),
                    'qty':           m.qty,
                  },
              ],
              'vitals': {
                for (final e in p.vitals.entries) e.key: e.value,
              },
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rx.isEmpty ? 'Case completed' : 'Case submitted → Pharmacist'), backgroundColor: C2.green));
            Navigator.pop(context);
          }),
          const SizedBox(height: 8),
        ])))),
      ),
    );
  }

  Widget _advisory(String name, int pct, DPlan plan) {
    Widget line(IconData ic, String label, String val) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 14, color: C2.cyanLight), const SizedBox(width: 8),
            Expanded(child: RichText(text: TextSpan(children: [
              TextSpan(text: '$label  ', style: ct(12, FontWeight.w700, C2.cyanLight)),
              TextSpan(text: val, style: ct(12.5, FontWeight.w400, Colors.white)),
            ]))),
          ]),
        );
    final rxStr = plan.rx.map((r) => '${r.name} (${r.interval} × ${r.days})').join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C2.navy, Color(0xFF005A8D)]), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.memory, size: 15, color: Colors.white), const SizedBox(width: 6),
          Text('AI Clinical Advisory', style: ct(12.5, FontWeight.w700, Colors.white)), const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: C2.cyan, borderRadius: BorderRadius.circular(4)), child: Text('LOCAL', style: ct(8.5, FontWeight.w700, Colors.white))),
        ]),
        const SizedBox(height: 10),
        line(Icons.coronavirus_outlined, 'Likely:', '$name ($pct%)'),
        line(Icons.science_outlined, 'Tests:', plan.tests.join(', ')),
        line(Icons.healing_outlined, 'Treatment:', plan.firstLine),
        line(Icons.medication_outlined, 'Rx:', rxStr),
        line(Icons.warning_amber_rounded, 'Red Flags:', plan.redFlags.join(', ')),
        Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text('From local clinical database — doctor must review.', style: ct(10.5, FontWeight.w400, Colors.white70))),
        Row(children: [
          _aiBtn('Apply', C2.green, () => _applyAdvisory(name, plan)),
          const SizedBox(width: 6),
          _aiBtn('Dismiss', Colors.white.withValues(alpha: 0.15), () => setState(() => _advisoryDismissed = true)),
        ]),
      ]),
    );
  }

  Widget _aiBtn(String t, Color bg, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: ct(12, FontWeight.w600, Colors.white)),
      ));

  Widget _diagnosisField() {
    final loaded = DiseaseMaster.isLoaded;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (diagnoses.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Wrap(spacing: 6, runSpacing: 6, children: diagnoses.map((d) => Chip(
          label: Text(d, style: ct(11.5, FontWeight.w600, C2.navy)), backgroundColor: C2.cyanLight, side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact,
          deleteIcon: const Icon(Icons.close, size: 13), deleteIconColor: C2.text2, onDeleted: () => setState(() => diagnoses.remove(d)),
        )).toList())),
      COutlineButton(loaded ? 'Add Diagnosis' : 'Loading disease list…', icon: Icons.add, onTap: !loaded ? null : () async {
        // Park focus on the page-level sink so the modal route's focus
        // restoration can't bring focus back to the Symptoms TextField
        // (which would call Scrollable.ensureVisible and jump the page).
        _parkFocus();
        final picked = await showModalBottomSheet<String>(
          context: context, isScrollControlled: true, backgroundColor: C2.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => const _DiseasePickerSheet());
        if (!mounted) return;
        _parkFocus();
        if (picked != null && picked.trim().isNotEmpty && !diagnoses.contains(picked)) setState(() => diagnoses.add(picked));
      }),
    ]);
  }

  Widget _testsField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (tests.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Wrap(spacing: 6, runSpacing: 6, children: tests.map((t) => Chip(
          label: Text(t, style: ct(11.5, FontWeight.w600, C2.navy)), backgroundColor: C2.cyanLight, side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact,
          deleteIcon: const Icon(Icons.close, size: 13), deleteIconColor: C2.text2, onDeleted: () => setState(() => tests.remove(t)),
        )).toList())),
      COutlineButton('Add Test', icon: Icons.add, onTap: () async {
        _parkFocus();
        final picked = await _pick(context, 'Add Test', kLabTests.where((t) => !tests.contains(t)).toList());
        if (!mounted) return;
        _parkFocus();
        if (picked != null) setState(() => tests.add(picked));
      }),
    ]);
  }

  Widget _medCard(RxItem m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C2.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(m.name, style: ct(13, FontWeight.w600, C2.text))),
          InkWell(onTap: () => setState(() => rx.remove(m)), child: const Icon(Icons.close, size: 18, color: C2.text2)),
        ]),
        const SizedBox(height: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DOSAGE', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
          SizedBox(height: 38, child: TextFormField(initialValue: m.dosage, style: ct(12.5, FontWeight.w500, C2.text),
            decoration: cInput('e.g. 500 mg'), onChanged: (v) => m.dosage = v)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _mini('Frequency', m.interval, kFrequencies, (v) => setState(() { m.interval = v; _recalcQty(m); }))),
          const SizedBox(width: 6),
          // Open-ended duration: 1-2 digit days OR a 3-letter code (SOS, PRN).
          // Dropdown can't cover all values the AI advisory suggests.
          Expanded(child: _miniDuration(m)),
          const SizedBox(width: 6),
          SizedBox(width: 64, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('QTY (auto)', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
            Container(height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
              child: Text('${m.qty}', style: ct(14, FontWeight.w700, C2.navy))),
          ])),
        ]),
      ]),
    );
  }

  Widget _mini(String label, String val, List<String> opts, ValueChanged<String> onCh) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: ct(10, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
        SizedBox(height: 38, child: SearchDropdown(
          items: opts, value: opts.contains(val) ? val : null,
          onChanged: (v) => onCh(v ?? val))),
      ]);

  /// Open-ended Duration input. Accepts 1-2 digit days (1-99) OR a 3-letter
  /// code like SOS / PRN. Input formatters cap length at 3 and strip
  /// invalid characters as the doctor types.
  Widget _miniDuration(RxItem m) {
    final isInvalid = m.days.isNotEmpty &&
        !RegExp(r'^(\d{1,2}|[A-Za-z]{3})$').hasMatch(m.days);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DURATION', style: ct(10, FontWeight.w600, C2.text2)),
      const SizedBox(height: 3),
      SizedBox(
        height: 38,
        child: TextFormField(
          initialValue: m.days,
          style: ct(12.5, FontWeight.w500, C2.text),
          decoration: cInput('5 or SOS').copyWith(
            errorText: isInvalid ? 'Bad value' : null,
            errorStyle: const TextStyle(fontSize: 0, height: 0),
          ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(3),
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
          ],
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => setState(() {
            m.days = v.toUpperCase();
            _recalcQty(m);
          }),
        ),
      ),
    ]);
  }

  Future<void> _addMed() async {
    _parkFocus();
    final picked = await _pick(context, 'Add Medicine', kMedicineNames.where((m) => !rx.any((x) => x.name == m)).toList());
    if (!mounted) return;
    _parkFocus();
    if (picked != null) setState(() => rx.add(RxItem(name: picked)));
  }

  Future<String?> _pick(BuildContext context, String title, List<String> options) {
    return showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: C2.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PickerSheet(title: title, options: options));
  }

  void _viewUploadedRx(String path) {
    final file = File(path);
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: C2.white,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Uploaded Prescription', style: ct(14.5, FontWeight.w700, C2.navy)),
        const SizedBox(height: 4),
        Text(path.split('/').last, style: ct(11, FontWeight.w400, C2.text2)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: file.existsSync()
            ? InteractiveViewer(child: Image.file(file, fit: BoxFit.contain))
            : Container(padding: const EdgeInsets.all(24), alignment: Alignment.center,
                decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.image_not_supported_outlined, size: 36, color: C2.text3),
                  const SizedBox(height: 8),
                  Text('Image preview not available on this device.', textAlign: TextAlign.center, style: ct(12, FontWeight.w400, C2.text2)),
                ])),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: ct(13, FontWeight.w700, C2.cyan)))),
      ])),
    ));
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w500, C2.text))),
      ]));

  // ═════════════ Px + Rx history (rule 2026-08-05) ═════════════
  // Prescription & Reports section renders two chip buttons; tapping each
  // opens a modal dialog with a table of historical rows.

  /// Total count for the Px chip badge: past-history + last-diagnosis +
  /// attached reports/prescriptions. Zero when the patient has no history
  /// at all, so the empty-state helper text can render.
  int _pxCount() {
    var c = 0;
    if (p.pastHistory.trim().isNotEmpty) c++;
    if (p.disease.trim().isNotEmpty) c++;
    c += p.attachments.length;
    return c;
  }

  Widget _historyChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C2.navy, C2.cyan]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(label, style: ct(15, FontWeight.w800, Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(4)),
                child: Text('$count', style: ct(10.5, FontWeight.w700, Colors.white)),
              ),
            ]),
            Text(subtitle, style: ct(10.5, FontWeight.w500, Colors.white70)),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: Colors.white),
        ]),
      ),
    );
  }

  void _openPxHistory() {
    // Rows for Px = past consultations table. Sourced from:
    //  - Past Medical History text (one row, no date)
    //  - The most recent diagnosis on file (p.disease), tagged with regDate
    //  - Each counsellor-uploaded attachment (Report / Other) with its
    //    kind + description. Attachment rows are tappable → the previously
    //    captured image opens in an interactive viewer.
    // Ordering: history first (context), diagnosis, then attachments.
    final rows = <_HistoryRow>[];
    if (p.pastHistory.trim().isNotEmpty) {
      rows.add(_HistoryRow(cells: ['—', 'Past History', p.pastHistory.trim()]));
    }
    if (p.disease.trim().isNotEmpty) {
      rows.add(_HistoryRow(cells: [
        p.regDate.isEmpty ? '—' : p.regDate,
        'Previous Diagnosis',
        p.disease.trim(),
      ]));
    }
    for (final a in p.attachments) {
      rows.add(_HistoryRow(
        cells: [
          p.regDate.isEmpty ? '—' : p.regDate,
          a.kind.label,
          a.description.isEmpty ? a.path.split(RegExp(r'[\\/]+')).last : a.description,
        ],
        onTap: () => _viewUploadedRx(a.path),
      ));
    }
    _openHistoryDialog(
      title: 'Px — Past Consultations',
      icon: Icons.history_edu_outlined,
      headers: const ['Date', 'Type', 'Details'],
      rows: rows,
      empty: 'No past consultation records on file.',
    );
  }

  void _openRxHistory() {
    // Rows for Rx = past prescriptions table. One row per PrevRx entry.
    final rows = p.previousRx.map((r) => _HistoryRow(cells: [
      r.date,
      r.medicine,
      r.dosage.isEmpty ? '—' : r.dosage,
      r.frequency.isEmpty ? '—' : r.frequency,
      r.duration.isEmpty ? '—' : r.duration,
    ])).toList();
    _openHistoryDialog(
      title: 'Rx — Past Prescriptions',
      icon: Icons.medication_outlined,
      headers: const ['Date', 'Medicine', 'Dosage', 'Frequency', 'Duration'],
      rows: rows,
      empty: 'No prescriptions on file yet.',
    );
  }

  /// Shared Px/Rx dialog. Header + scrollable structured table + Close.
  void _openHistoryDialog({
    required String title,
    required IconData icon,
    required List<String> headers,
    required List<_HistoryRow> rows,
    required String empty,
  }) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: C2.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: C2.navy),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: ct(15, FontWeight.w700, C2.navy))),
              InkWell(onTap: () => Navigator.pop(context),
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: C2.text2))),
            ]),
            const SizedBox(height: 6),
            Container(height: 1, color: C2.border),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(empty, style: ct(12.5, FontWeight.w400, C2.text2))))
            else
              Flexible(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(C2.cyanLight),
                    headingTextStyle: ct(11.5, FontWeight.w800, C2.navy),
                    dataTextStyle: ct(12, FontWeight.w500, C2.text),
                    columnSpacing: 16,
                    horizontalMargin: 8,
                    columns: [for (final h in headers) DataColumn(label: Text(h))],
                    rows: [for (final r in rows) DataRow(
                      onSelectChanged: r.onTap == null ? null : (_) { Navigator.pop(context); r.onTap!(); },
                      cells: [for (final c in r.cells) DataCell(Text(c, style: ct(12, FontWeight.w500, C2.text)))],
                    )],
                  ),
                ),
              )),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Close', style: ct(13, FontWeight.w700, C2.cyan)))),
          ]),
        ),
      ),
    ));
  }

  // Mirrors the counsellor Register form's _toggle helper so the two
  // Vitals sections look identical.
  Widget _vitalsToggle() => Transform.scale(
        scale: 0.8,
        child: Switch(
          value: _showVitals,
          activeColor: Colors.white,
          activeTrackColor: C2.cyan,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => setState(() => _showVitals = v),
        ),
      );

  Widget _vitalField(({String key, String label, String hint}) v) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v.label.toUpperCase(), style: ct(9.5, FontWeight.w700, C2.text2)),
      const SizedBox(height: 3),
      SizedBox(height: 36, child: TextField(
        controller: _vitals[v.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          LengthLimitingTextInputFormatter(6),
        ],
        style: ct(12.5, FontWeight.w600, C2.text),
        decoration: cInput(v.hint).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      )),
    ]);
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  const _PickerSheet({required this.title, required this.options});
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final query = q.trim();
    final m = widget.options.where((o) => query.isEmpty || o.toLowerCase().contains(query.toLowerCase())).toList();
    final exact = m.any((o) => o.toLowerCase() == query.toLowerCase());
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: ct(15, FontWeight.w700, C2.navy)),
        const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Search or type to add…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 8),
        // Free-text: add an item that isn't in the master list.
        if (query.isNotEmpty && !exact)
          ListTile(dense: true, contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline, size: 18, color: C2.green),
            title: Text('Add "$query"', style: ct(13.5, FontWeight.w600, C2.green)),
            onTap: () => Navigator.pop(context, query)),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: m.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(query.isEmpty ? 'Type to search' : 'No master match — use "Add" above', style: ct(13, FontWeight.w400, C2.text2)))
          : ListView(shrinkWrap: true, children: m.map((o) => ListTile(dense: true, title: Text(o, style: ct(13.5, FontWeight.w500, C2.text)),
              trailing: const Icon(Icons.add, size: 18, color: C2.cyan), onTap: () => Navigator.pop(context, o))).toList())),
      ]),
    );
  }
}

/// ICD-11 diagnosis search picker — flat list of Standard Term + ICD-11 code
/// (no category / sub-category). Matches name, code AND synonyms.
class _DiseasePickerSheet extends StatefulWidget {
  const _DiseasePickerSheet();
  @override
  State<_DiseasePickerSheet> createState() => _DiseasePickerSheetState();
}

class _DiseasePickerSheetState extends State<_DiseasePickerSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final matches = DiseaseMaster.search(q);
    final query = q.trim();
    final exact = matches.any((d) => d.term.toLowerCase() == query.toLowerCase());
    final rows = matches.map((d) => InkWell(
          onTap: () => Navigator.pop(context, d.display),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Row(children: [
              Expanded(child: Text(d.term, style: ct(13.5, FontWeight.w600, C2.text))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C2.navyLight, borderRadius: BorderRadius.circular(5)),
                child: Text(d.icd.isEmpty ? '—' : d.icd, style: ct(10.5, FontWeight.w700, C2.navy))),
            ]),
          ),
        )).toList();
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Select Diagnosis', style: ct(15, FontWeight.w700, C2.navy)),
          const Spacer(),
          Text('${matches.length} of ${DiseaseMaster.all.length}', style: ct(11, FontWeight.w500, C2.text2)),
        ]),
        const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Search or type a diagnosis…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 4),
        // Free-text: add a diagnosis not in the ICD-11 master.
        if (query.isNotEmpty && !exact)
          InkWell(
            onTap: () => Navigator.pop(context, query),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(children: [
                const Icon(Icons.add_circle_outline, size: 16, color: C2.green), const SizedBox(width: 8),
                Expanded(child: Text('Add "$query"', style: ct(13, FontWeight.w600, C2.green))),
              ]))),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 360),
          child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.all(16), child: Text(query.isEmpty ? 'Type to search' : 'No master match — use "Add" above', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(shrinkWrap: true, children: rows)),
      ]),
    );
  }
}

/// Row model for the Px + Rx tabular history dialogs (rule 2026-08-05).
/// `cells` maps 1:1 with the dialog's column headers. `onTap` is optional
/// — when non-null the row is selectable (currently used for attachment
/// rows in the Px table, which open the uploaded image).
class _HistoryRow {
  final List<String> cells;
  final VoidCallback? onTap;
  _HistoryRow({required this.cells, this.onTap});
}
