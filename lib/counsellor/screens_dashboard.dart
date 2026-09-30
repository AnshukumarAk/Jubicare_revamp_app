import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_errors.dart';
import '../api/appointments_api.dart';
import '../config/app_config.dart';
import '../api/masters_store.dart';
import '../api/patients_api.dart';
import '../api/sync_service.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';
// displayDosage: renders a stored dosage with the unit its form
// implies, so this screen shows "Tab · 500 mg" for a doctor who only
// typed 500 (user 2026-09-22).
import '../doctor/ddata.dart' show displayDosage;

class CounDashboard extends StatelessWidget {
  final VoidCallback onRegister;
  final String name;
  /// The counsellor shell passes its `_refreshFromBackend` here so the
  /// dashboard's retry banner (and, later, pull-to-refresh) can trigger a
  /// fresh pull without duplicating the API logic.
  final Future<void> Function()? onRefresh;
  const CounDashboard({super.key, required this.onRegister, this.name = 'Divya', this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final initials = name.isEmpty ? 'C' : name[0].toUpperCase();
    // Tile counts prefer the server number (from /queues/summary/tiles) so
    // the dashboard reflects the whole facility, not just what happened
    // to be pulled into the local list. Falls back to the local count while
    // the first refresh is still in flight or the backend is unreachable.
    final today = s.backendRegisteredToday ?? s.registeredToday;
    final done = s.backendVisitsCompleted ?? s.visitsCompleted;
    final past7 = s.backendPast7DaysTotal ?? s.counsellorPast7Days.length;
    // "Registered Patients (Today)" section — filter the shared patient
    // list to just today's rows so the counsellor sees the day's work
    // (older visits are one tap away via the stat tiles).
    final todaysList = s.patients.where((p) => p.registeredOn == 'Today').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradGreeting(name: name, sub: 'Receptionist Dashboard', initials: initials),
      // Sync status moved to the app-bar cloud icon (user 2026-08-14) —
      // tap it for the counts + a "Sync now" action.
      // Backend refresh status: thin loading bar while the shell's
      // _refreshFromBackend is in flight, and a red retry banner if the
      // last pull failed. Doctor/pharmacist shells show the same UI.
      if (s.refreshing)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
        ),
      // Cached-list banner removed 2026-08-20 per user rule "dont show
      // offline message no need". Data is already on screen from the
      // local cache; the AppBar refresh button covers the retry gesture.
      IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: StatTile(
            '$today', 'Registered Today', C2.navy,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientsList(
              title: 'Registered Today',
              patients: todaysList))))),
          const SizedBox(width: 8),
          Expanded(child: StatTile(
            '$done', 'Visits Completed', C2.cyan,
            // The shell's _refreshFromBackend pulls /queues/doctor/attended
            // alongside tiles + past-7-days on mount, pull-to-refresh, and
            // app-bar refresh, so `s.patients` already carries the COMPLETED
            // rows and the tap opens instantly with no per-tap fetch
            // (user 2026-08-29 "only one time download and when refresh").
            onTap: () {
              final list = s.patients
                  .where((p) => p.status == 'completed').toList()
                ..sort((a, b) => b.regDate.compareTo(a.regDate));
              Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientsList(
                  title: 'Visits Completed', patients: list)));
            })),
          const SizedBox(width: 8),
          // Past 7 Days tile (rule 2026-07-31 — parity with doctor screen).
          // Tap opens the shared CounPatientsList filtered to newest-first
          // patients registered in the last week.
          Expanded(child: StatTile(
            '$past7', 'Past 7 Days', C2.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientsList(
              title: 'Past 7 Days', patients: s.counsellorPast7Days))))),
        ],
      )),
      const SizedBox(height: 14),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Registered Patients (Today)'),
        if (todaysList.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(
            child: Text('No patients registered today', style: ct(12, FontWeight.w400, C2.text2)))),
        ...todaysList.take(5).map((p) => _PatientRow(p)),
        if (todaysList.length > 5)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing 5 of ${todaysList.length} registered today', style: ct(11, FontWeight.w500, C2.text2))),
      ])),
      const SizedBox(height: 8),
      CPrimaryButton('Register New Patient', icon: Icons.person_add_alt_1, onTap: onRegister),
    ]);
  }
}

class _PatientRow extends StatelessWidget {
  final CPatient p;
  const _PatientRow(this.p);
  @override
  Widget build(BuildContext context) {
    // Full status ladder (user bug report 2026-08-13: rows sitting at the
    // pharmacy / lab / payment desk all showed a misleading "Waiting").
    final (label, bg, fg) = apptStatus(p.status);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientDetail(p: p))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
            const SizedBox(height: 1),
            Text('${p.age}y · ${p.symptoms.take(2).join(', ')}', style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
          CBadge(label, bg: bg, fg: fg),
        ]),
      ),
    );
  }
}

