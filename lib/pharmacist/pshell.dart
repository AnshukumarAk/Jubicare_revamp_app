import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'dart:io';

import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../config/app_config.dart';
import '../api/appointments_api.dart';
import '../api/attendance_api.dart';
import '../api/camps_api.dart';
import '../api/masters_store.dart';
import '../api/queues_api.dart';
import '../api/requisitions_api.dart';
import '../api/sync_service.dart';
import '../api/uploads_api.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/screens_dashboard.dart' show CounPatientDetail, CounPatientsList, kUploadsBase;
import '../doctor/dshell.dart' show DocHeader, DocBottomNav;
import '../doctor/ddata.dart' show kMedicineNames, parseDosage, kDosageForms, kDosageFormSep, dosageFormNeedsQty;
import '../services/connectivity_service.dart';
import '../services/deepgram_stt.dart';
import '../services/attendance_store.dart';
import '../services/patients_cache_store.dart';
import '../services/terminology_store.dart';
import '../services/back_form_registry.dart';
import '../services/requisitions_store.dart';
import '../services/fcm_service.dart';
import '../services/notification_router.dart';
import '../services/notifications_service.dart';
import '../state/app_state.dart';
import '../widgets/attendance_capture.dart';
import '../widgets/pending_alert.dart';
import '../widgets/photo_lightbox.dart';

class PharmacistShell extends StatefulWidget {
  final String userName;
  const PharmacistShell({super.key, this.userName = 'J.P. Singh'});
  @override
  State<PharmacistShell> createState() => _PharmacistShellState();
}

class _PharmacistShellState extends State<PharmacistShell> {
  int _tab = 0;
  // Hooked into the app-bar refresh button so a stalled network can be
  // recovered without a full app restart (user rule 2026-08-16).
  final GlobalKey<_PharmaDashboardState> _dashKey = GlobalKey<_PharmaDashboardState>();
  final GlobalKey<_PharmaStockState> _stockKey = GlobalKey<_PharmaStockState>();
  // Visited-tab history — Android back walks it backwards instead of
  // closing the app (user bug 2026-08-16).
  final List<int> _tabHistory = [0];
  static const _nav = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.inventory_2_outlined, 'Stock'),
    // Report tab removed 2026-07-29 per user rule.
    (Icons.event_available_outlined, 'Attend'),
  ];
  void _go(int i) {
    if (_tab != i) {
      _tabHistory.remove(i);
      _tabHistory.add(i);
    }
    setState(() => _tab = i);
  }

  bool _handleBack() {
    // Open check-in/out form on the Attend tab eats the first back press
    // (user 2026-08-21 — back must show the attend list, not the last tab).
    if (_tab == 2 && BackFormRegistry.close('pharma.attend')) return true;
    if (_tabHistory.length <= 1) return false;
    _tabHistory.removeLast();
    setState(() => _tab = _tabHistory.last);
    return true;
  }

  final _attendRefresh = ValueNotifier(0);

  /// One refresh path for the app-bar button AND pull-to-refresh: online
  /// check first, then the visible data — dashboard queue + stock always
  /// (existing behaviour), plus the Attend tab's rows when it is current.
  /// The offline sync queue is never touched (user rule 2026-08-21).
  Future<void> _refreshAll() async {
    if (!mounted || !context.read<ConnectivityService>().isOnline) return;
    // Masters + terminology also refresh on the app-bar/pull refresh so
    // any new medicine, symptom, block/village or clinical-sheet update
    // reaches the app without a re-login (user 2026-08-25).
    unawaited(context.read<MastersStore>().refresh());
    unawaited(context.read<TerminologyStore>().refresh());
    await Future.wait([
      if (_dashKey.currentState != null) _dashKey.currentState!.refreshNow(),
      if (_stockKey.currentState != null) _stockKey.currentState!.refreshNow(),
    ]);
    if (_tab == 2) _attendRefresh.value++;
  }

  @override
  void initState() {
    super.initState();
    NotificationRouter.instance.pending.addListener(_applyNotificationRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyNotificationRoute());
  }

  @override
  void dispose() {
    NotificationRouter.instance.pending.removeListener(_applyNotificationRoute);
    super.dispose();
  }

  void _applyNotificationRoute() {
    if (!mounted) return;
    final r = NotificationRouter.instance.consume();
    if (r == null) return;
    switch (r.route) {
      // Pharma tabs: 0=Home, 1=Stock, 2=Attend
      case 'attend':          _go(2); break;
      case 'pharma_dispense': _go(0); break; // dashboard shows queue
      case 'stock':           _go(1); break;
      // Requisitions live inside the Stock tab. Additionally, if the
      // push carried a req id in route_arg, jump straight into that
      // requisition's detail sheet on the Past sub-tab (user
      // 2026-09-10 "when requisition accept then send on Past tab
      // here his info page").
      case 'requisition':
        _go(1);
        final reqId = int.tryParse(r.arg ?? '');
        if (reqId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _stockKey.currentState?.openRequisition(reqId);
          });
        }
        break;
      case 'home':            _go(0); break;
      default: break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isEmpty ? 'P' : widget.userName[0].toUpperCase();
    final pages = [
      PharmaDashboard(key: _dashKey, name: widget.userName),
      PharmaStock(key: _stockKey),
      // PharmaReport removed 2026-07-29 per user rule.
      PharmaAttendance(refreshSignal: _attendRefresh),
    ];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (_handleBack()) return;
          // Root of the app — confirm before closing (user 2026-08-23).
          if (await confirmExit(context)) SystemNavigator.pop();
        },
        child: Scaffold(
        backgroundColor: C2.bg,
        body: Column(children: [
          DocHeader(initials: initials, userName: widget.userName, role: 'Pharmacist',
            onRefresh: _refreshAll),
          // Pull-to-refresh on every tab (user rule 2026-08-16 —
          // matches the doctor role). Refreshes both the dashboard
          // queue and the Stock tab's requisitions in one gesture.
          Expanded(child: IndexedStack(index: _tab, children: pages.map((p) =>
            RefreshIndicator(
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                child: p),
            )).toList())),
        ]),
        bottomNavigationBar: DocBottomNav(items: _nav, current: _tab, onTap: _go),
      ),
      ),
    );
  }
}

// ───────────────── Dashboard ─────────────────
class PharmaDashboard extends StatefulWidget {
  final String name;
  const PharmaDashboard({super.key, required this.name});
  @override
  State<PharmaDashboard> createState() => _PharmaDashboardState();
}

class _PharmaDashboardState extends State<PharmaDashboard> {
  bool _refreshing = false;
  String? _lastError;
  SyncService? _sync;
  int _lastDrainSig = -1;
  StreamSubscription<void>? _fcmDashSub;

  /// Public hook for the shell's app-bar refresh button (user rule
  /// 2026-08-16).
  Future<void> refreshNow() => _refreshFromBackend();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydratePatientsFromCache();
      _refreshFromBackend();
    });
    // Cross-device wake-up (user 2026-08-22): the doctor's submit fires
    // an FCM push from the server — re-pull the queue the moment it
    // arrives, no manual refresh.
    _fcmDashSub = FcmService.instance.onMessageReceived.listen((_) {
      if (mounted) _refreshFromBackend();
    });
  }

  String get _pharmaCacheKey {
    final app = context.read<AppState>();
    return 'pharmacist_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _hydratePatientsFromCache() async {
    try {
      final store = await PatientsCacheStore.open();
      final rows = store.load(_pharmaCacheKey);
      if (rows.isEmpty || !mounted) return;
      context.read<CounsellorState>()
          .mergeBackendPatients(rows, statusOverride: 'with_pharma');
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<SyncService>();
    if (!identical(_sync, s)) {
      _sync?.removeListener(_onSyncTick);
      _sync = s..addListener(_onSyncTick);
    }
  }

  @override
  void dispose() {
    _fcmDashSub?.cancel();
    _sync?.removeListener(_onSyncTick);
    super.dispose();
  }

  void _onSyncTick() {
    final sig = (_sync?.lastApplied ?? 0) * 100000 + (_sync?.lastRejected ?? 0) * 100 + (_sync?.lastFailed ?? 0);
    if (sig != _lastDrainSig && (_sync?.lastDrainAt != null)) {
      _lastDrainSig = sig;
      _refreshFromBackend();
    }
  }

  Future<void> _refreshFromBackend() async {
    if (_refreshing || !mounted) return;
    setState(() { _refreshing = true; _lastError = null; });
    try {
      final api = context.read<QueuesApi>();
      // Fetch the primary queue. ANY failure here is silent — cached
      // list is already on screen and the retry button is one tap away
      // (user 2026-08-26: "server started but red banner not going" —
      // the banner survived until every conceivable throw path was
      // treated silent). Once this succeeds we know the server is
      // reachable, so a stale error is cleared unconditionally.
      QueueList queue;
      try {
        queue = await api.pharmaQueue(limit: 200);
      } catch (_) {
        return; // banner already cleared at start; retry will run again
      }
      final week = await api.pharmaPast7Days(limit: 200)
          .catchError((_) => QueueList(items: const [], total: 0, count: 0));
      if (!mounted) return;
      final store = context.read<CounsellorState>();
      final queueIds = {
        for (final r in queue.items) r['appointment_id'],
      };
      final combined = [
        for (final r in queue.items) {...r, 'status': 'with_pharma'},
        for (final r in week.items)
          if (!queueIds.contains(r['appointment_id'])) r,
      ];
      store.mergeBackendPatients(combined);
      try {
        final cache = await PatientsCacheStore.open();
        await cache.save(_pharmaCacheKey, combined);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final name = widget.name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradGreeting(name: name, sub: 'Pharmacy Dashboard', initials: name.isEmpty ? 'P' : name[0].toUpperCase()),
      if (_refreshing) const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
      if (!_refreshing && _lastError != null)
        Padding(padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: _refreshFromBackend,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEECEA), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 14, color: C2.danger),
                const SizedBox(width: 6),
                Expanded(child: Text('Refresh failed — tap to retry',
                  style: ct(11, FontWeight.w500, C2.danger))),
                const Icon(Icons.refresh, size: 14, color: C2.danger),
              ]),
            ),
          )),
      Row(children: [
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            const PharmaQueueList())),
          child: StatTile('${s.pharmaQueue.length}', 'In Queue', C2.cyan))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            const PharmaDispensedList())),
          child: StatTile('${s.pharmaDispensed}', 'Dispensed', C2.green))),
        const SizedBox(width: 8),
        // Past 7 Days tile (rule 2026-07-31 — parity with doctor screen).
        // Reuses the counsellor patient list widget filtered to patients
        // that reached the pharmacy in the last week.
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            CounPatientsList(title: 'Past 7 Days', patients: s.pharmaPast7Days))),
          child: StatTile('${s.pharmaPast7Days.length}', 'Past 7 Days', C2.navy))),
      ]),
      const SizedBox(height: 14),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Pending Prescriptions'),
        if (s.pharmaQueue.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('No prescriptions pending', style: ct(12, FontWeight.w400, C2.text2))))
        else
          ...s.pharmaQueue.map((p) => _pendRow(context, p)),
      ])),
    ]);
  }

  Widget _pendRow(BuildContext context, CPatient p) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PharmaDispense(patient: p))),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
              Text('${p.disease.isEmpty ? "—" : p.disease} · ${medsLabel(p)} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
            const CBadge('Pending', bg: Color(0xFFFEF7E0), fg: Color(0xFFB8860B)),
          ]),
        ),
      );
}

/// CR27: Home "In Queue" → searchable list of pending patients. Tap a patient
/// to see basic details (same as doctor/counsellor screens).
class PharmaQueueList extends StatefulWidget {
  const PharmaQueueList({super.key});
  @override
  State<PharmaQueueList> createState() => _PharmaQueueListState();
}

class _PharmaQueueListState extends State<PharmaQueueList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final query = q.trim().toLowerCase();
    final list = s.pharmaQueue.where((p) => query.isEmpty
        || p.name.toLowerCase().contains(query) || p.contact.contains(query)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('In Queue (${s.pharmaQueue.length})', style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(decoration: cInput('Search by name or phone number').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(query.isEmpty ? 'No patients in queue' : 'No patient matches "$q"', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [CCard(child: Column(children: list.map((p) => InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientDetail(p: p, showReAppointment: false))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                      Text('${p.age}y · ${p.contact} · ${medsLabel(p)} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                    const CBadge('Pending', bg: Color(0xFFFEF7E0), fg: Color(0xFFB8860B)),
                  ]),
                ))).toList()))])),
        ]),
      ),
    );
  }
}

/// CR27: Dispensed patients — search by name/phone; tap to see dispensed meds.
class PharmaDispensedList extends StatefulWidget {
  const PharmaDispensedList({super.key});
  @override
  State<PharmaDispensedList> createState() => _PharmaDispensedListState();
}

