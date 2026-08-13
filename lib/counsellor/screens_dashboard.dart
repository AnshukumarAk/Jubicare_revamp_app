import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_errors.dart';
import '../api/appointments_api.dart';
import '../api/sync_service.dart';
import 'cw.dart';
import 'cdata.dart';
import 'cstate.dart';

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
      GradGreeting(name: name, sub: 'Counsellor Dashboard', initials: initials),
      // Sync status pill — shows how many mutations were pushed to the
      // backend the last time /mobile/sync/push ran, plus anything still
      // queued. Tap to force a drain.
      const _SyncStatusPill(),
      // Backend refresh status: thin loading bar while the shell's
      // _refreshFromBackend is in flight, and a red retry banner if the
      // last pull failed. Doctor/pharmacist shells show the same UI.
      if (s.refreshing)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
        ),
      if (!s.refreshing && s.lastRefreshError != null)
        Padding(padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEECEA), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 14, color: C2.danger),
                const SizedBox(width: 6),
                Expanded(child: Text('Showing cached list — tap to retry',
                  style: ct(11, FontWeight.w500, C2.danger))),
                const Icon(Icons.refresh, size: 14, color: C2.danger),
              ]),
            ),
          )),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientsList(
              title: 'Visits Completed',
              patients: s.patients.where((p) => p.status == 'completed').toList()))))),
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
    final (bg, fg, label) = switch (p.status) {
      'completed' => (const Color(0xFFEDF7E0), C2.green, 'Done'),
      'with_doctor' => (C2.cyanLight, C2.cyan, 'With Doctor'),
      _ => (const Color(0xFFFEF7E0), const Color(0xFFB8860B), 'Waiting'),
    };
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

  CPatient get p => widget.p;

  @override
  void initState() {
    super.initState();
    // Backend rows (id 'B…') carry only the queue-list summary. Fetch
    // the full appointment via /api/appointments/{id} so this screen
    // shows symptoms, diagnoses, vitals + counsellor remarks — none of
    // which are in the list response. Locally-added patients ('P…')
    // and demo seed (numeric) already have all fields in memory, so
    // we skip the network call for them.
    if (p.backendAppointmentId != null && p.id.startsWith('B')) {
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
      p.remarks = (d['counsellor_remarks'] ?? '').toString();
      p.doctorRemarks = (d['doctor_remarks'] ?? '').toString();
      p.observations = (d['observation'] ?? '').toString();
      p.pregnant = (d['pregnant'] as bool?) ?? p.pregnant;
      // Prescription — pharmacist-visible rows the doctor entered.
      final rxRows = (d['prescription'] as List?) ?? const [];
      p.prescription = <RxItem>[
        for (final r in rxRows)
          if (r is Map)
            RxItem(
              name: (r['medicine_name'] ?? '').toString(),
              dosage: (r['dosage'] ?? '').toString(),
              interval: (r['frequency'] ?? 'TDS').toString(),
              days: '${r['duration_days'] ?? 5} Days',
              qty: (r['qty'] as num?)?.toInt() ?? 0,
              dispensedQty: (r['dispensed_qty'] as num?)?.toInt(),
              dispensed: (r['dispensed'] as bool?) ?? false,
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
          if (!_loading && _err != null)
            Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: InkWell(
                onTap: _hydrate,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEECEA), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    const Icon(Icons.cloud_off, size: 14, color: C2.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Showing cached view — tap to retry',
                      style: ct(11, FontWeight.w500, C2.danger))),
                    const Icon(Icons.refresh, size: 14, color: C2.danger),
                  ]),
                ),
              )),
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
                  Text('${p.gender}, ${p.age}y${p.uniqueCode.isNotEmpty ? " · ${p.uniqueCode}" : ""}', style: ct(12, FontWeight.w400, C2.text2)),
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
              if (p.disease.isNotEmpty) _kv('Likely', p.disease),
              _kv('Registered', p.registeredOn),
              // Re-Appointment CTA (rule 2026-07-31). Sits at the end of the
              // Registration Details card so the counsellor sees it right
              // where they read the demographics.
              if (widget.showReAppointment) ...[
                const SizedBox(height: 12),
                CPrimaryButton(
                  'Re-Appointment',
                  icon: Icons.event_repeat_outlined,
                  onTap: () {
                    context.read<CounsellorState>().startReAppointmentFor(p);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ])),
            if (p.vitals.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Vitals'),
                ...p.vitals.entries.map((e) => _kv(e.key, e.value)),
              ])),
            if (p.remarks.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Patient Remarks'),
                Text(p.remarks, style: ct(13, FontWeight.w400, C2.text)),
              ])),
            // Doctor's prescribed medicines (shown once the doctor has prescribed).
            if (p.prescription.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Prescribed Medicines'),
                ...p.prescription.map((m) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 4, right: 6), child: Icon(Icons.medication_outlined, size: 14, color: C2.cyan)),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.dosage.isEmpty ? m.name : '${m.name} · ${m.dosage}', style: ct(13, FontWeight.w600, C2.text)),
                      Text('${m.interval} · ${m.days} · Qty ${m.qty}', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                  ]))),
              ])),
            // Doctor Remarks (from the Case Details screen).
            if (p.doctorRemarks.isNotEmpty)
              CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SecBar('Doctor Remarks'),
                Text(p.doctorRemarks, style: ct(13, FontWeight.w400, C2.text)),
              ])),
          ]),
        )),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
          Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
        ]),
      );
}