class CounPatientDetail extends StatefulWidget {
  final CPatient p;
  /// Show the Re-Appointment CTA (rule 2026-07-31). Only the counsellor
  /// Status list opts in — Home / doctor / pharmacist opens keep it off so
  /// the button doesn't show up where it isn't actionable.
  final bool showReAppointment;
  const CounPatientDetail({super.key, required this.p, this.showReAppointment = false});
  @override
  State<CounPatientDetail> createState() => _CounPatientDetailState();
}

class _CounPatientDetailState extends State<CounPatientDetail> {
  bool _loading = false;
  String? _err;
  // Next Follow-Up the doctor picked at submit (user 2026-08-22
  // "show follow up details in details page"). ISO yyyy-mm-dd from the
  // appointment detail; '' = none recorded.
  String _followUp = '';

  CPatient get p => widget.p;

  @override
  void initState() {
    super.initState();
    // Backend rows (queue 'B…' + online-search 'S…') carry only summary
    // fields. Fetch the full appointment via /api/appointments/{id} so
    // this screen shows symptoms, diagnoses, vitals, remarks + photos —
    // none of which are in the list responses. Locally-added patients
    // ('P…') and demo seed (numeric) have everything in memory already
    // and carry no backendAppointmentId, so no network call fires.
    if (p.backendAppointmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    setState(() { _loading = true; _err = null; });
    try {
      final api = context.read<AppointmentsApi>();
      final d = await api.detail(p.backendAppointmentId!);
      if (!mounted) return;
      // Merge server-side clinical fields into the local CPatient in
      // place. `p` is the same object the shell's `patients` list
      // holds, so subsequent opens of this screen (or the Status tab)
      // see the enriched data too — no repeated fetch on re-open.
      //
      // Direct assignment (not .clear()..addAll(...)) is deliberate:
      // the CPatient collection fields may hold a const [] literal
      // when the queue merge fell through empty, and calling .clear()
      // on that throws UnmodifiableListMixin. Assignment side-steps
      // the mutation entirely and the old list becomes garbage.
      final syms = (d['symptoms'] as List?) ?? const [];
      p.symptoms = <String>[
        for (final s in syms)
          if (s is Map) (s['symptom_name'] ?? s['name'] ?? '').toString()
      ];
      final dx = (d['diagnoses'] as List?) ?? const [];
      if (dx.isNotEmpty && dx.first is Map) {
        p.disease = ((dx.first as Map)['diagnosis_text'] ?? '').toString();
      }
      // Vitals — key/value map keyed by human labels the existing
      // CCard(Vitals) block already renders.
      final vitals = <String, String>{};
      void v(String label, String key) {
        final val = d[key];
        if (val != null) vitals[label] = val.toString();
      }
      v('Systolic BP', 'systolic_bp');
      v('Diastolic BP', 'diastolic_bp');
      v('Blood Sugar', 'blood_sugar');
      v('Body Temp (°F)', 'body_temp');
      v('Oxygen', 'oxygen');
      v('Heart Rate', 'heart_rate');
      v('Hemoglobin', 'hemoglobin');
      v('Height (cm)', 'height');
      v('Weight (kg)', 'weight');
      p.vitals = vitals;
      // Also mirror height/weight into the CPatient string fields the
      // register form's Re-Appointment prefill reads (heightCm/weightKg)
      // so a follow-up visit starts with the last recorded measurements.
      if (d['height'] != null) p.heightCm = d['height'].toString();
      if (d['weight'] != null) p.weightKg = d['weight'].toString();
      // ENGLISH leads on every display (user 2026-08-22 "still remarks
      // showing hindi") — the original (as dictated) stays in the base
      // columns and is only the fallback for rows without a translation.
      String eng(String enKey, String baseKey) {
        final e = (d[enKey] ?? '').toString().trim();
        return e.isNotEmpty ? e : (d[baseKey] ?? '').toString();
      }
      p.remarks = eng('counsellor_remarks_english', 'counsellor_remarks');
      // Original as dictated — inputs (Re-Appointment prefill) use this.
      p.remarksOriginal = (d['counsellor_remarks'] ?? '').toString();
      p.doctorRemarks = eng('doctor_remarks_english', 'doctor_remarks');
      p.doctorRemarksOriginal = (d['doctor_remarks'] ?? '').toString();
      p.observations = eng('observation_english', 'observation');
      p.pregnant = (d['pregnant'] as bool?) ?? p.pregnant;
      // Pregnancy dates ride along so Re-Appointment can re-select the
      // LMP/EDD picker (user 2026-08-21 "date is not showing selected").
      p.lmpDate = (d['lmp_date'] as String?) ?? p.lmpDate;
      p.eddDate = (d['edd_date'] as String?) ?? p.eddDate;
      _followUp = (d['follow_up_date'] as String?) ?? '';
      // Assigned doctor (staff_name) — Re-Appointment prefill re-selects
      // them in the register form's dropdown.
      final docName = (d['assigned_doctor_name'] as String?)?.trim();
      if (docName != null && docName.isNotEmpty) p.assignedDoctor = docName;
      // Prescription / report photos. file_path from the server is either
      // a bare "<uuid>.jpg" (uploads/patient_docs/) or a legacy phone-local
      // path. Stash it in serverPath — the render side decides whether it
      // can build a network URL out of it.
      final atts = (d['attachments'] as List?) ?? const [];
      p.attachments = <Attachment>[
        for (final a in atts)
          if (a is Map)
            Attachment(
              path: '',
              serverPath: ((a['file_path'] ?? '') as Object).toString(),
              kind: AttachmentKindX.fromLabel((a['kind'] ?? 'Other').toString()),
              description: (a['description'] ?? '').toString(),
            ),
      ];
      // Prescription — pharmacist-visible rows the doctor entered.
      final rxRows = (d['prescription'] as List?) ?? const [];
      p.prescription = <RxItem>[
        for (final r in rxRows)
          if (r is Map)
            RxItem(
              // prescription_item_id rides along so the pharmacist's
              // dispense call can identify this line server-side.
              itemId: (r['prescription_item_id'] as num?)?.toInt(),
              name: (r['medicine_name'] ?? '').toString(),
              dosage: (r['dosage'] ?? '').toString(),
              interval: (r['frequency'] ?? 'TDS').toString(),
              days: '${r['duration_days'] ?? 5} Days',
              qty: (r['qty'] as num?)?.toInt() ?? 0,
              // 0 = not dispensed yet → let the constructor default it to
              // the prescribed qty (Delivered field opens pre-filled).
              dispensedQty: ((r['dispensed_qty'] as num?)?.toInt() ?? 0) > 0
                  ? (r['dispensed_qty'] as num).toInt()
                  : null,
              dispensed: (r['dispensed'] as bool?) ?? false,
              comboKey: (r['combo_key'] ?? '').toString(),
            ),
      ];
      // Also tell CounsellorState so the Home list rebuilds against
      // the enriched row (symptoms show under the name, etc).
      context.read<CounsellorState>().updateRequisitions();
      setState(() { _loading = false; });
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('[CounPatientDetail] hydrate ApiException: code=${e.code} '
            'status=${e.statusCode} message=${e.message}');
      if (!mounted) return;
      setState(() { _loading = false; _err = e.message; });
    } catch (e, st) {
      // ignore: avoid_print
      print('[CounPatientDetail] hydrate error: $e\n$st');
      if (!mounted) return;
      setState(() { _loading = false; _err = e.toString(); });
    }
  }

  /// Kick off a Re-Appointment. Backend rows ('B…' queue / 'S…' search)
  /// only carry the list summary — aadhar, address, PIN, blood group,
  /// category and past history never travel on those rows, so the
  /// register form's prefill came up half-empty (user bug report
  /// 2026-08-13). Pull the FULL patient record first, merge it in, then
  /// hand the enriched object to the register form.
  Future<void> _startReAppointment(BuildContext context) async {
    final isBackendRow = p.id.startsWith('B') || p.id.startsWith('S');
    final pid = int.tryParse(p.id.replaceFirst(RegExp(r'^[BS]'), ''));
    if (isBackendRow && pid != null) {
      try {
        final d = await context.read<PatientsApi>().get(pid);
        p.aadhar      = (d['aadhar_number'] ?? '').toString();
        p.bloodGroup  = d['blood_group'] as String?;
        p.category    = d['category_name'] as String?;
        p.pin         = (d['pin_code'] ?? '').toString();
        p.address     = (d['address'] ?? '').toString();
        p.pastHistory = (d['past_history'] ?? '').toString();
        p.pwd         = (d['disability'] == true) ? 'Yes' : 'No';
      } catch (_) {
        // Offline — prefill continues with whatever the row already has.
      }
    }
    if (!context.mounted) return;
    context.read<CounsellorState>().startReAppointmentFor(p);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('Patient Details', style: ct(16, FontWeight.w700, C2.navy)),
        ),
        body: Column(children: [
          // Backend fetch progress — thin bar while /appointments/{id}
          // is being pulled to enrich this screen (symptoms + vitals +
          // remarks that the queue list didn't carry).
          if (_loading) const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
          // Cached-view banner removed 2026-08-20 (same rule as Home
          // dashboard) — the patient detail always renders whatever
          // fields it has, offline or online.
          Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle),
                  child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
                  // unique_code stays internal (user rule 2026-08-14:
                  // "dont show anywhere unique id").
                  // Unique code back on the name card (user 2026-08-22).
                  Text(
                      '${p.gender}, ${p.age}y'
                      '${p.uniqueCode.isEmpty ? '' : ' · ${p.uniqueCode}'}',
                      style: ct(12, FontWeight.w400, C2.text2)),
                  if (p.dob.isNotEmpty) Text('DOB: ${p.dob}', style: ct(11.5, FontWeight.w400, C2.text2)),
                ])),
              ]),
            ])),
            CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecBar('Registration Details'),
              _kv('Contact', p.contact),
              if (p.dob.isNotEmpty) _kv('Date of Birth', p.dob),
              _kv('Age', '${p.age} y'),
              _kv('Block', p.block.isEmpty ? '—' : p.block),
              _kv('Village', p.village.isEmpty ? '—' : p.village),
              _kv('Symptoms', p.symptoms.isEmpty ? '—' : p.symptoms.join(', ')),
              if (p.pregnant) _kv('Pregnant', 'Yes'),
              // 'Likely' row removed from Patient Details (user 2026-08-22).
              _kv('Registered', p.registeredOn),
              if (_followUp.isNotEmpty)
                _kv('Next Follow-up', _followUp.split('-').reversed.join('-')),
              // Re-Appointment CTA (rule 2026-07-31). Sits at the end of the
              // Registration Details card so the counsellor sees it right
              // where they read the demographics.
              if (widget.showReAppointment) ...[
                const SizedBox(height: 12),
                CPrimaryButton(
                  'Re-Appointment',
                  icon: Icons.event_repeat_outlined,
                  onTap: () => _startReAppointment(context),
                ),
              ],
            ])),
            if (p.vitals.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Vitals'),
                // Display with units, same wording as the Register form
                // (user 2026-08-14). The map KEYS stay canonical — the
                // doctor's editable card and re-appointment prefill
                // match on them.
                // Two per row (user 2026-09-28). Nine vitals stacked one to a
                // line pushed the remarks and photos below the fold; paired
                // up they fit a screen. Label above value rather than beside
                // it, because "Systolic BP (mmHg)" has no room to sit beside
                // anything in half a phone's width.
                ..._vitalRows(p.vitals),
              ])),
            if (p.remarks.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Patient Remarks'),
                // English leads (user 2026-08-22), with the words the
                // patient actually said one tap away (user 2026-09-28).
                CTranslatedText(p.remarks,
                    original: p.remarksOriginal,
                    style: ct(13, FontWeight.w400, C2.text)),
              ])),
            // Prescription / report photos. Server-named rows render over
            // the network from uploads/patient_docs/; rows that only have
            // a phone-local path render from disk when this IS the phone
            // that captured them, else show a placeholder tile.
            if (p.attachments.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Prescription and Reports'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in p.attachments) _AttachmentThumb(a: a),
                ]),
              ])),
            // Doctor's prescribed medicines (shown once the doctor has prescribed).
            if (p.prescription.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Prescribed Medicines'),
                ...p.prescription.map((m) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 4, right: 6), child: Icon(Icons.medication_outlined, size: 14, color: C2.cyan)),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayDosage(m.dosage).isEmpty
                              ? m.name
                              : '${m.name} · ${displayDosage(m.dosage)}',
                          style: ct(13, FontWeight.w600, C2.text)),
                      Text('${m.interval} · ${m.days} · Qty ${m.qty}', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                  ]))),
              ])),
            // Doctor Remarks (from the Case Details screen). The
            // "Tests advised: …" line the doctor screen appends into the
            // remarks column is SPLIT OUT here (user 2026-08-28: doctor
            // left Remarks blank yet the card showed the tests line) —
            // it renders under its own "Tests Advised" card instead, and
            // an empty remainder hides the Doctor Remarks card entirely.
            Builder(builder: (_) {
              // Split the tests line off BOTH copies, so the "Show original"
              // toggle swaps remarks for remarks and never puts the test list
              // back (user 2026-09-28).
              (List<String>, List<String>) splitRemarks(String src) {
                final tests = <String>[];
                final rest = <String>[];
                for (final l in src.split('\n')) {
                  final t = l.trim();
                  if (t.toLowerCase().startsWith('tests advised:')) {
                    final v = t.substring('tests advised:'.length).trim();
                    if (v.isNotEmpty) tests.add(v);
                  } else if (t.isNotEmpty) {
                    rest.add(t);
                  }
                }
                return (tests, rest);
              }
              final (tests, rest) = splitRemarks(p.doctorRemarks);
              final (_, restOriginal) = splitRemarks(p.doctorRemarksOriginal);
              return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (rest.isNotEmpty)
                  CCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SecBar('Doctor Remarks'),
                    CTranslatedText(rest.join('\n'),
                        original: restOriginal.join('\n'),
                        style: ct(13, FontWeight.w400, C2.text)),
                  ])),
                if (tests.isNotEmpty)
                  CCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SecBar('Tests Advised'),
                    ...tests.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Padding(
                            padding: EdgeInsets.only(top: 3, right: 6),
                            child: Icon(Icons.science_outlined,
                                size: 14, color: C2.cyan)),
                        Expanded(child: Text(t,
                            style: ct(13, FontWeight.w400, C2.text))),
                      ]),
                    )),
                  ])),
              ]);
            }),
          ]),
        )),
        ]),
      ),
    );
  }

  /// The vitals map laid out two to a row, in the order it was built.
  /// An odd count leaves the last cell empty rather than stretching the
  /// value across the full width, so the columns stay aligned.
  List<Widget> _vitalRows(Map<String, String> vitals) {
    final e = vitals.entries.toList();
    return [
      for (var i = 0; i < e.length; i += 2)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _vitalCell(
                _kVitalUnitLabel[e[i].key] ?? e[i].key, e[i].value)),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < e.length
                  ? _vitalCell(_kVitalUnitLabel[e[i + 1].key] ?? e[i + 1].key,
                      e[i + 1].value)
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
    ];
  }

  Widget _vitalCell(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: ct(11, FontWeight.w400, C2.text2)),
          const SizedBox(height: 2),
          Text(v, style: ct(13.5, FontWeight.w600, C2.text)),
        ],
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
          Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
        ]),
      );
}