class _PharmaDispensedListState extends State<PharmaDispensedList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final query = q.trim().toLowerCase();
    final list = s.dispensedPatients.where((p) => query.isEmpty
        || p.name.toLowerCase().contains(query) || p.contact.contains(query)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('Dispensed Patients (${s.dispensedPatients.length})', style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(decoration: cInput('Search by name or phone number').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(query.isEmpty ? 'No dispensed patients' : 'No patient matches "$q"', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [CCard(child: Column(children: list.map((p) => InkWell(
                onTap: () => _showDispensedMeds(context, p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                      Text('${p.age}y · ${p.contact} · ${medsLabel(p)} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                    ])),
                    const CBadge('Dispensed', bg: Color(0xFFEDF7E0), fg: C2.green),
                    const SizedBox(width: 6), const Icon(Icons.chevron_right, color: C2.text3, size: 18),
                  ]),
                ))).toList()))])),
        ]),
      ),
    );
  }

  /// Queue/week rows carry only medicine_count — the lines live behind
  /// GET /appointments/{id}. Fetch them on first open so the sheet never
  /// says "No medicines on record" for a genuinely dispensed case
  /// (user 2026-08-22).
  Future<void> _showDispensedMeds(BuildContext context, CPatient p) async {
    if (p.prescription.isEmpty && p.backendAppointmentId != null) {
      try {
        final d = await context
            .read<AppointmentsApi>()
            .detail(p.backendAppointmentId!);
        final lines = <RxItem>[
          for (final r in (d['prescription'] as List? ?? const []))
            if (r is Map)
              () {
                final parsed = parseDosage('${r['dosage'] ?? ''}');
                final serverForm = '${r['dosage_form'] ?? ''}'.trim();
                return RxItem(
                  itemId: (r['prescription_item_id'] as num?)?.toInt(),
                  name: '${r['medicine_name'] ?? ''}',
                  dosage: parsed.strength,
                  dosageForm: serverForm.isNotEmpty ? serverForm : parsed.form,
                  interval: '${r['frequency'] ?? 'TDS'}',
                  days: '${r['duration_days'] ?? 5} Days',
                  qty: (r['qty'] as num?)?.toInt() ?? 0,
                  dispensedQty: (r['dispensed_qty'] as num?)?.toInt(),
                  dispensed: (r['dispensed'] as bool?) ?? false,
                  dispenseReason: '${r['qty_change_reason'] ?? ''}',
                  comboKey: '${r['combo_key'] ?? ''}',
                );
              }(),
        ]..removeWhere((m) => m.name.trim().isEmpty);
        if (lines.isNotEmpty) p.prescription = lines;
      } catch (_) {/* offline — sheet shows what we have */}
    }
    if (!context.mounted) return;
    _openDispensedSheet(context, p);
  }

  void _openDispensedSheet(BuildContext context, CPatient p) => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(color: C2.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          padding: const EdgeInsets.all(16),
          child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(17, FontWeight.w700, C2.navy))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
                Text('${p.age}y · ${p.contact}', style: ct(12, FontWeight.w400, C2.text2)),
              ])),
              const CBadge('Dispensed', bg: Color(0xFFEDF7E0), fg: C2.green),
            ]),
            const Divider(height: 24),
            Text('Dispensed Medicines', style: ct(12.5, FontWeight.w700, C2.navy)),
            const SizedBox(height: 6),
            if (p.prescription.isEmpty) Text('No medicines on record.', style: ct(12, FontWeight.w400, C2.text2)),
            ...p.prescription.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_displayNameWithDosage(m), style: ct(13, FontWeight.w600, C2.text)),
                const SizedBox(height: 2),
                Text('${m.interval} · ${m.days} · Prescribed ${m.qty} · Dispensed ${m.dispensedQty}',
                    style: ct(11.5, FontWeight.w400, C2.text2)),
                // Show the pharmacist's reason when dispensed qty differed
                // from prescribed and a note was captured (user 2026-09-08).
                if (m.dispenseReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${m.dispenseReason.trim()}',
                      style: ct(11.5, FontWeight.w600, C2.danger)),
                ],
              ]),
            )),
            const SizedBox(height: 8),
          ]))),
        ),
      );
}

/// How many medicines to show in a list row.
///
/// Loaded lines win once a detail fetch has filled them in; before that the
/// queue row's own `medicine_count` is the only number available. Reading
/// `prescription.length` alone showed every backend patient as "0 meds",
/// which reads as "nothing to dispense" for someone sent to the pharmacy.
/// Compose the medicine name + dosage cell for display, including the
/// dosage form when the doctor picked one (user 2026-09-08).
/// Format: "Paracetamol · Tab · 500 mg" / "Paracetamol · 500 mg" (no
/// form) / "Paracetamol" (no dosage either).
/// A requisition item's stored dosage might be "Cream · 20" (form
/// prefixed by the mobile submit) or a bare "500" from older builds.
/// Render the unit that matches the form — "20 ml" for liquid /
/// semi-solid forms, "500 mg" for tablets/capsules. Blank stays blank
/// so the caller decides how to show missing data (user 2026-09-14
/// "Cream Clotrimazole showing 20 mg — should be ml").
String _fmtReqDose(String stored) {
  final s = stored.trim();
  if (s.isEmpty) return '';
  final parsed = parseDosage(s);
  final strength = parsed.strength;
  final form = parsed.form;
  if (strength.isEmpty) return s; // no digits parseable — echo as-is
  final unit = dosageFormNeedsQty(form) ? 'mg' : 'ml';
  return form.isEmpty ? '$strength $unit' : '$form · $strength $unit';
}

String _displayNameWithDosage(RxItem m) {
  final form = m.dosageForm.trim();
  var strength = m.dosage.trim();
  // Append the unit that matches the form so "Cream · 20" reads as
  // "Cream · 20 ml" on Deliver Medicine, not "20 mg" (user
  // 2026-09-14 "cream Clotrimazole showing 20 mg — should be ml").
  // Skip if the doctor already wrote a unit in the strength.
  if (strength.isNotEmpty && !RegExp(r'(mg|ml|mcg|iu|g)\b', caseSensitive: false).hasMatch(strength)) {
    strength = '$strength ${dosageFormNeedsQty(form) ? 'mg' : 'ml'}';
  }
  final tail = [
    if (form.isNotEmpty) form,
    if (strength.isNotEmpty) strength,
  ].join(' · ');
  return tail.isEmpty ? m.name : '${m.name} · $tail';
}

int medsLabel(CPatient p) =>
    p.prescription.isNotEmpty ? p.prescription.length : p.medicineCount;

// ───────────────── Deliver one patient ─────────────────
class PharmaDispense extends StatefulWidget {
  final CPatient patient;
  const PharmaDispense({super.key, required this.patient});
  @override
  State<PharmaDispense> createState() => _PharmaDispenseState();
}

class _PharmaDispenseState extends State<PharmaDispense> {
  CPatient get p => widget.patient;
  final Map<RxItem, TextEditingController> _reason = {};
  // Dropdown pick per line (user 2026-08-21): Not Available / Buy From
  // Outside / Other. 'Other' opens the free-text box; the picked label
  // (or the typed text) still flows through _reasonCtl so the validate +
  // submit paths stay unchanged.
  final Map<RxItem, String?> _reasonChoice = {};
  static const _kReasonOptions = ['Not Available', 'Buy From Outside', 'Other'];
  bool _loadingRx = false;

  // Snapshot of the ORIGINAL dispensedQty per line, taken when the
  // Deliver Medicine screen opens (and again once /appointments/{id}
  // hydrates the lines). If the pharmacist edits a quantity, taps
  // back WITHOUT Confirm Delivery, and opens the same patient again,
  // the field must reappear with the doctor's prescribed number —
  // not the abandoned edit (user 2026-09-07). Restored in dispose
  // unless _confirmed = true (Confirm Delivery ran successfully).
  final Map<RxItem, int> _originalDispensedQty = {};
  bool _confirmed = false;

  // Per-medicine available stock at THIS pharmacist's facility. Populated
  // in initState from the offline cache (pharma_stock_v1 — same key the
  // Overall Status tab writes) and then refreshed from GET /medicines/stock
  // when online. Case-insensitive lookup so "Paracetamol" and "paracetamol"
  // match (user 2026-09-07 stock-aware dispense).
  Map<String, int> _stock = {};

  int _stockOf(String medicineName) {
    final key = medicineName.trim().toLowerCase();
    if (key.isEmpty) return 0;
    for (final e in _stock.entries) {
      if (e.key.trim().toLowerCase() == key) return e.value;
    }
    return 0;
  }

  void _snapshotDispensedQty() {
    for (final m in p.prescription) {
      _originalDispensedQty.putIfAbsent(m, () => m.dispensedQty);
    }
  }

  TextEditingController _reasonCtl(RxItem m) => _reason.putIfAbsent(m, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _snapshotDispensedQty();
    _loadPrescription();
    _loadStock();
  }