/// Human-readable appointment status + colours for a patient's flow stage.
(String, Color, Color) apptStatus(String status) => switch (status) {
      'completed' => ('Completed', const Color(0xFFEDF7E0), C2.green),
      'with_pharma' => ('At Pharmacy', C2.cyanLight, C2.cyan),
      'with_doctor' => ('With Doctor', C2.cyanLight, C2.cyan),
      'denied' => ('Delivery Denied', Color(0xFFFDEAEA), C2.danger),
      _ => ('Registered', Color(0xFFFEF7E0), Color(0xFFB8860B)),
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

  List<String> get _villages => [for (final v in kBlockVillages.values) ...v];

  List<CPatient> _results(CounsellorState s) {
    final name = _name.text.trim().toLowerCase();
    final mobile = _mobile.text.trim();
    return s.patients.where((p) {
      if (village != null && p.village != village) return false;
      if (name.isNotEmpty && !p.name.toLowerCase().contains(name)) return false;
      // Mobile match is a prefix/substring on the raw contact digits so a
      // partial number ("98765") still surfaces the patient.
      if (mobile.isNotEmpty && !p.contact.contains(mobile)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final results = _searched ? _results(s) : <CPatient>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: SecBar('Appointment Status')),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Search Patient'),
        CField('Search Mode', Row(children: [
          Expanded(child: _modeBtn('Online Search', 'Entire database', true)),
          const SizedBox(width: 8),
          Expanded(child: _modeBtn('Offline Search', 'Local storage', false)),
        ])),
        CField('Village', SearchDropdown(
          items: _villages, value: village, hint: 'Select Village',
          onChanged: (v) => setState(() => village = v))),
        CField('Patient Name', TextField(controller: _name, decoration: cInput('Type patient name'))),
        CField('Mobile Number', TextField(
          controller: _mobile, keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: cInput('10-digit mobile'),
        )),
        Row(children: [
          Expanded(child: CPrimaryButton('Search', icon: Icons.search, onTap: () => setState(() => _searched = true))),
          const SizedBox(width: 8),
          COutlineButton('Clear', icon: Icons.clear, onTap: () => setState(() {
            village = null; _name.clear(); _mobile.clear(); _searched = false;
          })),
        ]),
      ])),
      if (_searched)
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
      onTap: () => setState(() => online = isOnline),
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
      onTap: () => Navigator.push(context, MaterialPageRoute(
        // Status is the only opener that surfaces Re-Appointment.
        builder: (_) => CounPatientDetail(p: p, showReAppointment: true))),
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
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [
                CCard(child: Column(children: list.map((p) => _PatientRow(p)).toList())),
              ])),
        ]),
      ),
    );
  }
}

/// Diagnostic pill visible on the counsellor Home. Reads live counts
/// from SyncService so a user can see: how many actions still queued,
/// how many were applied / rejected / failed in the last drain, and the
/// timestamp of the last push. Tap to force a drain.
class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill();
  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final applied = sync.lastApplied;
    final rejected = sync.lastRejected;
    final failed = sync.lastFailed;
    final pending = sync.pending;
    final draining = sync.isDraining;
    final ts = sync.lastDrainAt;
    final bg = pending == 0 && failed == 0
        ? const Color(0xFFEDF7E0)
        : (failed > 0 || rejected > 0 ? const Color(0xFFFEECEA) : const Color(0xFFEEF2F7));
    final fg = pending == 0 && failed == 0
        ? C2.green
        : (failed > 0 || rejected > 0 ? C2.danger : C2.text2);
    final label = pending == 0
        ? (ts == null
            ? 'Sync: nothing to send yet'
            : 'Sync: applied $applied · rejected $rejected · failed $failed')
        : 'Sync: $pending pending${draining ? ' · sending…' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: draining ? null : sync.drain,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(
              draining ? Icons.sync : (pending == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined),
              size: 16, color: fg,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: ct(12, FontWeight.w600, fg))),
            if (pending > 0 && !draining)
              const Icon(Icons.refresh, size: 16, color: C2.text2),
          ]),
        ),
      ),
    );
  }
}