/// Detail-page display names for the vitals map keys, with units — same
/// wording as the Register form labels (user 2026-08-14). Keys the map
/// already stores with a unit (Body Temp (°F), Height (cm), Weight (kg))
/// pass through unchanged.
const Map<String, String> _kVitalUnitLabel = {
  'Systolic BP':       'Systolic BP (mmHg)',
  'Diastolic BP':      'Diastolic BP (mmHg)',
  'Blood Sugar':       'Blood Sugar (mg/dl)',
  'Oxygen':            'Oxygen Saturation (%)',
  'Oxygen Saturation': 'Oxygen Saturation (%)',
  'Heart Rate':        'Heart Rate (BPM)',
  'Hemoglobin':        'Hemoglobin (g/dl)',
};

/// Where uploaded files are published — see [AppConfig.uploadsBase], the
/// one place hosts are configured. Photos resolve as
/// `$kUploadsBase/patient_docs/<file_name>`.
const String kUploadsBase = AppConfig.uploadsBase;

/// One prescription/report photo tile on the Patient Detail screen.
/// Renders (in priority order):
///   1. Network image — serverPath is a bare "<uuid>.jpg" (or legacy
///      "patient_docs/<uuid>.jpg") under the static server's uploads dir.
///   2. Local file — the phone that captured it still has the picker copy.
///   3. Placeholder icon — a phone-local path from a DIFFERENT phone.
/// Tap opens a full-screen zoomable view.
class _AttachmentThumb extends StatelessWidget {
  final Attachment a;
  const _AttachmentThumb({required this.a});