  Future<void> _loadStock() async {
    // 1) Warm from the cache the Overall Status tab already writes.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pharma_stock_v1');
      if (raw != null && mounted) {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        setState(() => _stock =
            {for (final e in m.entries) e.key: (e.value as num).toInt()});
      }
    } catch (_) {/* first run — no cache yet */}
    // 2) Refresh from server so a just-received requisition is reflected.
    try {
      final res = await context.read<ApiClient>().get('/medicines/stock');
      if (!mounted || res is! List) return;
      final next = <String, int>{};
      for (final r in res) {
        if (r is! Map) continue;
        final name = (r['medicine_name'] ?? '').toString();
        if (name.isEmpty) continue;
        next[name] = (r['quantity'] as num?)?.toInt() ?? 0;
      }
      setState(() => _stock = next);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pharma_stock_v1', jsonEncode(next));
      } catch (_) {/* best-effort */}
    } catch (_) {/* offline — cache holds */}
  }

  /// Fetch the medicines the doctor prescribed.
  ///
  /// /queues/pharmacist returns a flat appointment row carrying only
  /// `medicine_count` — no lines — so a CPatient built by
  /// mergeBackendPatients reaches this screen with an empty `prescription`
  /// and the pharmacist is told "No medicines prescribed" for a patient who
  /// was sent here precisely because medicines were prescribed.
  /// GET /appointments/{id} returns the lines, each with the
  /// prescription_item_id the dispense call has to quote back.
  Future<void> _loadPrescription() async {
    final apptId = p.backendAppointmentId;
    // Demo/local rows already carry their prescription in memory.
    if (apptId == null || p.prescription.isNotEmpty) return;
    _loadingRx = true;
    try {
      final d = await context.read<AppointmentsApi>().detail(apptId);
      if (!mounted) return;
      final lines = <RxItem>[
        for (final r in (d['prescription'] as List? ?? const []))
          if (r is Map)
            RxItem(
              itemId:   (r['prescription_item_id'] as num?)?.toInt(),
              name:     '${r['medicine_name'] ?? ''}',
              // Split "<form> · <strength>" back apart (user 2026-09-08).
              dosage:   parseDosage('${r['dosage'] ?? ''}').strength,
              dosageForm: '${r['dosage_form'] ?? ''}'.trim().isNotEmpty
                  ? '${r['dosage_form']}'.trim()
                  : parseDosage('${r['dosage'] ?? ''}').form,
              interval: '${r['frequency'] ?? 'TDS'}',
              days:     '${r['duration_days'] ?? 5} Days',
              qty:      (r['qty'] as num?)?.toInt() ?? 0,
              // Falls back to the prescribed qty so the Delivered field opens
              // pre-filled with the expected amount (user 2026-08-22) — the
              // server sends 0, not null, for still-undispensed lines, which
              // used to override that fallback and force a "reason" on every
              // line. The reason dropdown now only appears when the
              // pharmacist actually changes the quantity.
              dispensedQty: ((r['dispensed_qty'] as num?)?.toInt() ?? 0) > 0
                  ? (r['dispensed_qty'] as num).toInt()
                  : null,
              dispensed: (r['dispensed'] as bool?) ?? false,
              // Combination-strip group id so _medRows can merge two
              // lines the doctor wrote as one deliverable (user
              // 2026-09-12). Blank on standalone lines.
              comboKey: '${r['combo_key'] ?? ''}',
            ),
      ]..removeWhere((m) => m.name.trim().isEmpty);
      setState(() {
        if (lines.isNotEmpty) p.prescription = lines;
        _loadingRx = false;
        // Fresh lines from server → snapshot their dispensedQty so
        // dispose can restore the original values.
        _snapshotDispensedQty();
      });
    } catch (_) {
      // Offline: leave the list empty rather than blocking. The pharmacist
      // still sees the patient and can retry once the network is back.
      if (mounted) setState(() => _loadingRx = false);
    }
  }

  @override
  void dispose() {
    // Abandoned edits → restore original dispensed quantities so the
    // next visit shows the doctor's prescribed number (user 2026-09-07).
    // Confirm Delivery sets _confirmed=true, so a successful dispense
    // keeps the pharmacist's committed values.
    if (!_confirmed) {
      for (final entry in _originalDispensedQty.entries) {
        entry.key.dispensedQty = entry.value;
      }
    }
    for (final c in _reason.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<CounsellorState>();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)), title: Text('Deliver Medicine', style: ct(16, FontWeight.w700, C2.navy))),
        body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CCard(child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: const BoxDecoration(color: C2.cyanLight, shape: BoxShape.circle), child: Text(p.initials, style: ct(18, FontWeight.w700, C2.navy))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(16, FontWeight.w700, C2.text)),
              Text('${p.age}y · ${p.disease.isEmpty ? "—" : p.disease}', style: ct(12, FontWeight.w400, C2.text2)),
            ])),
          ])),
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Prescribed Medicines'),
            if (_loadingRx)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (p.prescription.isEmpty)
              Text('No medicines prescribed', style: ct(12, FontWeight.w400, C2.text2)),
            ..._medRows(p.prescription),
            const SizedBox(height: 8),
            CPrimaryButton('Confirm Delivery', icon: Icons.check_circle_outline, onTap: () {
              void err(String m) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(m), backgroundColor: C2.danger));
              // Guard 1 — user 2026-09-07: dispensed CANNOT exceed the
              // doctor's prescribed quantity. Over-dispense used to slip
              // through silently and lose stock without an audit reason.
              for (final m in p.prescription) {
                final given = m.dispensedQty ?? 0;
                if (given > m.qty) {
                  return err('Dispensed medicine count cannot be more than prescribed medicine count (${m.name})');
                }
              }
              // Guard 2 — user 2026-09-07: reject any line whose dispense
              // exceeds this pharmacist's on-hand stock. The stock number
              // is the same one the Overall Status tab shows.
              for (final m in p.prescription) {
                final given = m.dispensedQty ?? 0;
                if (given > 0 && given > _stockOf(m.name)) {
                  return err('Insufficient stock for ${m.name} (available: ${_stockOf(m.name)})');
                }
              }
              // Reason for quantity change is mandatory when delivered ≠ prescribed.
              for (final m in p.prescription) {
                if (m.dispensedQty != m.qty && _reasonCtl(m).text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter reason for quantity change in ${m.name}'), backgroundColor: C2.danger));
                  return;
                }
              }
              _confirmed = true; // dispose() must NOT restore originals.
              s.pharmacistDispense(p);
              // Enqueue appointment.dispense for /mobile/sync/push (v2 §4).
              // Same contract the doctor submit needs: the server resolves the
              // case by appointment_id and 422s without it, and DispenseLineIn
              // identifies each line by prescription_item_id — a medicine_name
              // is dropped, so every dispense was silently rejected and the
              // patient stayed in the pharmacy queue.
              context.read<SyncService>().enqueue(kind: 'appointment.dispense', payload: {
                if (p.backendAppointmentId != null)
                  'appointment_id': p.backendAppointmentId,
                'client_appointment_ref': p.id,
                'lines': [
                  for (final m in p.prescription)
                    if (m.itemId != null)
                      {
                        'prescription_item_id': m.itemId,
                        'dispensed_qty': m.dispensedQty,
                        if (m.dispensedQty != m.qty)
                          'qty_change_reason': _reasonCtl(m).text.trim(),
                      },
                ],
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivered for ${p.name}'), backgroundColor: C2.green));
              Navigator.pop(context);
            }),
          ])),
        ])),
      ),
    );
  }

  /// Lay out the prescription list, grouping any two lines that share
  /// a non-empty [RxItem.comboKey] into ONE combination card — that
  /// pair was written by the doctor as a single strip (Paracetamol +
  /// Vitamin C) and the pharmacist should not tick two rows for one
  /// physical item (user 2026-09-12). Standalone lines fall back to
  /// the existing single-line renderer.
  List<Widget> _medRows(List<RxItem> items) {
    final out = <Widget>[];
    final seen = <int>{};
    for (var i = 0; i < items.length; i++) {
      if (seen.contains(i)) continue;
      final m = items[i];
      if (m.comboKey.trim().isNotEmpty) {
        RxItem? partner;
        for (var j = i + 1; j < items.length; j++) {
          if (!seen.contains(j) && items[j].comboKey == m.comboKey) {
            partner = items[j];
            seen.add(j);
            break;
          }
        }
        if (partner != null) {
          out.add(_comboMedRow(m, partner));
          continue;
        }
      }
      out.add(_medRow(m));
    }
    return out;
  }

  /// Card for a combination pair: single title "A + B", shared
  /// Prescribed line and DELIVERED QTY. The typed qty writes to BOTH
  /// RxItems so the existing per-line dispense payload stays valid.
  Widget _comboMedRow(RxItem a, RxItem b) {
    final changed = a.dispensedQty != a.qty;
    final stockA = _stockOf(a.name);
    final stockB = _stockOf(b.name);
    final short = stockA < a.qty || stockB < b.qty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C2.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
              '${_displayNameWithDosage(a)} + ${_displayNameWithDosage(b)}',
              style: ct(13, FontWeight.w600, C2.text))),
          CBadge('Stock: $stockA / $stockB',
              bg: short ? const Color(0xFFFFE6E6) : const Color(0xFFEDF7E0),
              fg: short ? C2.danger : C2.green),
          const SizedBox(width: 6),
          const CBadge('Rx', bg: C2.navyLight, fg: C2.navy),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _ro('Prescribed', '${a.interval} · ${a.days} · Qty ${a.qty}')),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DELIVERED QTY', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
            SizedBox(height: 38, child: TextFormField(initialValue: '${a.dispensedQty}', keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              textAlign: TextAlign.center, style: ct(13, FontWeight.w500, C2.text), decoration: cInput(),
              onChanged: (v) => setState(() {
                final n = int.tryParse(v) ?? 0;
                a.dispensedQty = n;
                b.dispensedQty = n;
              }))),
          ])),
        ]),
        if (changed) ...[
          Padding(padding: const EdgeInsets.only(top: 6), child: DropdownButtonFormField<String>(
            value: _reasonChoice[a],
            isExpanded: true,
            decoration: cInput('Reason for quantity change *'),
            style: ct(12.5, FontWeight.w400, C2.text),
            items: [ for (final o in _kReasonOptions) DropdownMenuItem(value: o, child: Text(o)) ],
            onChanged: (v) => setState(() {
              _reasonChoice[a] = v;
              _reasonChoice[b] = v;
              final text = (v == null || v == 'Other') ? '' : v;
              _reasonCtl(a).text = text;
              _reasonCtl(b).text = text;
            }),
          )),
          if (_reasonChoice[a] == 'Other')
            Padding(padding: const EdgeInsets.only(top: 6), child: TextField(controller: _reasonCtl(a),
              decoration: cInput('Enter reason *'), style: ct(12.5, FontWeight.w400, C2.text),
              onChanged: (v) => setState(() { _reasonCtl(b).text = v; }))),
        ],
      ]),
    );
  }

  Widget _medRow(RxItem m) {
    final changed = m.dispensedQty != m.qty;
    // On-hand stock for THIS medicine at THIS pharmacist's facility
    // (user 2026-09-07: show every medicine stock in deliver medicine —
    // his own stock quantity). Red tint when short of the prescribed qty.
    final stock = _stockOf(m.name);
    final low = stock < m.qty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C2.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_displayNameWithDosage(m), style: ct(13, FontWeight.w600, C2.text))),
          CBadge('Stock: $stock',
              bg: low ? const Color(0xFFFFE6E6) : const Color(0xFFEDF7E0),
              fg: low ? C2.danger : C2.green),
          const SizedBox(width: 6),
          const CBadge('Rx', bg: C2.navyLight, fg: C2.navy),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _ro('Prescribed', '${m.interval} · ${m.days} · Qty ${m.qty}')),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DELIVERED QTY', style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
            SizedBox(height: 38, child: TextFormField(initialValue: '${m.dispensedQty}', keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              textAlign: TextAlign.center, style: ct(13, FontWeight.w500, C2.text), decoration: cInput(),
              onChanged: (v) => setState(() => m.dispensedQty = int.tryParse(v) ?? 0))),
          ])),
        ]),
        if (changed) ...[
          Padding(padding: const EdgeInsets.only(top: 6), child: DropdownButtonFormField<String>(
            value: _reasonChoice[m],
            isExpanded: true,
            decoration: cInput('Reason for quantity change *'),
            style: ct(12.5, FontWeight.w400, C2.text),
            items: [ for (final o in _kReasonOptions) DropdownMenuItem(value: o, child: Text(o)) ],
            onChanged: (v) => setState(() {
              _reasonChoice[m] = v;
              // A named reason is the answer itself; 'Other' waits for the
              // typed explanation below.
              _reasonCtl(m).text = (v == null || v == 'Other') ? '' : v;
            }),
          )),
          if (_reasonChoice[m] == 'Other')
            Padding(padding: const EdgeInsets.only(top: 6), child: TextField(controller: _reasonCtl(m),
              decoration: cInput('Enter reason *'), style: ct(12.5, FontWeight.w400, C2.text), onChanged: (_) => setState(() {}))),
        ],
      ]),
    );
  }

  Widget _ro(String label, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: ct(9.5, FontWeight.w600, C2.text2)), const SizedBox(height: 3),
        Container(height: 38, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
          child: Text(val, style: ct(12, FontWeight.w500, C2.text2))),
      ]);
}

// ───────────────── Stock ─────────────────
// One draft row on the Requisition form. Unit added 2026-07-29 alongside the
// Zonal Incharge-approval workflow so the Zonal Incharge sees packaging (Tab/Strip/Vial/ml/Bottle/Sachet)
// on the dashboard side. Qty is a String so re-order can start empty.
class _Req {
  String? name;
  String dosage;
  String unit;
  String qty;
  /// Dosage form (Tab / Cap / Syp / Gel / Cream) — same picker the
  /// doctor uses on prescription rows (user 2026-09-14). Rides on the
  /// server payload as part of the `dosage` string ("Tab · 500 mg")
  /// so no requisition schema change is needed.
  String dosageForm;
  _Req({this.name, this.dosage = '', this.unit = 'Strip', this.qty = '10',
        this.dosageForm = 'Tab'});
}

const List<String> _kMedUnits = ['Tab', 'Strip', 'Bottle', 'Vial', 'Sachet', 'ml', 'Ampoule', 'Tube', 'Piece'];

/// Pretty status label + colours for a requisition status string.
({String label, Color bg, Color fg}) _reqStatusStyle(String s) {
  switch (s) {
    case 'approved':      return (label: 'Approved',           bg: const Color(0xFFE4EEF9), fg: C2.navy);
    case 'partial':       return (label: 'Partially Approved', bg: const Color(0xFFFEF7E0), fg: const Color(0xFFB8860B));
    case 'rejected':      return (label: 'Rejected',           bg: const Color(0xFFFBE9E7), fg: C2.danger);
    case 'verified':      return (label: 'Verified',           bg: const Color(0xFFEDF7E0), fg: C2.green);
    case 'pending_zi':
    default:              return (label: 'Pending',            bg: const Color(0xFFEEF2F7), fg: C2.text2);
  }
}

class PharmaStock extends StatefulWidget {
  const PharmaStock({super.key});
  @override
  State<PharmaStock> createState() => _PharmaStockState();
}

class _PharmaStockState extends State<PharmaStock> {
  int tab = 0;
  final List<_Req> reqItems = [_Req()];
  StreamSubscription<void>? _fcmStockSub;
  SyncService? _sync;
  int _lastDrainSig = -1;

  @override
  void initState() {
    super.initState();
    // Pull the pharmacist's requisitions from /api/requisitions after
    // the first frame so cross-device history + Zonal Incharge
    // decisions land on the phone (user rule 2026-08-16 — screen was
    // reading pre-seeded local rows before this).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRequisitions();
    });
    // Approval pushes: when the admin approves/rejects on the web portal
    // the server sends an FCM message — re-pull so the decision shows
    // without a manual refresh (user 2026-08-21).
    _fcmStockSub = FcmService.instance.onMessageReceived.listen((_) {
      if (mounted) _loadRequisitions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Confirm Delivery lands on the server through the sync queue — the
    // moment that drain applies, re-pull so the Overall Status TOTAL
    // reflects the dispense WITHOUT a manual refresh (user 2026-08-22).
    final s = context.read<SyncService>();
    if (!identical(_sync, s)) {
      _sync?.removeListener(_onSyncTick);
      _sync = s..addListener(_onSyncTick);
    }
  }

  void _onSyncTick() {
    final s = _sync;
    if (s == null || s.lastDrainAt == null) return;
    final sig = s.lastApplied * 100000 + s.lastRejected * 100 + s.lastFailed;
    if (sig == _lastDrainSig) return;
    _lastDrainSig = sig;
    if (mounted) _loadRequisitions();
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSyncTick);
    _fcmStockSub?.cancel();
    super.dispose();
  }

  /// Public hook — the shell app-bar refresh button calls this.
  Future<void> refreshNow() => _loadRequisitions();

  /// Public entry point from the pharma shell's notification handler:
  /// switch to Past sub-tab and pop the detail sheet for [backendReqId]
  /// (user 2026-09-10 "requisition notification tap should open this
  /// info page, not just the Stock tab"). If the row hasn't landed yet
  /// (offline / mid-refresh) waits up to 3 s for _loadRequisitions.
  Future<void> openRequisition(int backendReqId) async {
    if (!mounted) return;
    setState(() => tab = 1); // Past sub-tab
    // Give the refresh a moment if it's currently in flight.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final match = context.read<CounsellorState>().requisitions
          .where((r) => r.backendId == backendReqId).toList();
      if (match.isNotEmpty) {
        await _ensureLinesLoaded(match.first);
        if (!mounted) return;
        final fresh = context.read<CounsellorState>().requisitions
            .firstWhere((x) => x.backendId == backendReqId,
                        orElse: () => match.first);
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => _RequisitionDetail(req: fresh)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Not found — user still on Past tab where the row will appear
    // once the next refresh lands (best-effort deep link).
  }

  bool _didPrefill = false;

  /// Pre-fill the Requisition form with the pharmacist's MOST-REQUESTED
  /// medicines (from history), newest dosage/qty — fully editable, rows
  /// removable (user 2026-08-21). Runs once, and only while the form is
  /// still pristine so typing / Re-Order prefills are never clobbered.
  void _maybePrefillFromHistory() {
    print('[JC] prefill: didPrefill=$_didPrefill mounted=$mounted '
        'rows=${reqItems.length} firstName=${reqItems.isNotEmpty ? reqItems.first.name : '-'}');
    if (_didPrefill || !mounted) return;
    if (!(reqItems.length == 1 && reqItems.first.name == null)) return;
    final s = context.read<CounsellorState>();
    print('[JC] prefill: reqs=${s.requisitions.length} '
        'items=${[for (final r in s.requisitions) r.items.length]}');
    final freq = <String, int>{};
    final latest = <String, ReqLine>{};
    final approvedOrder = <String>[]; // newest-first, medicines with an approved qty
    for (final r in s.requisitions) {
      for (final i in r.items) {
        if (i.isZonalAdded || i.name.trim().isEmpty) continue;
        freq[i.name] = (freq[i.name] ?? 0) + 1;
        latest.putIfAbsent(i.name, () => i); // list is newest-first
        if (i.approvedQty > 0 && !approvedOrder.contains(i.name)) {
          approvedOrder.add(i.name);
        }
      }
    }
    print('[JC] prefill: freq=$freq approved=$approvedOrder');
    // Most-FREQUENTLY requested first (user 2026-08-21): medicines seen in
    // 2+ past requisitions lead. User 2026-08-29: only the TOP-frequency
    // tier — not every medicine that clears the ≥2 bar. Their history had
    // Albendazole/Vit-C at 3× and Cetirizine/Calcium at 2×, and all four
    // were prefilling; the top pair alone is what the user actually
    // reorders. Ties break by most-recent use (requisitions list is
    // newest-first, so the first name to hit `latest` wins).
    var top = <String>[];
    if (freq.values.any((n) => n >= 2)) {
      final maxFreq = freq.values.reduce((a, b) => a > b ? a : b);
      final recencyIndex = <String, int>{};
      var idx = 0;
      for (final r in s.requisitions) {
        for (final i in r.items) {
          if (i.isZonalAdded || i.name.trim().isEmpty) continue;
          recencyIndex.putIfAbsent(i.name, () => idx++);
        }
      }
      top = freq.keys.where((k) => freq[k]! == maxFreq).toList()
        ..sort((a, b) => (recencyIndex[a] ?? 1 << 30)
            .compareTo(recencyIndex[b] ?? 1 << 30));
    }
    if (top.isEmpty) {
      top = [
        if (freq.isNotEmpty) freq.keys.first, // latest requested
        ...approvedOrder.take(3), // newest approved; extra in case of overlap
      ].toSet().take(3).toList();
    }
    if (top.isEmpty) return;
    setState(() {
      reqItems
        ..clear()
        ..addAll(top.map((n) {
          // Split any stored "Tab · 500 mg" back into (form, strength)
          // so the form dropdown hydrates and the dosage box keeps
          // just the number — otherwise submit would re-prefix and
          // send "Tab · Tab · 500 mg" (user 2026-09-14).
          final parsed = parseDosage(latest[n]!.dosage);
          return _Req(
            name: n,
            dosage: parsed.strength,
            dosageForm: parsed.form.isNotEmpty ? parsed.form : 'Tab',
            unit: latest[n]!.unit,
            qty: latest[n]!.requested > 0 ? '${latest[n]!.requested}' : '10',
          );
        }));
      if (reqItems.isEmpty) reqItems.add(_Req());
      _didPrefill = true;
    });
    print('[JC] prefill APPLIED: ${[for (final r in reqItems) r.name]}');
  }

  String get _reqCacheKey {
    final app = context.read<AppState>();
    return 'pharmacist_${app.backendUserId ?? app.currentUser}';
  }

  /// Live on-hand quantities from GET /medicines/stock — the Overall
  /// Status TOTAL column reads these, so a dispense moves the number
  /// (user 2026-08-22 "after submit stock not changing"). Cached for
  /// offline; the requisition-based RECV sum is the last fallback.
  Map<String, int> _liveStock = {};
  // Per-medicine dispensed-to-patients totals (server truth) — the DISP
  // column reads these when present (user 2026-08-22).
  Map<String, int> _liveDispensed = {};

  Future<void> _loadLiveStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pharma_stock_v1');
      if (raw != null && mounted && _liveStock.isEmpty) {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        setState(() => _liveStock =
            {for (final e in m.entries) e.key: (e.value as num).toInt()});
      }
      final rawD = prefs.getString('pharma_dispensed_v1');
      if (rawD != null && mounted && _liveDispensed.isEmpty) {
        final m = (jsonDecode(rawD) as Map).cast<String, dynamic>();
        setState(() => _liveDispensed =
            {for (final e in m.entries) e.key: (e.value as num).toInt()});
      }
    } catch (_) {}
    try {
      final res = await context.read<ApiClient>().get('/medicines/stock');
      if (!mounted || res is! List) return;
      final next = <String, int>{};
      final nextDisp = <String, int>{};
      for (final r in res) {
        if (r is! Map) continue;
        final name = (r['medicine_name'] ?? '').toString();
        if (name.isEmpty) continue;
        next[name] = (r['quantity'] as num?)?.toInt() ?? 0;
        nextDisp[name] = (r['dispensed_total'] as num?)?.toInt() ?? 0;
      }
      setState(() { _liveStock = next; _liveDispensed = nextDisp; });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pharma_stock_v1', jsonEncode(next));
      await prefs.setString('pharma_dispensed_v1', jsonEncode(nextDisp));
    } catch (_) {/* offline — cache/RECV fallback stays */}
  }

  Future<void> _loadRequisitions() async {
    _loadLiveStock();
    if (!mounted) return;
    final store = context.read<CounsellorState>();
    final api = context.read<RequisitionsApi>();
    store.setRequisitionsLoading(true);
    // Offline-first: hydrate from cache immediately so the list has
    // rows even before the API call resolves (user rule 2026-08-20
    // "everything works online and offline").
    try {
      final cache = await RequisitionsStore.open();
      final cached = cache.load(_reqCacheKey);
      if (cached.isNotEmpty && mounted) {
        store.applyBackendRequisitions(cached);
        // Prefill from the cached history too — a failed/slow network
        // call must not leave the form blank when history exists
        // (user bug 2026-08-21).
        _maybePrefillFromHistory();
      }
    } catch (_) {/* first launch — nothing cached */}
    try {
      final rows = await api.list(dateFrom: AppConfig.dataWindowFrom, limit: 200);
      if (!mounted) return;
      store.applyBackendRequisitions(rows);
      _maybePrefillFromHistory();
      // Persist fresh copy for the next offline open.
      try {
        final cache = await RequisitionsStore.open();
        await cache.save(_reqCacheKey, rows);
      } catch (_) {/* best-effort */}
    } on ApiException catch (e) {
      if (!mounted) return;
      // Offline: silent — cached list stays on screen.
      store.setRequisitionsLoading(false,
          error: e.code == ApiErrorCode.networkUnreachable ? null : e.message);
      return;
    } catch (e) {
      if (!mounted) return;
      store.setRequisitionsLoading(false, error: null);
      return;
    }
    store.setRequisitionsLoading(false);
  }

  /// Lazy-load the full lines for a card the user is opening. The list
  /// endpoint only carries aggregates (line_count / requested_total);
  /// lines live on GET /requisitions/{id}. Guard: skip when already loaded.
  Future<void> _ensureLinesLoaded(Requisition r) async {
    if (r.backendId == null || r.items.isNotEmpty) return;
    try {
      final detail = await context.read<RequisitionsApi>().detail(r.backendId!);
      if (!mounted) return;
      final lines = <ReqLine>[
        for (final l in (detail['lines'] as List? ?? const []))
          if (l is Map)
            CounsellorState.reqLineFromBackend(l.cast<String, dynamic>()),
      ];
      context.read<CounsellorState>().replaceRequisitionLines(r.backendId!, lines);
    } catch (_) { /* silent — user can retry via Refresh */ }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Stock Management')),
      Row(children: [_tabBtn('Requisition', 0), const SizedBox(width: 6), _tabBtn('Past', 1), const SizedBox(width: 6), _tabBtn('Overall Status', 2)]),
      const SizedBox(height: 12),
      if (tab == 0) _reqPanel() else if (tab == 1) _pastPanel() else _overallPanel(),
    ]);
  }

  Widget _overallPanel() {
    final reqs = context.watch<CounsellorState>().requisitions;
    final agg = <String, List<int>>{}; // name -> [requested, dispatched, received]
    for (final r in reqs) {
      for (final l in r.items) {
        final a = agg.putIfAbsent(l.name, () => [0, 0, 0]);
        a[0] += l.requested; a[1] += l.dispatched; a[2] += l.received;
      }
    }
    if (agg.isEmpty) return CCard(child: Padding(padding: const EdgeInsets.all(10), child: Center(child: Text('No stock movement yet', style: ct(12, FontWeight.w400, C2.text2)))));
    Widget cell(String t, {bool head = false, int flex = 1, TextAlign align = TextAlign.center}) => Expanded(flex: flex,
        child: Text(t, textAlign: align, style: ct(head ? 10 : 11.5, head ? FontWeight.w700 : FontWeight.w500, head ? Colors.white : C2.text)));
    return CCard(padding: const EdgeInsets.all(8), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), decoration: const BoxDecoration(color: C2.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
        child: Row(children: [
          cell('MEDICINE', head: true, flex: 3, align: TextAlign.left),
          cell('REQ', head: true), cell('DISP', head: true), cell('RECV', head: true),
          // "Total on-hand" — what actually reached the MMU minus what
          // has been dispensed. For now = RECV (dispense per medicine
          // isn't rolled into this endpoint yet; user rule 2026-08-16
          // wanted the column present so pharmacist has one glance
          // number for available stock).
          cell('TOTAL', head: true),
        ])),
      ...agg.entries.map((e) => Container(padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
        child: Builder(builder: (_) {
          final disp = _liveDispensed[e.key] ?? e.value[1];
          final recv = e.value[2];
          // TOTAL = what the row itself shows — RECV minus DISP (user
          // 2026-08-25: 1000 received + 18 dispensed must read 982, not
          // an unrelated server-stock number). Never negative.
          final total = recv - disp < 0 ? 0 : recv - disp;
          return Row(children: [
            Expanded(flex: 3, child: Text(e.key, style: ct(11.5, FontWeight.w600, C2.text))),
            cell('${e.value[0]}'),
            cell('$disp'),
            cell('$recv'),
            Expanded(child: Text('$total',
                textAlign: TextAlign.center,
                style: ct(11.5, FontWeight.w700, C2.navy))),
          ]);
        }))),
    ]));
  }

  Widget _tabBtn(String t, int i) => Expanded(child: InkWell(onTap: () => setState(() => tab = i), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9), alignment: Alignment.center,
        decoration: BoxDecoration(color: tab == i ? C2.cyan : C2.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: tab == i ? C2.cyan : C2.border, width: 1.5)),
        child: Text(t, style: ct(12.5, FontWeight.w600, tab == i ? Colors.white : C2.text2)),
      )));

  Widget _reqPanel() {
    // Absorb any Re-Order prefill produced by the Past tab. Consumed after
    // the frame so setState is safe (the state's notifyListeners triggers
    // this rebuild, and we mustn't call setState synchronously in build).
    final s = context.watch<CounsellorState>();
    if (s.hasReorderTemplate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tpl = s.consumeReorderTemplate();
        if (tpl == null) return;
        setState(() {
          reqItems
            ..clear()
            // Pre-fill ALL past items (user 2026-08-26 — the earlier
            // `.where(!isZonalAdded)` filter was hiding items the
            // Zonal Incharge had approved, so a 2-line requisition
            // showed only 1 on Re-Order). Pharmacist can still remove
            // any line before submitting.
            ..addAll(tpl.items.map((i) {
              // Pre-fill qty with the approved qty (falls back to what
              // was originally requested) so the pharmacist just taps
              // Submit for an identical re-order.
              final prevQty = i.approvedQty > 0 ? i.approvedQty : i.requested;
              final parsed = parseDosage(i.dosage);
              return _Req(
                name: i.name,
                dosage: parsed.strength,
                dosageForm: parsed.form.isNotEmpty ? parsed.form : 'Tab',
                unit: i.unit,
                qty: prevQty > 0 ? prevQty.toString() : '',
              );
            }));
          if (reqItems.isEmpty) reqItems.add(_Req());
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Re-order pre-filled from ${tpl.id}. Enter new quantities.'),
          backgroundColor: C2.navy,
        ));
      });
    }
    return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...reqItems.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CField('Medicine', InkWell(
            onTap: () async { final m = await _pickMed(); if (m != null) setState(() => e.value.name = m); },
            child: InputDecorator(decoration: cInput().copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, color: C2.text2)),
              child: Text(e.value.name ?? 'Select Medicine', overflow: TextOverflow.ellipsis,
                style: ct(13, e.value.name == null ? FontWeight.w400 : FontWeight.w500, e.value.name == null ? C2.text3 : C2.text)))), required: true)),
          if (reqItems.length > 1) IconButton(onPressed: () => setState(() => reqItems.removeAt(e.key)), icon: const Icon(Icons.close, size: 18, color: C2.text2)),
        ]),
        Row(children: [
          // Dosage Form first (user 2026-09-14) — picking Tab vs Syp
          // decides the label + input rules of the Dosage box beside
          // it, so the form belongs upstream in the reading order.
          Expanded(flex: 2, child: CField('Dosage Form', SearchDropdown(
            items: kDosageForms,
            value: kDosageForms.contains(e.value.dosageForm) ? e.value.dosageForm : null,
            onChanged: (v) => setState(() { e.value.dosageForm = v ?? ''; }),
          ), required: true)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: () {
            // Solid forms are counted in mg; syrups / gels / creams are
            // measured by ml, so widen the label + allow decimal input
            // for those (user 2026-09-14).
            final needsQty = dosageFormNeedsQty(e.value.dosageForm);
            return CField(
              needsQty ? 'Dosage (mg)' : 'Dosage (ML)',
              TextField(
                controller: TextEditingController(text: e.value.dosage),
                decoration: cInput(needsQty ? 'e.g. 500' : 'e.g. 100 ml'),
                keyboardType: needsQty
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: needsQty
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ]
                    : [LengthLimitingTextInputFormatter(12)],
                onChanged: (v) => e.value.dosage = v,
              ),
              required: true,
            );
          }()),
          const SizedBox(width: 8),
          // Qty is always asked on a requisition — even for creams /
          // gels / syrups the pharmacist orders N tubes or bottles,
          // not a bare volume (user 2026-09-14).
          Expanded(flex: 1, child: CField('Qty', TextField(
            controller: TextEditingController(text: e.value.qty),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            decoration: cInput(),
            onChanged: (v) => e.value.qty = v,
          ), required: true)),
        ]),
      ]))),
      COutlineButton('Add More', icon: Icons.add_circle_outline, onTap: () => setState(() => reqItems.add(_Req()))),
      const SizedBox(height: 8),
      CPrimaryButton(
        _submittingReq ? 'Submitting…' : 'Submit Requisition',
        icon: _submittingReq ? Icons.hourglass_top : Icons.send,
        onTap: _submittingReq ? null : () => _submitReq(context),
      ),
    ]));
  }

  bool _submittingReq = false;

  Future<void> _submitReq(BuildContext context) async {
    if (_submittingReq) return;
    // Parse qty once per row so validation and construction see the
    // same value. Qty is a piece count for every form — creams / gels
    // / syrups are ordered by tube or bottle, not by bare volume
    // (user 2026-09-14).
    final parsed = reqItems
        .map((r) => (draft: r, qty: int.tryParse(r.qty.trim()) ?? 0))
        .toList();
    final valid = parsed.where((p) => p.draft.name != null && p.qty > 0).toList();
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (valid.isEmpty) return err('Select at least one medicine + qty');
    if (valid.any((p) => p.draft.dosage.trim().isEmpty)) return err('Enter dosage for every medicine');
    setState(() => _submittingReq = true);
    final s = context.read<CounsellorState>();
    final api = context.read<RequisitionsApi>();
    // Same "<form> · <strength>" encoding the doctor uses on Rx
    // items so the requisition list reads back as "Tab · 500" and
    // pharmacist reports can group by form without parsing free
    // text (user 2026-09-14).
    String _fmtDosage(_Req d) {
      final s = d.dosage.trim();
      if (s.isEmpty) return '';
      if (d.dosageForm.isEmpty) return s;
      return '${d.dosageForm}$kDosageFormSep$s';
    }
    final lines = [
      for (final p in valid)
        {
          'medicine_name': p.draft.name,
          'dosage':        _fmtDosage(p.draft),
          'requested_qty': p.qty,
        }
    ];
    try {
      await api.create(lines: lines);
      if (!mounted) return;
      // Blank the form, then immediately re-arm the history prefill so
      // coming back from the Past tab shows a filled form again instead
      // of a single empty row (user 2026-08-21).
      setState(() { reqItems..clear()..add(_Req()); _didPrefill = false; tab = 1; });
      _maybePrefillFromHistory();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Requisition submitted · Awaiting approval'),
        backgroundColor: C2.green,
      ));
      // Refresh in the background so the new row lands with server-
      // assigned id/status without making the user wait for a second
      // round trip (user 2026-09-10: "simple sa requisition send karne
      // ke liye taking too much time").
      unawaited(_loadRequisitions());
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.networkUnreachable) {
        // Offline — save locally so the pharmacist isn't blocked, AND
        // queue the indent so it reaches the server on the next drain
        // (server kind `requisition.create`, added 2026-08-20; before
        // this an offline indent lived and died on the handset).
        context.read<SyncService>().enqueue(
          kind: 'requisition.create',
          payload: {'lines': lines},
        );
        final now = DateTime.now();
        final localId = s.nextRequisitionId(now);
        s.addRequisition(Requisition(
          id: localId,
          date: fmtDate(now),
          status: 'pending_zi',
          items: valid.map((p) => ReqLine(
            name: p.draft.name!, dosage: _fmtDosage(p.draft), unit: p.draft.unit,
            requested: p.qty, status: 'Pending',
          )).toList(),
          audit: [AuditEntry(when: now, actor: 'Pharmacist', action: 'Submitted (offline)')],
        ));
        if (!mounted) return;
        setState(() { reqItems..clear()..add(_Req()); _didPrefill = false; tab = 1; });
        _maybePrefillFromHistory();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Offline — saved locally, will sync when back online'),
          backgroundColor: C2.navy,
        ));
      } else {
        err('Submit failed: ${e.message}');
      }
    } catch (_) {
      err('Submit failed. Try again.');
    } finally {
      if (mounted) setState(() => _submittingReq = false);
    }
  }

  Widget _pastPanel() {
    final s = context.watch<CounsellorState>();
    final reqs = s.requisitions;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Loading strip + retry banner (mirrors the Devices tab pattern).
      if (s.loadingRequisitions)
        const Padding(padding: EdgeInsets.only(bottom: 6),
          child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2))),
      if (s.requisitionsError != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
          onTap: _loadRequisitions,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: C2.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_off, size: 16, color: C2.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(s.requisitionsError!, style: ct(12.5, FontWeight.w600, C2.danger))),
              const Icon(Icons.refresh, size: 16, color: C2.danger),
            ]),
          ),
        )),
      if (reqs.isEmpty && !s.loadingRequisitions)
        CCard(child: Padding(padding: const EdgeInsets.all(10),
          child: Center(child: Text('No requisitions submitted yet',
              style: ct(12, FontWeight.w400, C2.text2)))))
      else
        ...reqs.map((r) {
          final st = _reqStatusStyle(r.status);
          // If lines aren't loaded yet, show the aggregate summary from
          // the list endpoint so the card isn't blank.
          final summary = r.items.isNotEmpty
              ? r.items.map((i) => '${i.name}×${i.requested}').join(', ')
              : (r.backendLineCount != null
                  ? '${r.backendLineCount} medicine${r.backendLineCount == 1 ? '' : 's'} · ${r.backendRequestedTotal ?? 0} qty'
                  : '');
          return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () async {
            // Lazy-load full lines from GET /requisitions/{id} before
            // opening the detail screen — list endpoint only carries
            // aggregates. Silent on failure (detail will just be sparse).
            await _ensureLinesLoaded(r);
            if (!mounted) return;
            // Re-read from state — replaceRequisitionLines rebuilt the row.
            final fresh = context.read<CounsellorState>().requisitions
                .firstWhere((x) => identical(x, r) || x.backendId == r.backendId, orElse: () => r);
            Navigator.push(context, MaterialPageRoute(builder: (_) => _RequisitionDetail(req: fresh)));
          },
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.id}  ·  ${r.date}', style: ct(13, FontWeight.w700, C2.text)),
              const SizedBox(height: 2),
              Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
            CBadge(st.label, bg: st.bg, fg: st.fg),
            const SizedBox(width: 6), const Icon(Icons.chevron_right, color: C2.text3, size: 18),
          ]),
        ),
        // Re-Order is only meaningful for a fully-completed requisition
        // (Zonal Incharge approved + pharma verified). Rule 2026-07-29 — hide it on
        // anything still moving through the workflow.
        if (r.status == 'verified') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              // Re-Order pre-fills the Requisition tab with the past
              // requisition's medicines and switches to that tab so the
              // pharmacist can review/edit quantities before submitting
              // (user 2026-08-26 — reverted from the direct-submit
              // behavior back to the earlier review-first flow).
              onPressed: () {
                context.read<CounsellorState>().setReorderTemplate(r);
                setState(() => tab = 0);
              },
              icon: const Icon(Icons.replay_outlined, size: 16, color: C2.cyan),
              label: Text('Re-Order', style: ct(12, FontWeight.w700, C2.cyan)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: C2.cyanLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ]));
    }),
    ]);
  }

  Future<String?> _pickMed() => showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: C2.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const _MedPicker());
}