  /// Compose the uploads URL for a server-named row. Handles both the
  /// bare name ("x.jpg") and the legacy prefixed form ("patient_docs/x.jpg").
  String? _networkUrl(BuildContext context) {
    final sp = (a.serverPath ?? '').trim();
    if (sp.isEmpty || sp.startsWith('/')) return null; // absent or phone path
    final rel = sp.contains('/') ? sp : 'patient_docs/$sp';
    return '$kUploadsBase/$rel';
  }

  @override
  Widget build(BuildContext context) {
    final url = _networkUrl(context);
    final localOk = a.path.isNotEmpty && File(a.path).existsSync();
    Widget img;
    if (url != null) {
      img = Image.network(url, width: 84, height: 84, fit: BoxFit.cover,
        loadingBuilder: (_, child, prog) => prog == null ? child
          : Container(width: 84, height: 84, color: C2.cyanLight,
              child: const Center(child: SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)))),
        errorBuilder: (_, __, ___) => _placeholder());
    } else if (localOk) {
      img = Image.file(File(a.path), width: 84, height: 84, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder());
    } else {
      img = _placeholder();
    }
    return InkWell(
      onTap: (url != null || localOk) ? () => _openFull(context, url) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
        const SizedBox(height: 2),
        SizedBox(width: 84, child: Text(a.kind.label, maxLines: 1,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: ct(10, FontWeight.w500, C2.text2))),
      ]),
    );
  }

  Widget _placeholder() => Container(
        width: 84, height: 84, color: C2.border,
        child: const Icon(Icons.description_outlined, size: 26, color: C2.text3),
      );

  void _openFull(BuildContext context, String? url) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(children: [
        InteractiveViewer(
          maxScale: 5,
          child: url != null
              ? Image.network(url, fit: BoxFit.contain)
              : Image.file(File(a.path), fit: BoxFit.contain),
        ),
        Positioned(top: 4, right: 4, child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        )),
      ]),
    ));
  }
}

/// Human-readable appointment status + colours for a patient's flow stage.
/// Covers the full appointment_status_t ladder so no stage falls through
/// to a misleading default.
(String, Color, Color) apptStatus(String status) => switch (status) {
      'completed' => ('Completed', const Color(0xFFEDF7E0), C2.green),
      'with_pharma' => ('At Pharmacy', C2.badgeBlue, C2.white),
      'with_doctor' => ('With Doctor', C2.badgeBlue, C2.white),
      'with_lab' => ('At Lab', C2.cyanLight, C2.cyan),
      'with_counsellor' => ('Payment Due', Color(0xFFFEF7E0), Color(0xFFB8860B)),
      'denied' => ('Delivery Denied', Color(0xFFFDEAEA), C2.danger),
      'lama' => ('LAMA', Color(0xFFFDEAEA), C2.danger),
      _ => ('Waiting', Color(0xFFFEF7E0), Color(0xFFB8860B)),
    };

/// CR25: Appointment Status — search a patient (online/offline) by village,
/// name or unique code and see their current appointment status.
class CounAppointmentStatus extends StatefulWidget {
  /// Called when the counsellor taps "Re-Appointment" on a search result.
  /// The shell uses this to stash the patient in CounsellorState and swap
  /// to the Register tab (rule 2026-07-29).
  final ValueChanged<CPatient>? onReAppointment;
  const CounAppointmentStatus({super.key, this.onReAppointment});
  @override
  State<CounAppointmentStatus> createState() => _CounAppointmentStatusState();
}