/// Requisition detail — four stacked sections (Requested / Approved / Zonal Incharge
/// Added / Received) plus invoice upload + audit trail. The dev-only
/// "Simulate Zonal Incharge Approval" chip stays visible until the JubiCare Dashboard
/// side of the workflow ships and the real Zonal Incharge decision lands here.
class _RequisitionDetail extends StatefulWidget {
  final Requisition req;
  const _RequisitionDetail({required this.req});
  @override
  State<_RequisitionDetail> createState() => _RequisitionDetailState();
}

class _RequisitionDetailState extends State<_RequisitionDetail> {
  Requisition get req => widget.req;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final st = _reqStatusStyle(req.status);

    final canVerify = req.status == 'approved' || req.status == 'partial';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('${req.id} · ${req.date}', style: ct(14, FontWeight.w700, C2.navy)),
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          // Header card — id, date, status, Zonal Incharge remark if present.
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(req.id, style: ct(14, FontWeight.w700, C2.navy))),
              CBadge(st.label, bg: st.bg, fg: st.fg),
            ]),
            const SizedBox(height: 4),
            Text('Raised on ${req.date}', style: ct(11.5, FontWeight.w400, C2.text2)),
            if (req.zonalRemark.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: C2.border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.person_outline, size: 15, color: C2.navy),
                  const SizedBox(width: 6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Zonal Incharge Remark', style: ct(10.5, FontWeight.w700, C2.text2)),
                    const SizedBox(height: 2),
                    Text(req.zonalRemark, style: ct(12, FontWeight.w500, C2.text)),
                  ])),
                ]),
              ),
            ],
            // Approval happens in the web portal (rule 2026-08-05) — the
            // pharmacist can only view and, later, verify what actually
            // arrived. No in-app approval shortcut.
            // Requested medicines + the ZI decision per line live in THIS
            // card now — two-card layout (user 2026-08-21): this one and
            // Received Medicines. Audit trail card removed same day.
            const SizedBox(height: 12),
            Text('Requested Medicines', style: ct(12.5, FontWeight.w700, C2.navy)),
            const SizedBox(height: 2),
            ...[...req.requestedItems, ...req.zonalAddedItems].map(_mergedRow),
          ])),

          // ── Section: Received / verification ─────────
          if (canVerify || req.status == 'verified') ...[
            const SizedBox(height: 12),
            _verificationCard(context, s, editable: canVerify),
          ],
        ]),
      ),
    );
  }

  // ─────────────────────── section builders ────────────────────────

  Widget _sectionCard(String title, {required String subtitle, required List<Widget> rows}) {
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 2),
      Text(subtitle, style: ct(11, FontWeight.w400, C2.text2)),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('—', style: ct(12, FontWeight.w400, C2.text3)))
      else
        ...rows,
    ]));
  }

  Widget _lineRow(ReqLine i, {required bool showApproved}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
      child: Row(children: [
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.name, style: ct(12.5, FontWeight.w700, C2.text)),
          if (i.dosage.isNotEmpty)
            Text(_fmtReqDose(i.dosage), style: ct(10.5, FontWeight.w400, C2.text2)),
        ])),
        Expanded(flex: 2, child: Text('Req ${i.requested}', textAlign: TextAlign.center, style: ct(11.5, FontWeight.w600, C2.text))),
        if (showApproved)
          Expanded(flex: 3, child: Text(
            i.approvedQty < 0 ? '—' : (i.approvedQty == 0 ? 'Rejected' : 'Approved ${i.approvedQty}'),
            textAlign: TextAlign.right,
            style: ct(11.5, FontWeight.w700, i.approvedQty == 0 ? C2.danger : (i.approvedQty > 0 ? C2.green : C2.text3)),
          )),
      ]),
    );
  }

  Widget _approvedRow(ReqLine i) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(i.name, style: ct(12.5, FontWeight.w700, C2.text))),
          Text(
            i.approvedQty <= 0 ? 'Rejected' : 'Approved ${i.approvedQty}',
            style: ct(12, FontWeight.w700, i.approvedQty <= 0 ? C2.danger : C2.green),
          ),
        ]),
        if (i.dosage.isNotEmpty)
          Text(_fmtReqDose(i.dosage), style: ct(10.5, FontWeight.w400, C2.text2)),
        if (i.zonalRemark.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('Note: ${i.zonalRemark}', style: ct(11, FontWeight.w500, C2.text2))),
      ]),
    );
  }

  Widget _verificationCard(BuildContext context, CounsellorState s, {required bool editable}) {
    // Web-portal approvals may not record per-line quantities; when the
    // requisition is approved overall but no line carries a qty, fall back
    // to the requested lines so verification is still possible.
    var rows = req.items.where((l) => l.approvedQty > 0).toList();
    if (rows.isEmpty) rows = req.requestedItems;
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Received Medicines', style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 2),
      Text(editable
          ? 'Confirm quantities on receipt, attach invoice, complete verification.'
          : 'Final received quantities and attached invoice.', style: ct(11, FontWeight.w400, C2.text2)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: const BoxDecoration(color: C2.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
        child: Row(children: [
          Expanded(flex: 4, child: Text('MEDICINE', style: ct(10, FontWeight.w700, Colors.white))),
          Expanded(flex: 2, child: Text('APPROVED', textAlign: TextAlign.center, style: ct(10, FontWeight.w700, Colors.white))),
          Expanded(flex: 3, child: Text('RECEIVED', textAlign: TextAlign.center, style: ct(10, FontWeight.w700, Colors.white))),
        ])),
      ...rows.map((i) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name + (i.isZonalAdded ? '  ★' : ''), style: ct(12, FontWeight.w700, C2.text)),
            if (i.dosage.isNotEmpty)
              Text(_fmtReqDose(i.dosage), style: ct(10.5, FontWeight.w400, C2.text2)),
          ])),
          Expanded(flex: 2, child: Text('${i.approvedQty > 0 ? i.approvedQty : i.requested}', textAlign: TextAlign.center, style: ct(11.5, FontWeight.w700, C2.text))),
          Expanded(flex: 3, child: SizedBox(height: 34, child: TextFormField(
            initialValue: '${i.received}',
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            enabled: editable,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            style: ct(12, FontWeight.w700, C2.text),
            decoration: cInput().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
            onChanged: (v) { i.received = int.tryParse(v) ?? 0; s.updateRequisitions(); },
          ))),
        ]),
      )),
      const SizedBox(height: 10),
      // Invoice attachment. The button flips label + colour once a file is
      // captured so the pharmacist can tell verification is unblocked. On a
      // read-only (verified) requisition it only appears as the green
      // "Invoice attached" badge — a dead upload button there is noise.
      if (editable || req.invoicePath.isNotEmpty)
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: Icon(req.invoicePath.isEmpty ? Icons.upload_file_outlined : Icons.check_circle_outline,
              size: 16, color: req.invoicePath.isEmpty ? C2.navy : C2.green),
          label: Text(
            req.invoicePath.isEmpty ? 'Upload Invoice (PDF/Image)' : 'Invoice attached',
            style: ct(12, FontWeight.w700, req.invoicePath.isEmpty ? C2.navy : C2.green),
          ),
          onPressed: editable ? () async {
            final path = await _pickInvoice();
            if (path == null || !mounted) return;
            setState(() => req.invoicePath = path);
            // Push to the server right away (user 2026-08-21). Offline
            // keeps the local path — Complete Verification's lift still
            // uploads it later, so nothing is lost either way.
            final uploads = context.read<UploadsApi>();
            final messenger = ScaffoldMessenger.of(context);
            try {
              final up = await uploads.uploadImage(path);
              final name = (up['file_name'] ?? '').toString();
              if (name.isNotEmpty && mounted) {
                setState(() => req.invoicePath = name);
              }
              messenger.showSnackBar(const SnackBar(
                content: Text('Invoice uploaded'),
                backgroundColor: C2.green,
              ));
            } on ApiException catch (e) {
              messenger.showSnackBar(SnackBar(
                content: Text(e.code == ApiErrorCode.networkUnreachable
                    ? 'Offline — invoice saved, will upload with verification'
                    : 'Invoice upload failed: ${e.message}'),
                backgroundColor: C2.navy,
              ));
            } catch (_) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Invoice saved — will upload with verification'),
                backgroundColor: C2.navy,
              ));
            }
          } : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 40),
            side: BorderSide(color: req.invoicePath.isEmpty ? C2.navy : C2.green),
          ),
        )),
      ]),
      if (editable) ...[
        const SizedBox(height: 10),
        CPrimaryButton(
          'Complete Verification',
          icon: Icons.verified_outlined,
          onTap: () => _completeVerification(context, s),
        ),
      ],
    ]));
  }

  /// PATCH /requisitions/{id}/receive — the received quantities and the
  /// invoice must reach the server, not just the handset (gap closed
  /// 2026-08-20: verification used to be local-only, so stock never moved).
  /// Online: upload invoice → receive. Offline: enqueue `requisition.receive`
  /// (the drain's photo-lift uploads the invoice before pushing).
  Future<void> _completeVerification(BuildContext context, CounsellorState s) async {
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: C2.danger));
    if (req.invoicePath.isEmpty) {
      return err('Attach the invoice before completing verification');
    }
    if (req.items.every((l) => l.received <= 0)) {
      return err('Enter received quantity for at least one medicine');
    }
    final anyApproved = req.items.any((l) => l.approvedQty > 0);
    final receipts = [
      for (final l in req.items)
        if (l.backendLineId != null &&
            (l.approvedQty > 0 || (!anyApproved && !l.isZonalAdded)))
          {'requisition_line_id': l.backendLineId, 'received_qty': l.received},
    ];
    final backendId = req.backendId;
    // Grab providers before the first await — no context use across gaps.
    final uploadsApi = context.read<UploadsApi>();
    final reqApi = context.read<RequisitionsApi>();
    final sync = context.read<SyncService>();
    var syncedNow = false;
    if (backendId != null && receipts.isNotEmpty) {
      try {
        // Invoice first — the receive payload carries the server-side name.
        var invoiceKey = req.invoicePath;
        if (!invoiceKey.startsWith('http') && File(invoiceKey).existsSync()) {
          final up = await uploadsApi.uploadImage(invoiceKey);
          final name = (up['file_name'] ?? '').toString();
          if (name.isNotEmpty) invoiceKey = name;
        }
        await reqApi.receive(
            backendId, receipts: receipts, invoicePath: invoiceKey);
        syncedNow = true;
      } on ApiException catch (e) {
        if (e.code == ApiErrorCode.networkUnreachable) {
          sync.enqueue(kind: 'requisition.receive', payload: {
            'requisition_id': backendId,
            'receipts': receipts,
            // Local path — lifted to a server name by the drain's photo pass.
            'invoice_path': req.invoicePath,
          });
        } else {
          return err('Could not record the receipt: ${e.message}');
        }
      } catch (_) {
        return err('Could not record the receipt. Try again.');
      }
    }
    if (!mounted) return;
    s.completeVerification(req, invoicePath: req.invoicePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(syncedNow
          ? 'Verification complete — stock updated on server'
          : 'Verification complete — will sync when back online'),
      backgroundColor: C2.green,
    ));
  }

  /// One line of the merged header card: medicine · Req qty · ZI decision.
  /// approvedQty semantics: -1 = no per-line decision recorded (web-portal
  /// approvals often skip per-line qtys) -> show '—', NOT "Rejected"
  /// (display bug fixed 2026-08-21); 0 = rejected; >0 = approved qty.
  Widget _mergedRow(ReqLine i) {
    final pending = req.status == 'pending_zi';
    // Web-portal approvals often record NO per-line quantity (0 / null on
    // every line). When the requisition as a whole is approved and no line
    // carries a positive qty, read each line as approved at its requested
    // qty (user 2026-08-21 — "approved was showing in previous version").
    final overallApproved = req.status == 'approved' ||
        req.status == 'partial' || req.status == 'verified';
    final noLineData = !req.items.any((l) => l.approvedQty > 0);
    Widget decision;
    if (pending) {
      decision = Text('Pending', style: ct(11.5, FontWeight.w600, C2.text3));
    } else if (i.approvedQty > 0) {
      decision = Text('Approved ${i.approvedQty}',
          style: ct(11.5, FontWeight.w700, C2.green));
    } else if (noLineData && overallApproved && !i.isZonalAdded) {
      decision = Text('Approved ${i.requested}',
          style: ct(11.5, FontWeight.w700, C2.green));
    } else if (i.approvedQty == 0 && !noLineData) {
      decision = Text('Rejected', style: ct(11.5, FontWeight.w700, C2.danger));
    } else {
      decision = Text('—', style: ct(11.5, FontWeight.w600, C2.text3));
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C2.border))),
      child: Row(children: [
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.name + (i.isZonalAdded ? '  ★' : ''),
              style: ct(12.5, FontWeight.w700, C2.text)),
          if (i.dosage.isNotEmpty)
            Text(_fmtReqDose(i.dosage), style: ct(10.5, FontWeight.w400, C2.text2)),
          if (i.zonalRemark.isNotEmpty)
            Text('Note: ${i.zonalRemark}', style: ct(10.5, FontWeight.w500, C2.text2)),
        ])),
        Expanded(flex: 2, child: Text(
            i.isZonalAdded ? 'Added' : 'Req ${i.requested}',
            textAlign: TextAlign.center,
            style: ct(11.5, FontWeight.w600, C2.text))),
        Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: decision)),
      ]),
    );
  }

  Widget _auditCard() {
    if (req.audit.isEmpty) return const SizedBox.shrink();
    // Newest at the top so the current state is what the reader sees first.
    final entries = req.audit.reversed.toList();
    String fmtWhen(DateTime d) {
      final date = fmtDate(d);
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$date · $h:$m';
    }
    return CCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Audit Trail', style: ct(13, FontWeight.w700, C2.navy)),
      const SizedBox(height: 8),
      ...entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(color: C2.cyan, shape: BoxShape.circle)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.actor} — ${e.action}', style: ct(12, FontWeight.w700, C2.text)),
            Text(fmtWhen(e.when), style: ct(10.5, FontWeight.w400, C2.text2)),
            if (e.note.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.note, style: ct(11, FontWeight.w500, C2.text2))),
          ])),
        ]),
      )),
    ]));
  }

  /// Invoice capture — image_picker's file/gallery flow. Web builds get a
  /// gallery picker; Android gets both camera and gallery from the same
  /// picker so the pharmacist can shoot a photo of a paper invoice too.
  Future<String?> _pickInvoice() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      return x?.path;
    } catch (_) {
      return null;
    }
  }
}

class _MedPicker extends StatefulWidget {
  const _MedPicker();
  @override
  State<_MedPicker> createState() => _MedPickerState();
}

class _MedPickerState extends State<_MedPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    // Server medicine master first (only names the backend can match);
    // the hardcoded list is just the first-launch offline fallback.
    final serverMeds = context.watch<MastersStore>().medicineNames();
    final options = serverMeds.isNotEmpty ? serverMeds : kMedicineNames;
    final m = options.where((o) => q.isEmpty || o.toLowerCase().contains(q.toLowerCase())).toList();
    return Padding(padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Select Medicine', style: ct(15, FontWeight.w700, C2.navy)), const SizedBox(height: 10),
        TextField(autofocus: true, decoration: cInput('Type to search…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: ListView(shrinkWrap: true,
          children: m.map((o) => ListTile(dense: true, title: Text(o, style: ct(13.5, FontWeight.w500, C2.text)),
            trailing: const Icon(Icons.add, size: 18, color: C2.cyan), onTap: () => Navigator.pop(context, o))).toList())),
      ]));
  }
}

// ───────────────── Pharmacy Report ─────────────────
class PharmaReport extends StatefulWidget {
  const PharmaReport({super.key});
  @override
  State<PharmaReport> createState() => _PharmaReportState();
}

class _PharmaReportState extends State<PharmaReport> {
  String? _kind;    // 'patient' | 'stock'
  String _from = '';
  String _to = '';
  DateTime? _fromDt, _toDt;
  bool _generated = false;

  /// Reverse of `fmtDate` so we can compare a Requisition's stored date
  /// ("24-Jun-2026") with the From/To range chosen by the user.
  DateTime? _parseFmtDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = int.tryParse(parts[0]);
    final monthIdx = months.indexOf(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null || monthIdx < 0) return null;
    return DateTime(year, monthIdx + 1, day);
  }

  Widget _reportCard(String title, String sub, IconData icon, Color color, String kind) => InkWell(
    onTap: () => setState(() { _kind = kind; _generated = false; }),
    child: CCard(child: Row(children: [
      Container(width: 40, height: 40, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: ct(13.5, FontWeight.w700, C2.text)),
        Text(sub, style: ct(11.5, FontWeight.w400, C2.text2)),
      ])),
      if (_kind == kind) const Icon(Icons.check_circle, color: C2.green, size: 18),
    ])),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final dispensed = s.dispensedPatients;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Pharmacy Report')),
      _reportCard('Patient Report', 'Dispensed patients & medicines', Icons.description, C2.cyan, 'patient'),
      _reportCard('Stock Report',   'Requisitions raised, dispatch + receive status', Icons.inventory_2, C2.navy, 'stock'),

      if (_kind != null) ...[
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Select Duration'),
          Row(children: [
            Expanded(child: CField('From', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(),
              onPicked: (d) => setState(() { _fromDt = d; _from = fmtDate(d); })), required: true)),
            const SizedBox(width: 8),
            Expanded(child: CField('To', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(),
              onPicked: (d) => setState(() { _toDt = d; _to = fmtDate(d); })), required: true)),
          ]),
          CPrimaryButton('Generate Report', icon: Icons.assessment, onTap: () {
            if (_from.isEmpty || _to.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select both From and To dates'), backgroundColor: C2.danger));
              return;
            }
            setState(() => _generated = true);
          }),
        ])),
      ],

      if (_generated && _kind == 'patient')
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SecBar('Patient Report · $_from – $_to'),
          Row(children: [
            Expanded(child: StatTile('${s.pharmaQueue.length}', 'Pending', C2.cyan)),
            const SizedBox(width: 8),
            Expanded(child: StatTile('${dispensed.length}', 'Dispensed', C2.green)),
            const SizedBox(width: 8),
            Expanded(child: StatTile('${s.deniedDeliveries.length}', 'Denied', C2.danger)),
          ]),
          const SizedBox(height: 10),
          Text('Dispensed Patients & Medicines', style: ct(12.5, FontWeight.w700, C2.navy)),
          const SizedBox(height: 4),
          if (dispensed.isEmpty) Text('None in this period.', style: ct(12, FontWeight.w400, C2.text2)),
          ...dispensed.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.name} · ${p.age}/${p.gender}', style: ct(12.5, FontWeight.w700, C2.text)),
              if (p.prescription.isEmpty) Text('No medicines', style: ct(11, FontWeight.w400, C2.text2)),
              ...p.prescription.map((m) => Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('• ${_displayNameWithDosage(m)} · ${m.interval} · Qty ${m.dispensedQty}', style: ct(11.5, FontWeight.w400, C2.text2)))),
            ]),
          )),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 160,
            child: CPrimaryButton('Export PDF', icon: Icons.picture_as_pdf, onTap: () => _exportPatientPdf(dispensed, s.deniedDeliveries.length)))),
        ])),

      if (_generated && _kind == 'stock') ...[
        (() {
          // Filter requisitions to the chosen range.
          final inRange = s.requisitions.where((r) {
            final d = _parseFmtDate(r.date);
            if (d == null || _fromDt == null || _toDt == null) return false;
            final t = DateTime(d.year, d.month, d.day);
            final f = DateTime(_fromDt!.year, _fromDt!.month, _fromDt!.day);
            final to = DateTime(_toDt!.year, _toDt!.month, _toDt!.day);
            return !t.isBefore(f) && !t.isAfter(to);
          }).toList();
          int totalReq = 0, totalDisp = 0, totalRec = 0, lineCount = 0;
          for (final r in inRange) {
            for (final l in r.items) {
              totalReq += l.requested;
              totalDisp += (l.dispatched > 0 ? l.dispatched : l.requested);
              totalRec  += l.received;
              lineCount++;
            }
          }
          return CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SecBar('Stock Report · $_from – $_to'),
            // Two balanced tiles instead of three — the old "Received/Req."
            // tile was visibly wider than the single-number ones.
            Row(children: [
              Expanded(child: StatTile('${inRange.length} / $lineCount', 'Requisitions / Lines', C2.cyan)),
              const SizedBox(width: 8),
              Expanded(child: StatTile('$totalRec / $totalReq', 'Received / Req. Qty', C2.green)),
            ]),
            const SizedBox(height: 10),
            Text('Requisitions Raised', style: ct(12.5, FontWeight.w700, C2.navy)),
            const SizedBox(height: 4),
            if (inRange.isEmpty) Text('None in this period.', style: ct(12, FontWeight.w400, C2.text2)),
            ...inRange.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(r.date, style: ct(12.5, FontWeight.w700, C2.text)),
                  CBadge(r.status, bg: C2.navyLight, fg: C2.navy),
                ]),
                ...r.items.map((l) => Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text('• ${l.dosage.isEmpty ? l.name : "${l.name} ${l.dosage}"} · Req ${l.requested} · Disp ${l.dispatched > 0 ? l.dispatched : l.requested} · Rec ${l.received}',
                    style: ct(11.5, FontWeight.w400, C2.text2)))),
              ]),
            )),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: SizedBox(width: 160,
              child: CPrimaryButton('Export PDF', icon: Icons.picture_as_pdf, onTap: () => _exportStockPdf(inRange)))),
          ]));
        })(),
      ],
    ]);
  }

  Future<void> _exportPatientPdf(List<CPatient> dispensed, int denied) async {
    // One row per dispensed medicine: Date, Patient, Diagnosis, Medicine, Dosage, Frequency, Qty.
    String dose(RxItem m) {
      if (m.dosage.trim().isNotEmpty) return m.dosage;
      final (_, d) = splitMedicine(m.name); // derive strength from the name if missing
      return d.isEmpty ? '-' : d;
    }
    final rows = <List<String>>[];
    for (final p in dispensed) {
      final date = p.regDate.isEmpty ? '-' : p.regDate;
      final dx = p.disease.isEmpty ? '-' : p.disease;
      if (p.prescription.isEmpty) {
        rows.add([date, p.name, dx, '—', '—', '—', '—']);
      } else {
        for (final m in p.prescription) {
          rows.add([date, p.name, dx, m.name, dose(m), m.interval, '${m.dispensedQty}']);
        }
      }
    }
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('JubiCare - Pharmacy Patient Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
      pw.Text('Period: ${_from.isEmpty ? "—" : _from} to ${_to.isEmpty ? "—" : _to}'),
      pw.SizedBox(height: 6),
      pw.Text('Dispensed patients: ${dispensed.length}    Denied: $denied'),
      pw.SizedBox(height: 12),
      pw.Text('Dispensed Medicines', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Table.fromTextArray(
        headers: ['Date', 'Patient', 'Diagnosis', 'Medicine', 'Dosage', 'Frequency', 'Qty'],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        columnWidths: {for (var i = 0; i < 7; i++) i: const pw.IntrinsicColumnWidth()},
        data: rows,
      ),
    ]));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_Pharmacy_Patient_Report');
  }

  /// Stock Report PDF — one row per requisition line raised in the picked
  /// range. Mirrors the portal's pharmaStockPDF output.
  Future<void> _exportStockPdf(List<Requisition> reqs) async {
    final rows = <List<String>>[];
    int totalReq = 0, totalDisp = 0, totalRec = 0;
    for (final r in reqs) {
      for (final l in r.items) {
        final disp = l.dispatched > 0 ? l.dispatched : l.requested;
        final lineStatus = l.received >= disp
            ? 'Received'
            : (l.received > 0 ? 'Partial' : 'Pending');
        rows.add([
          r.date,
          l.name,
          l.dosage.isEmpty ? '-' : _fmtReqDose(l.dosage),
          '${l.requested}',
          '$disp',
          '${l.received}',
          lineStatus,
          r.status,
        ]);
        totalReq += l.requested;
        totalDisp += disp;
        totalRec  += l.received;
      }
    }
    if (rows.isNotEmpty) {
      rows.add(['—', 'TOTAL (${rows.length} lines)', '', '$totalReq', '$totalDisp', '$totalRec', '', '']);
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('JubiCare - Pharmacy Stock Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
      pw.Text('Period: ${_from.isEmpty ? "—" : _from} to ${_to.isEmpty ? "—" : _to}'),
      pw.SizedBox(height: 6),
      pw.Text('Requisitions: ${reqs.length}'),
      pw.SizedBox(height: 12),
      pw.Table.fromTextArray(
        headers: ['Date', 'Medicine', 'Dosage', 'Requested', 'Dispatched', 'Received', 'Line Status', 'Req Status'],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        columnWidths: {for (var i = 0; i < 8; i++) i: const pw.IntrinsicColumnWidth()},
        data: rows.isEmpty ? [List.filled(8, '—')] : rows,
      ),
    ]));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_Pharmacy_Stock_Report');
  }
}