class _CounAppointmentStatusState extends State<CounAppointmentStatus> {
  bool online = true;
  String? village;
  final _name = TextEditingController();
  // Search by patient mobile number (rule 2026-07-29). Was Unique Code
  // originally — the identifier is now the contact number.
  final _mobile = TextEditingController();
  bool _searched = false;

  // Online mode state (rule 2026-08-13): Search hits GET /api/patients
  // against the whole org register; results live here, never merged into
  // the shared CounsellorState so the Home list stays a clean 7-day feed.
  bool _searching = false;
  String? _searchErr;
  List<CPatient> _onlineRows = const [];

  /// Village filter options — the whole district from the backend
  /// geography cache; hardcoded map only as a first-launch fallback.
  List<String> _villageOptions(MastersStore geo) => geo.hasGeo
      ? geo.geoAllVillages
      : [for (final v in kBlockVillages.values) ...v];

  static const _kMonths = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  /// Offline search window (rule 2026-08-13): only the last 8 days of
  /// locally-held data is searchable offline. The local store itself is
  /// already just the backend past-7-days pull + today's registrations,
  /// so nothing older ever gets downloaded to the phone.
  bool _within8Days(String regDate) {
    final parts = regDate.split('-');
    if (parts.length != 3) return true; // unparseable → keep (local rows)
    final day = int.tryParse(parts[0]);
    final month = _kMonths[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return true;
    final d = DateTime(year, month, day);
    return !d.isBefore(DateTime.now().subtract(const Duration(days: 8)));
  }

  List<CPatient> _results(CounsellorState s) {
    // Guard: empty search must not dump every patient (user bug
    // 2026-08-20). At least one input is required — same rule as online.
    if (!_hasSearchCriteria()) return const [];
    final name = _name.text.trim().toLowerCase();
    final mobile = _mobile.text.trim();
    return s.patients.where((p) {
      if (!_within8Days(p.regDate)) return false;
      if (village != null && p.village != village) return false;
      if (name.isNotEmpty && !p.name.toLowerCase().contains(name)) return false;
      // Mobile match is a prefix/substring on the raw contact digits so a
      // partial number ("98765") still surfaces the patient.
      if (mobile.isNotEmpty && !p.contact.contains(mobile)) return false;
      return true;
    }).toList();
  }

  /// True when the user has typed / picked ENOUGH to run a meaningful
  /// search — village, ≥2-char name or ≥3-digit mobile. Blank searches
  /// used to return the entire DB (user bug 2026-08-20).
  bool _hasSearchCriteria() =>
      (village != null && village!.isNotEmpty) ||
      _name.text.trim().length >= 2 ||
      _mobile.text.trim().length >= 3;

  /// Online search — GET /api/patients with q = mobile (preferred) or name.
  /// The backend q matches name / contact / unique_code; the other typed
  /// field plus the village pick are applied client-side on the result.
  Future<void> _doOnlineSearch() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_hasSearchCriteria()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Type a name, mobile or pick a village to search.'),
        backgroundColor: C2.danger,
      ));
      return;
    }
    setState(() { _searched = true; _searching = true; _searchErr = null; });
    try {
      final api = context.read<PatientsApi>();
      final name = _name.text.trim();
      final mobile = _mobile.text.trim();
      final q = mobile.isNotEmpty ? mobile : (name.isNotEmpty ? name : null);
      final res = await api.list(q: q, limit: 100);
      if (!mounted) return;
      var rows = [for (final r in res.items) _rowToPatient(r)];
      if (name.isNotEmpty) {
        rows = rows.where((p) => p.name.toLowerCase().contains(name.toLowerCase())).toList();
      }
      if (mobile.isNotEmpty) {
        rows = rows.where((p) => p.contact.contains(mobile)).toList();
      }
      if (village != null) {
        rows = rows.where((p) => p.village == village).toList();
      }
      setState(() { _onlineRows = rows; _searching = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _searching = false; _searchErr = e.message; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _searching = false; _searchErr = e.toString(); });
    }
  }

  CPatient _rowToPatient(Map<String, dynamic> r) => CPatient(
        id:         'S${r['patient_id']}',
        name:       (r['patient_name'] ?? '').toString(),
        gender:     (r['gender'] ?? 'Female').toString(),
        age:        (r['age'] as num?)?.toInt() ?? 0,
        contact:    (r['contact_number'] ?? '').toString(),
        uniqueCode: (r['unique_code'] ?? '').toString(),
        block:      (r['block_name'] ?? '').toString(),
        village:    (r['village_name'] ?? '').toString(),
        regDate:    ((r['last_visit'] ?? '') as Object).toString(),
      );

  /// Open a result row. Online rows ('S<pid>') don't carry an
  /// appointment_id, so fetch the patient first to find the latest visit —
  /// that id is what lets the detail screen hydrate symptoms / vitals /
  /// photos. Falls back to a plain open if the fetch fails.
  Future<void> _openResult(CPatient p) async {
    if (p.id.startsWith('S')) {
      try {
        final api = context.read<PatientsApi>();
        final pid = int.tryParse(p.id.substring(1));
        if (pid != null) {
          final d = await api.get(pid);
          final appts = (d['appointments'] as List?) ?? const [];
          if (appts.isNotEmpty && appts.first is Map) {
            final a = (appts.first as Map).cast<String, dynamic>();
            p.backendAppointmentId = (a['appointment_id'] as num?)?.toInt();
            p.status = (a['status'] ?? p.status).toString();
            // Detail hydrate keys off the 'B' prefix — flip it now that
            // the appointment id is known.
            // (id is final; hydrate checks prefix, so re-wrap instead.)
          }
        }
      } catch (_) { /* open with the fields we have */ }
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => CounPatientDetail(p: p, showReAppointment: true)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    // Online mode renders what the API returned; offline filters the local
    // 8-day store. Neither leaks into the other.
    final results = !_searched
        ? <CPatient>[]
        : (online ? _onlineRows : _results(s));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: SecBar('Appointment Status')),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Search Patient'),
        CField('Search Mode', Row(children: [
          Expanded(child: _modeBtn('Online Search', 'Entire database', true)),
          const SizedBox(width: 8),
          Expanded(child: _modeBtn('Offline Search', 'Last 8 days', false)),
        ])),
        CField('Village', SearchDropdown(
          items: _villageOptions(context.watch<MastersStore>()),
          value: village, hint: 'Select Village',
          onChanged: (v) => setState(() {
            village = v;
            // Offline: live-filter as soon as a village is picked so
            // results appear without a Search-button tap (user
            // 2026-08-20: "closing keyboard then showing search
            // result — can we make this simpler").
            if (!online) _searched = _hasSearchCriteria();
          }))),
        CField('Patient Name', TextField(
          controller: _name,
          decoration: cInput('Type patient name'),
          onChanged: (_) {
            if (!online) setState(() => _searched = _hasSearchCriteria());
          })),
        CField('Mobile Number', TextField(
          controller: _mobile, keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: cInput('10-digit mobile'),
          onChanged: (_) {
            if (!online) setState(() => _searched = _hasSearchCriteria());
          })),
        Row(children: [
          Expanded(child: CPrimaryButton(
            _searching ? 'Searching…' : 'Search',
            icon: Icons.search,
            onTap: _searching ? null : () {
              if (online) {
                _doOnlineSearch();
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
                if (!_hasSearchCriteria()) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                        'Type a name, mobile or pick a village to search.'),
                    backgroundColor: C2.danger,
                  ));
                  return;
                }
                setState(() => _searched = true);
              }
            })),
          const SizedBox(width: 8),
          COutlineButton('Clear', icon: Icons.clear, onTap: () => setState(() {
            village = null; _name.clear(); _mobile.clear();
            _searched = false; _onlineRows = const []; _searchErr = null;
          })),
        ]),
      ])),
      if (_searching)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
        ),
      if (!_searching && _searchErr != null)
        Padding(padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: _doOnlineSearch,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEECEA), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 14, color: C2.danger),
                const SizedBox(width: 6),
                Expanded(child: Text('Search failed — tap to retry',
                  style: ct(11, FontWeight.w500, C2.danger))),
                const Icon(Icons.refresh, size: 14, color: C2.danger),
              ]),
            ),
          )),
      if (_searched && !_searching)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SecBar('${online ? "Online" : "Offline"} Results (${results.length})'),
          if (results.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Center(child: Text('No matching patients', style: ct(12, FontWeight.w400, C2.text2))))
          else
            ...results.map((p) => _statusRow(context, p)),
        ])),
    ]);
  }

  Widget _modeBtn(String title, String sub, bool isOnline) {
    final sel = online == isOnline;
    return InkWell(
      // Switching modes wipes the filters + results BOTH ways (user
      // 2026-08-22) — a village/name typed for one store must not silently
      // constrain the other.
      onTap: () => setState(() {
        if (online != isOnline) {
          village = null; _name.clear(); _mobile.clear();
          _searched = false; _onlineRows = const []; _searchErr = null;
        }
        online = isOnline;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? C2.cyan : C2.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? C2.cyan : C2.border, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ct(12.5, FontWeight.w700, sel ? Colors.white : C2.navy)),
          Text(sub, style: ct(10, FontWeight.w400, sel ? Colors.white70 : C2.text2)),
        ]),
      ),
    );
  }

  Widget _statusRow(BuildContext context, CPatient p) {
    final (label, bg, fg) = apptStatus(p.status);
    // Compose the two demographic lines. Age reads "28 yrs" when known;
    // village + mobile share the second line so the row stays short.
    final ageStr = p.age > 0 ? '${p.age} yrs' : '—';
    final village = p.village.isEmpty ? '—' : p.village;
    final mobile = p.contact.isEmpty ? '—' : p.contact;
    return InkWell(
      // Status is the only opener that surfaces Re-Appointment. Online
      // rows resolve their latest appointment_id on the way in so the
      // detail screen can hydrate symptoms / vitals / photos.
      onTap: () => _openResult(p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.name} · $ageStr', style: ct(13, FontWeight.w600, C2.text)),
            const SizedBox(height: 2),
            Text('$village · $mobile', style: ct(11.5, FontWeight.w400, C2.text2)),
          ])),
          const SizedBox(width: 8),
          CBadge(label, bg: bg, fg: fg),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: C2.text3, size: 18),
        ]),
      ),
    );
  }
}