// ───────────────── My Attendance (history + mark) ─────────────────
class PharmaAttendance extends StatefulWidget {
  /// Bumped by the shell on refresh while this tab is current.
  final Listenable? refreshSignal;
  const PharmaAttendance({super.key, this.refreshSignal});
  @override
  State<PharmaAttendance> createState() => _PharmaAttendanceState();
}

class _PharmaAttendanceState extends State<PharmaAttendance> {
  bool showForm = false;
  // Blocks a double-tap on Submit Check-In / Check-Out (user 2026-09-02
  // parity fix — a fast second tap could addPharmaAttendance twice
  // before the setState reset cleared the photo/time).
  bool _submitting = false;
  // Mode selector (rule 2026-08-05) — Check-In / Check-Out are mutually
  // exclusive so the pharmacist marks one side at a time.
  String _mode = 'in';
  String _date = '';
  String _checkIn = '';
  String _checkOut = '';
  String? location;
  final _notes = TextEditingController();
  // Selfie + GPS captured for whichever mode is active (rule 2026-08-05).
  // On Check-In this fills photoPath / lat / lng; on Check-Out the same
  // fields ride into photoPathOut / latOut / lngOut so the audit trail
  // has a photo for both ends of the shift.
  String? _photoPath;
  double? _lat;
  double? _lng;

  // Counsellor's mark for the pharmacist today — banner above the form
  // (user rule 2026-08-16 — cross-role attendance visibility).
  String? _counsellorMarkedBy;