/// List of patients opened from the home stat tiles (Registered Today / Visits Completed).
class CounPatientsList extends StatefulWidget {
  final String title;
  final List<CPatient> patients;
  const CounPatientsList({super.key, required this.title, required this.patients});
  @override
  State<CounPatientsList> createState() => _CounPatientsListState();
}

class _CounPatientsListState extends State<CounPatientsList> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.patients
        : widget.patients.where((p) =>
            p.name.toLowerCase().contains(q)
            || p.uniqueCode.toLowerCase().contains(q)
            || p.contact.contains(q)
            || p.village.toLowerCase().contains(q)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('${widget.title} (${widget.patients.length})',
              style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              decoration: cInput('Search by name, code, contact or village…').copyWith(
                prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => _q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(
                widget.patients.isEmpty ? 'No records'
                  : (q.isEmpty ? 'No records' : 'No patient matches "$_q"'),
                style: ct(13, FontWeight.w400, C2.text2)))
            : CLazyRowCard(
                itemCount: list.length,
                itemBuilder: (_, i) => _PatientRow(list[i]),
              )),
        ]),
      ),
    );
  }
}

// The old Home sync pill moved into the app bar as an icon + detail
// sheet (shell.dart `SyncStatusIcon`, user 2026-08-14) — same counts,
// same tap-to-drain, only the surface changed.