  // Camp anchors from /camps/anchors — same source as the counsellor +
  // doctor so the location string matches across roles (ATTEND task B;
  // replaces the hardcoded 3-camp list). Cached per user for offline.
  List<Map<String, dynamic>> _anchors = const [];
  int? _campAnchorId;
  StreamSubscription<void>? _fcmSub;
  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    _minuteTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
    _date = fmtDate(DateTime.now());
    // First back press while the check-in/out form is open closes the
    // form instead of switching tabs (user 2026-08-21).
    BackFormRegistry.register('pharma.attend', () {
      if (!mounted || !showForm) return false;
      // Clear the draft too — reopening must not resurrect stale
      // notes/photo/times (user 2026-08-26, same rule as counsellor).
      _resetAttendForm();
      return true;
    });
    _loadAnchors();
    _hydrateTodayFromBackend();
    _checkCounsellorMark();
    // Live refresh on FCM (user bug 2026-08-18): the counsellor's mark
    // shows up without a re-login.
    _fcmSub = FcmService.instance.onMessageReceived.listen((_) {
      _hydrateTodayFromBackend();
      _checkCounsellorMark();
    });
    widget.refreshSignal?.addListener(_onExternalRefresh);
  }

  /// Blank every draft field of the check-in/out form and close it
  /// (user 2026-08-26 — stale drafts resurfacing on Close/Back/Refresh).
  void _resetAttendForm() {
    setState(() {
      showForm = false; _checkIn = ''; _checkOut = '';
      location = null; _notes.clear();
      _photoPath = null; _lat = null; _lng = null;
    });
  }

  /// Shell-driven refresh (pull / app-bar while this tab is current).
  void _onExternalRefresh() {
    if (!mounted) return;
    if (showForm) _resetAttendForm();
    _loadAnchors();
    _hydrateTodayFromBackend();
    _checkCounsellorMark();
  }

  /// Per-user cache key (rule 2026-08-16 — no cross-user leakage).
  String get _userKey {
    final app = context.read<AppState>();
    return 'pharma_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _loadAnchors() async {
    try {
      final rows = await context.read<CampsApi>().anchors();
      if (!mounted) return;
      setState(() => _anchors = rows.cast<Map<String, dynamic>>());
      unawaited(AttendanceStore.open()
          .then((s) => s.saveAnchors(_userKey, _anchors)));
    } catch (_) {
      try {
        final store = await AttendanceStore.open();
        final cached = store.loadAnchors(_userKey);
        if (cached.isNotEmpty && mounted) {
          setState(() => _anchors = cached);
        }
      } catch (_) {/* facility-name fallback in _autofill */}
    }
  }

  /// Rebuild today's shift after an app restart — server first, offline
  /// snapshot as fallback (user rule 2026-08-18). Without this the
  /// pharmacist's Check-Out stayed locked all day after any relaunch.
  Future<void> _hydrateTodayFromBackend() async {
    Map<String, dynamic>? m;
    var serverAnswered = false;
    try {
      final res = await context.read<AttendanceApi>().today();
      serverAnswered = true;
      final row = res['attendance'];
      if (row is Map) {
        m = row.cast<String, dynamic>();
        // Server-stamped counsellor auto-mark → banner (same as dshell).
        final autoBy = (m['auto_marked_by'] ?? '').toString().trim();
        if (autoBy.isNotEmpty && mounted) {
          setState(() => _counsellorMarkedBy = autoBy);
        }
        unawaited(AttendanceStore.open()
            .then((st) => st.saveToday(_userKey, m)));
      }
    } catch (_) {
      try {
        m = (await AttendanceStore.open()).loadToday(_userKey);
      } catch (_) {/* no cache */}
    }
    // Server explicitly said "no attendance today" → drop the local row
    // so a deleted-from-DB row doesn't linger on the phone (user
    // 2026-08-25). Silent offline still keeps the cached copy.
    if (serverAnswered && m == null && mounted) {
      final today = fmtDate(DateTime.now());
      context.read<CounsellorState>().removePharmaAttendanceOn(today);
      setState(() => _counsellorMarkedBy = null);
      try {
        final st = await AttendanceStore.open();
        await st.saveToday(_userKey, null);
      } catch (_) {}
      return;
    }
    if (m == null || !mounted) return;
    final date    = _fmtServerDate('${m['attendance_date'] ?? ''}');
    final checkIn = _fmtServerTime('${m['check_in'] ?? ''}');
    if (date.isEmpty || checkIn.isEmpty) return;
    final s = context.read<CounsellorState>();
    final serverOut = _fmtServerTime('${m['check_out'] ?? ''}');
    AttendanceRecord? local;
    for (final r in s.pharmaAttendance) {
      if (r.date == date) { local = r; break; }
    }
    if (local != null) {
      // Counsellor may have closed the shift server-side (task C) —
      // mirror it locally without a re-login.
      if (serverOut.isNotEmpty && local.checkOut.isEmpty) {
        s.closePharmaShift(local, local.copyWith(checkOut: serverOut));
      }
    } else {
      s.addPharmaAttendance(AttendanceRecord(
        date:     date,
        checkIn:  checkIn,
        checkOut: serverOut,
        location: '${m['location'] ?? m['anchor_name'] ?? ''}',
        status:   '${m['status'] ?? 'Present'}',
        notes:    '${m['notes'] ?? ''}',
        photoPath: _serverPhotoUrl(m['photo_path']),
        photo:     _serverPhotoUrl(m['photo_path']).isNotEmpty,
        photoPathOut: _serverPhotoUrl(m['photo_path_out']),
        lat:      (m['latitude']  as num?)?.toDouble(),
        lng:      (m['longitude'] as num?)?.toDouble(),
      ));
    }
    if (mounted) setState(() {});
  }

  /// Server photo_path → public URL (same rule as counsellor/doctor).
  static String _serverPhotoUrl(dynamic p) {
    final s = (p ?? '').toString().trim();
    if (s.isEmpty || s.startsWith('http') || s.startsWith('/')) return s;
    return '$kUploadsBase/patient_docs/$s';
  }

  /// '2026-08-13' (or ISO datetime) -> '13-08-2026' (same as doctor).
  static String _fmtServerDate(String v) {
    if (v.length < 10) return '';
    final p = v.substring(0, 10).split('-');
    if (p.length != 3) return '';
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  /// '14:05:00' / ISO datetime -> '2:05 PM'; blank stays blank (open shift).
  static String _fmtServerTime(String v) {
    if (v.isEmpty || v == 'null') return '';
    final t = v.contains('T') ? v.split('T').last : v;
    final p = t.split(':');
    if (p.length < 2) return '';
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h > 23 || m > 59) return '';
    return fmtTime12(TimeOfDay(hour: h, minute: m));
  }

  @override
  void dispose() {
    BackFormRegistry.unregister('pharma.attend');
    _fcmSub?.cancel(); _notes.dispose();
    _minuteTicker?.cancel();
    super.dispose();
  }

  /// Same read as doctor: pull today's attendance rows for this facility,
  /// find any counsellor row whose notes list "Pharmacist" as staff.
  Future<void> _checkCounsellorMark() async {
    try {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final rows = await context.read<AttendanceApi>()
          .list(dateFrom: iso, dateTo: iso, limit: 20);
      for (final r in rows) {
        final rowRole = (r['role'] ?? '').toString().toLowerCase();
        if (rowRole != 'counsellor' && rowRole != 'counselor') continue;
        final notes = (r['notes'] ?? '').toString();
        if (RegExp(r'Staff \((In|Out)\)[^.]*\bPharmacist\b',
                caseSensitive: false).hasMatch(notes)) {
          if (!mounted) return;
          setState(() =>
              _counsellorMarkedBy = (r['full_name'] ?? 'Recipient').toString());
          return;
        }
      }
    } catch (_) { /* silent */ }
  }

  /// Today's open check-in record for the pharmacist (rule 2026-08-05).
  /// Non-null when a check-in without a matching check-out exists — the
  /// only state where Check-Out is allowed.

  /// Any attendance row for today, open OR complete. Distinguishes the
  /// "already checked out" state from "never checked in today" — otherwise
  /// the button falls back to "Mark Check-In" even after the counsellor
  /// closed the shift for you (user bug 2026-08-25).
  AttendanceRecord? _todayPharmaShift(CounsellorState s) {
    for (final r in s.pharmaAttendance) {
      if (r.date == _date && r.checkIn.isNotEmpty) return r;
    }
    return null;
  }

  AttendanceRecord? _openPharmaShift(CounsellorState s) {
    for (final r in s.pharmaAttendance) {
      if (r.date == _date && r.checkIn.isNotEmpty && r.checkOut.isEmpty) {
        return r;
      }
    }
    return null;
  }

  Future<void> _autofill(CounsellorState s) async {
    final now = TimeOfDay.now();
    final open = _openPharmaShift(s);
    setState(() {
      if (_mode == 'in') {
        _checkIn = fmtTime12(now);
      } else {
        _checkOut = fmtTime12(now);
      }
    });
    if (_mode == 'out' && open != null) {
      setState(() => location = open.location);
      return;
    }
    if (location != null) return;
    // Same source + fallback ladder as counsellor/doctor (ATTEND task B):
    // nearest /camps/anchors anchor via GPS, else the facility name.
    final fac = context.read<MastersStore>().facility;
    final facilityName =
        ((fac?['name'] ?? fac?['facility_name']) as String?)?.trim();
    if (_anchors.isEmpty) {
      if (facilityName != null && facilityName.isNotEmpty && mounted) {
        setState(() { location = facilityName; _campAnchorId = null; });
      }
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 6));
      Map<String, dynamic>? nearest;
      double best = double.infinity;
      for (final a in _anchors) {
        final lat = (a['latitude'] as num?)?.toDouble();
        final lng = (a['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
        if (d < best) { best = d; nearest = a; }
      }
      if (nearest != null && mounted) {
        setState(() {
          location = (nearest!['anchor_name'] ?? '').toString();
          _campAnchorId = (nearest['camp_anchor_id'] as num?)?.toInt();
        });
      } else if (facilityName != null && facilityName.isNotEmpty && mounted) {
        setState(() { location = facilityName; _campAnchorId = null; });
      }
    } catch (_) {
      if (facilityName != null && facilityName.isNotEmpty &&
          mounted && location == null) {
        setState(() { location = facilityName; _campAnchorId = null; });
      }
    }
  }

  void _submit(CounsellorState s) {
    if (_submitting) return;
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    final open = _openPharmaShift(s);
    // Guard rule 2026-08-05: Check-Out only if today's Check-In exists.
    if (_mode == 'out' && open == null) {
      return err('Please complete Check-In before Check-Out');
    }
    if (_mode == 'in' && open != null) {
      return err('Check-In already recorded — use Check-Out to close the shift');
    }
    if (_mode == 'in' && _checkIn.isEmpty) return err('Waiting for current time…');
    if (_mode == 'out' && _checkOut.isEmpty) return err('Waiting for current time…');
    if (location == null) return err('Waiting for GPS to pick the nearest camp…');
    if (_photoPath == null) return err('Take a selfie to mark attendance');
    setState(() => _submitting = true);
    if (_mode == 'in') {
      s.addPharmaAttendance(AttendanceRecord(
        date: _date,
        checkIn: _checkIn, checkOut: '',
        location: location!,
        status: 'Present', notes: _notes.text.trim(),
        photo: true, photoPath: _photoPath!, lat: _lat, lng: _lng,
      ));
      context.read<SyncService>().enqueue(kind: 'attendance.check_in', payload: {
        // ISO yyyy-MM-dd — _date is the dd-MM-yyyy DISPLAY string; the
        // server records the payload date, so a queue drained the next
        // morning must still carry the day the shift actually opened.
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_in':        _checkIn,
        'location':        location!,
        'camp_anchor_id':  _campAnchorId,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
        // Local path lifted on next drain (bug 2026-08-20).
        if (_photoPath != null) 'photo_key': _photoPath,
      });
      // Offline snapshot so a restart with no signal still shows the open
      // shift (user rule 2026-08-18).
      unawaited(AttendanceStore.open().then((st) => st.saveToday(_userKey, {
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_in': DateTime.now().toIso8601String(),
        'check_out': null,
        'location': location,
        'status': 'Present',
        'notes': _notes.text.trim(),
      })));
      // D2: 3h/6h/9h check-out reminders until the shift closes.
      unawaited(NotificationsService.instance
          .scheduleCheckoutReminders(checkInLabel: _checkIn));
    } else {
      final closed = open!.copyWith(
        checkOut: _checkOut,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photoPathOut: _photoPath!,
        latOut: _lat, lngOut: _lng,
      );
      s.closePharmaShift(open, closed);
      context.read<SyncService>().enqueue(kind: 'attendance.check_out', payload: {
        // ISO for the server — see check_in note above.
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_out':       _checkOut,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
        // Local path lifted on next drain (bug 2026-08-20).
        if (_photoPath != null) 'photo_key': _photoPath,
      });
      // Fixed 2026-08-20 (mirror of the doctor-shell fix): writing NOW for
      // both check_in and check_out produced a synthetic "already closed"
      // row that the backend hydrate then never overwrote. Keep the real
      // check-in from the open shift and the just-submitted check-out.
      unawaited(AttendanceStore.open().then((st) => st.saveToday(_userKey, {
        'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
        'check_in': open.checkIn,
        'check_out': _checkOut,
        'location': open.location,
        'status': 'Present',
      })));
      // D2: shift closed — stop the pending reminders.
      unawaited(NotificationsService.instance.cancelCheckoutReminders());
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Attendance (${_mode == 'in' ? 'Check-In' : 'Check-Out'}) submitted'),
      backgroundColor: C2.green,
    ));
    setState(() {
      showForm = false; _checkIn = ''; _checkOut = '';
      _date = fmtDate(DateTime.now()); location = null; _notes.clear();
      _photoPath = null; _lat = null; _lng = null;
      _mode = 'in';
      _submitting = false;
    });
  }

  Widget _modeBtn(String key, String label, IconData icon, {bool enabled = true}) {
    final selected = _mode == key;
    return Expanded(child: InkWell(
      onTap: !enabled ? null : () {
        if (_mode == key) return;
        setState(() => _mode = key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autofill(context.read<CounsellorState>());
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled ? C2.bg : (selected ? C2.cyan : C2.white),
          border: Border.all(color: !enabled ? C2.border : (selected ? C2.cyan : C2.border), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(!enabled ? Icons.lock_outline : icon, size: 16,
              color: !enabled ? C2.text3 : (selected ? Colors.white : C2.text2)),
          const SizedBox(width: 6),
          Text(label, style: ct(12.5, FontWeight.w700,
              !enabled ? C2.text3 : (selected ? Colors.white : C2.text2))),
        ]),
      ),
    ));
  }

  Widget _readOnlyPill({required IconData icon, required String value, bool empty = false}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: C2.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C2.border)),
      child: Row(children: [
        Icon(icon, size: 16, color: empty ? C2.text3 : C2.cyan),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
          style: ct(13.5, empty ? FontWeight.w400 : FontWeight.w600, empty ? C2.text3 : C2.text),
          overflow: TextOverflow.ellipsis)),
        Icon(Icons.lock_outline, size: 14, color: C2.text3),
      ]),
    );
  }

  /// Boundary hour (3, 6, 9, …) when the current wall-clock minute is
  /// exactly a 3-hour mark past check-in; else -1. Same behaviour as
  /// counsellor + doctor (user 2026-08-26 "exact time only, no window").
  int _checkoutBoundaryHourFor(AttendanceRecord? open) {
    if (open == null || open.checkIn.isEmpty || open.checkOut.isNotEmpty) {
      return -1;
    }
    final now = DateTime.now();
    DateTime? checkInDt;
    try {
      final parts = open.checkIn.trim().split(RegExp(r'\s+'));
      final hm = parts[0].split(':');
      var h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final period = parts.length > 1 ? parts[1].toUpperCase() : '';
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      checkInDt = DateTime(now.year, now.month, now.day, h, m);
    } catch (_) { return -1; }
    final mins = now.difference(checkInDt).inMinutes;
    if (mins < 180) return -1;
    if ((mins - 180) % 180 != 0) return -1;
    return mins ~/ 60;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final open = _openPharmaShift(s);
    if (open == null && _mode == 'out') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_openPharmaShift(context.read<CounsellorState>()) == null && _mode == 'out') {
          setState(() => _mode = 'in');
        }
      });
    }
    final _bh = _checkoutBoundaryHourFor(open);
    if (_bh > 0 && !showForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        PendingAlert.showOnce(
          context,
          key: 'pharma-checkout-pending-h$_bh',
          title: 'Check-out Pending',
          message: 'You checked in at ${open!.checkIn}. Your check-out '
              'is still pending. Please complete your check-out.',
        );
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Counsellor-marked banner (user rule 2026-08-16).
      if (_counsellorMarkedBy != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: C2.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, size: 16, color: C2.green),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Recipient $_counsellorMarkedBy has marked you present today.',
              style: ct(12.5, FontWeight.w600, C2.green))),
          ]),
        ),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Builder(builder: (_) {
        final today = _todayPharmaShift(s);
        final done = today != null && today.checkOut.isNotEmpty;
        return SecBar('My Attendance',
          trailing: done
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7E0),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, size: 14, color: C2.green),
                    const SizedBox(width: 4),
                    Text('Attendance complete',
                        style: ct(11.5, FontWeight.w700, C2.green)),
                  ]))
              : COutlineButton(
                  showForm ? 'Close' : (open == null ? 'Mark Check-In' : 'Mark Check-Out'),
                  icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
                  onTap: () {
                    final opening = !showForm;
                    if (!opening) {
                      // Close — drop the draft (user 2026-08-26).
                      _resetAttendForm();
                      return;
                    }
                    setState(() {
                      showForm = true;
                      _mode = open == null ? 'in' : 'out';
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _autofill(context.read<CounsellorState>());
                    });
                  }));
      })),
      if (showForm)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SecBar('Mark Attendance'),
          if (open != null)
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text('Closing check-in from ${open.checkIn} · ${open.location}',
                style: ct(11.5, FontWeight.w600, C2.navy))),
          const SizedBox(height: 4),
          Row(children: [
            _modeBtn('in', 'Check-In', Icons.login, enabled: open == null),
            const SizedBox(width: 8),
            _modeBtn('out', 'Check-Out', Icons.logout, enabled: open != null),
          ]),
          CField('Date', InputDecorator(decoration: cInput().copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: C2.cyan)),
            child: Text(_date, style: ct(13.5, FontWeight.w600, C2.text)))),
          if (_mode == 'in')
            CField('Check-in time', _readOnlyPill(
              icon: Icons.access_time,
              value: _checkIn.isEmpty ? 'Fetching current time…' : _checkIn,
              empty: _checkIn.isEmpty,
            ), required: true)
          else
            CField('Check-out time', _readOnlyPill(
              icon: Icons.access_time,
              value: _checkOut.isEmpty ? 'Fetching current time…' : _checkOut,
              empty: _checkOut.isEmpty,
            ), required: true),
          CField('Location', _readOnlyPill(
            icon: Icons.location_on_outlined,
            value: location ?? 'Detecting nearest camp via GPS…',
            empty: location == null,
          ), required: true),
          CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: null, decoration: cInput('Optional — type or use the mic').copyWith(
            suffixIcon: RemarksMicButton(controller: _notes)))),
          // Selfie + GPS proof for whichever mode is active (rule
          // 2026-08-05). Same widget the doctor + counsellor use — the
          // captured photo path + lat/lng ride into photoPath /
          // photoPathOut depending on Check-In vs Check-Out.
          CField('Selfie + Location', AttendanceCapture(
            initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
            // Facility name only — not the camp-anchor / location pill
            // (user 2026-08-31). Empty string if bootstrap has no team.
            placeLabel: ((context.read<MastersStore>().facility?['name']
                       ?? context.read<MastersStore>().facility?['facility_name'])
                     as String?)?.trim()
                ?? '',
            onCaptured: (path, lat, lng) => setState(() { _photoPath = path; _lat = lat; _lng = lng; }),
          ), required: true),
          const SizedBox(height: 4),
          CPrimaryButton(
            _submitting ? 'Submitting…' : (_mode == 'in' ? 'Submit Check-In' : 'Submit Check-Out'),
            icon: _submitting ? Icons.hourglass_top : Icons.check_circle_outline,
            onTap: _submitting ? null : () => _submit(s)),
        ])),
      if (!showForm) ...[
        if (s.pharmaAttendance.isEmpty)
          CCard(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attendance marked yet', style: ct(12, FontWeight.w400, C2.text2)))))
        else
          ...s.pharmaAttendance.map((r) => CCard(
            onTap: () => _showDetail(r),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.event_available, color: C2.cyan)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.date, style: ct(13.5, FontWeight.w700, C2.text)),
                Text('${r.checkIn} – ${r.checkOut} · ${r.location}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              const CBadge('Present', bg: Color(0xFFEDF7E0), fg: C2.green),
            ]))),
      ],
    ]);
  }

  void _showDetail(AttendanceRecord r) => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        // Cap the sheet + scroll so the check-out photo isn't off-screen
        // on small devices (user 2026-08-25).
        isScrollControlled: true,
        builder: (_) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Attendance — ${r.date}', style: ct(15, FontWeight.w700, C2.navy)),
            const SizedBox(height: 10),
            _drow('Date', r.date), _drow('Check-in', r.checkIn), _drow('Check-out', r.checkOut),
            _drow('Location', r.location), _drow('Status', r.status),
            if (r.lat != null && r.lng != null)
              _drow('GPS', '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'),
            if (r.notes.isNotEmpty) _drow('Notes', r.notes),
            if (r.photoPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Check-in photo', style: ct(11.5, FontWeight.w600, C2.text2)),
              const SizedBox(height: 4),
              _attPhoto(r.photoPath, 'Check-in photo'),
            ],
            if (r.photoPathOut.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Check-out photo', style: ct(11.5, FontWeight.w600, C2.text2)),
              const SizedBox(height: 4),
              _attPhoto(r.photoPathOut, 'Check-out photo'),
            ],
          ]))),
        ),
      );

  /// Attendance selfie: server rows carry URLs, own submissions carry
  /// local file paths (same renderer as the doctor sheet).
  /// Tap → fullscreen lightbox (user 2026-08-19).
  Widget _attPhoto(String path, [String? title]) => GestureDetector(
        onTap: () => showPhotoLightbox(context, path, title: title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path.startsWith('http')
              ? Image.network(path, height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))
              : Image.file(File(path), height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3)))),
        ),
      );

  Widget _drow(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}
