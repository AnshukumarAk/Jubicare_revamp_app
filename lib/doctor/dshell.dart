import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../api/attendance_api.dart';
import '../api/auth_api.dart';
import '../api/camps_api.dart';
import '../api/masters_store.dart';
import '../api/queues_api.dart';
import '../api/sync_service.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/screens_dashboard.dart' show kUploadsBase;
import '../counsellor/shell.dart' show SyncStatusIcon, ShellRefreshButton, NotificationsBell;
import '../services/attendance_store.dart';
import '../services/patients_cache_store.dart';
import '../services/connectivity_service.dart';
import '../services/deepgram_stt.dart';
import '../services/fcm_service.dart';
import '../services/terminology_store.dart';
import '../services/notifications_service.dart';
import '../screens/unified_login.dart';
import '../state/app_state.dart';
import '../widgets/pending_alert.dart';
import '../widgets/attendance_capture.dart';
import '../services/back_form_registry.dart';
import '../widgets/photo_lightbox.dart';
import 'dcase.dart';
import 'patient_history.dart';

/// Doctor module shell — 2.0 white header (official logo + profile) and a
/// bottom nav (Home / Case / Report / Attend). Uses the shared CounsellorState.
class DoctorShell extends StatefulWidget {
  final String userName;
  const DoctorShell({super.key, this.userName = 'Dr. Aakanksha'});
  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _tab = 0;
  // Lets the shell poke the dashboard when Home is re-selected or pulled
  // down. Same library, so the private State type is reachable here.
  final _dashboardKey = GlobalKey<_DoctorDashboardState>();
  // Visited-tab history — Android back button walks it backwards so
  // "back" from Attend lands on Home instead of closing the app
  // (user bug 2026-08-16: doctor tap → Attend → back = app closes).
  final List<int> _tabHistory = [0];
  static const _nav = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.medical_services_outlined, 'Case'),
    // Report tab removed 2026-08-05 per user rule.
    (Icons.event_available_outlined, 'Attend'),
  ];
  void _go(int i) {
    if (_tab != i) {
      _tabHistory.remove(i);
      _tabHistory.add(i);
    }
    setState(() => _tab = i);
    // Coming back to Home from Case/Attend is a natural moment to re-check
    // the queue. Throttled inside the dashboard so tab-tapping can't spam it.
    if (i == 0) _dashboardKey.currentState?.refreshOnReturn();
  }

  /// PopScope handler — rewind through visited tabs instead of closing
  /// the app (same pattern as counsellor shell). Returns true if the
  /// back gesture was absorbed.
  bool _handleBack() {
    // Open check-in/out form on the Attend tab eats the first back press
    // (user 2026-08-21 — back must show the attend list, not the last tab).
    if (_tab == 2 && BackFormRegistry.close('doc.attend')) return true;
    if (_tabHistory.length <= 1) return false; // let system close the app
    _tabHistory.removeLast();
    setState(() => _tab = _tabHistory.last);
    return true;
  }

  final _attendRefresh = ValueNotifier(0);

  /// One refresh path for the app-bar button AND pull-to-refresh: online
  /// check first, then the CURRENT tab's server data. The offline sync
  /// queue is never touched (user rule 2026-08-21).
  Future<void> _refreshCurrentTab() async {
    if (!mounted || !context.read<ConnectivityService>().isOnline) return;
    // Masters + terminology also refresh on the app-bar/pull refresh so
    // any new medicine, symptom, block/village or clinical-sheet update
    // reaches the app without a re-login (user 2026-08-25).
    unawaited(context.read<MastersStore>().refresh());
    unawaited(context.read<TerminologyStore>().refresh());
    if (_tab == 2) {
      _attendRefresh.value++;
    } else {
      await _dashboardKey.currentState?.refreshNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.replaceAll('Dr. ', '').isEmpty ? 'D' : widget.userName.replaceAll('Dr. ', '')[0].toUpperCase();
    final pages = [
      DoctorDashboard(key: _dashboardKey, name: widget.userName,
          active: _tab == 0, onOpenCase: () => _go(1)),
      const DoctorCaseList(),
      // DoctorReport removed 2026-08-05 per user rule.
      DoctorAttendance(refreshSignal: _attendRefresh),
    ];
    const pad = EdgeInsets.fromLTRB(14, 14, 14, 24);
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
          DocHeader(initials: initials, userName: widget.userName, role: 'Doctor',
            // Doctor's data lives on DoctorDashboard's state — expose its
            // refreshNow via the GlobalKey we already hold.
            onRefresh: _refreshCurrentTab),
          Expanded(child: IndexedStack(index: _tab, children: [
            // Home gets pull-to-refresh: the counsellor registers on a
            // different handset, so nothing on this device can know a new
            // patient exists until we ask. AlwaysScrollable so the gesture
            // works even when the queue is short enough not to overflow.
            for (final p in pages)
              RefreshIndicator(
                onRefresh: _refreshCurrentTab,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: pad,
                  child: p),
              ),
          ])),
        ]),
        bottomNavigationBar: DocBottomNav(items: _nav, current: _tab, onTap: _go),
      ),
      ),
    );
  }
}

/// Shared 2.0 header (logo + bell + profile avatar) reused by doctor/pharmacist.
class DocHeader extends StatelessWidget {
  final String initials, userName, role;
  /// Optional refresh callback — when provided, the app bar shows a
  /// refresh icon that re-pulls the shell's data. Doctor + pharmacist
  /// shells wire their own (user rule 2026-08-16: manual refresh in
  /// every app bar so internet drops don't force an app restart).
  final Future<void> Function()? onRefresh;
  const DocHeader({super.key, required this.initials, required this.userName, required this.role, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C2.white,
        border: Border(bottom: BorderSide(color: C2.cyan, width: 3)),
        boxShadow: [BoxShadow(color: Color(0x12003087), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Image.asset('assets/jubicare_logo.png', height: 30, fit: BoxFit.contain),
              const Spacer(),
              // Sync status icon (same as counsellor shell — user rule
              // 2026-08-14: sync UI belongs in the app bar, not the body).
              const SyncStatusIcon(),
              const SizedBox(width: 10),
              if (onRefresh != null) ...[
                ShellRefreshButton(onRefresh: onRefresh!),
                const SizedBox(width: 10),
              ],
              const NotificationsBell(),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _menu(context),
                child: Container(
                  width: 32, height: 32, alignment: Alignment.center,
                  decoration: const BoxDecoration(gradient: C2.headerGrad, shape: BoxShape.circle),
                  child: Text(initials, style: ct(12, FontWeight.w700, Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _menu(BuildContext context) => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.person_outline, color: C2.cyan),
              title: Text('My Profile', style: ct(14, FontWeight.w600, C2.text)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => SimpleProfile(name: userName, role: role))); }),
            ListTile(leading: const Icon(Icons.logout, color: C2.navy),
              title: Text('Logout', style: ct(14, FontWeight.w600, C2.text)),
              onTap: () async {
                Navigator.pop(context);
                if (!await confirmLogout(context)) return;
                if (!context.mounted) return;
                // Best-effort backend logout (v2 §1.3).
                unawaited(context.read<AuthApi>().logout().catchError((_) {}));
                // Kill FCM so pushes stop coming for the old user
                // (bug 2026-08-20).
                unawaited(FcmService.instance
                    .unregister(context.read<ApiClient>())
                    .catchError((_) {}));
                // Wipe user-scoped lists (user rule 2026-08-16).
                context.read<CounsellorState>().resetForNewUser();
                context.read<AppState>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                  (route) => false,
                );
              }),
          ])),
        ),
      );
}

class DocBottomNav extends StatelessWidget {
  final List<(IconData, String)> items;
  final int current;
  final ValueChanged<int> onTap;
  const DocBottomNav({super.key, required this.items, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C2.white,
        border: Border(top: BorderSide(color: C2.border, width: 1.5)),
        boxShadow: [BoxShadow(color: Color(0x0F003087), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: List.generate(items.length, (i) {
          final col = i == current ? C2.cyan : C2.text3;
          return Expanded(child: InkWell(onTap: () => onTap(i), child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i].$1, size: 19, color: col), const SizedBox(height: 2),
              Text(items[i].$2, style: ct(9.5, FontWeight.w600, col)),
            ]),
          )));
        })),
      )),
    );
  }
}

// ───────────────── Dashboard ─────────────────
class DoctorDashboard extends StatefulWidget {
  final String name;
  final VoidCallback onOpenCase;
  /// Whether Home is the visible tab. IndexedStack keeps every page mounted,
  /// so the background poll has to be told when it is off screen.
  final bool active;
  const DoctorDashboard({super.key, required this.name, required this.onOpenCase, this.active = true});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with WidgetsBindingObserver {
  bool _refreshing = false;
  String? _lastError;
  SyncService? _sync;
  int _lastDrainSignature = -1;
  Timer? _poll;
  DateTime? _lastFetchAt;

  /// Background poll cadence while Home is on screen.
  ///
  /// _onSyncTick only fires for pushes made *on this handset*, and in an MMU
  /// the counsellor is on a different phone — so a newly registered patient
  /// was invisible here until the app was restarted. Until the backend can
  /// push, asking on a timer is what keeps the queue current.
  static const _pollEvery = Duration(seconds: 30);

  /// Floor between automatic fetches, so a resume landing next to a tab
  /// switch and a timer tick don't fire three round-trips back to back.
  /// Pull-to-refresh bypasses this — that one is the doctor asking directly.
  static const _minGap = Duration(seconds: 10);

  StreamSubscription<void>? _fcmDashSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydratePatientsFromCache();
      _refreshFromBackend(immediate: true);
    });
    // Cross-device wake-up (user 2026-08-22): the counsellor's register
    // fires an FCM push from the server — re-pull the queue immediately
    // instead of waiting for the 30 s poll.
    _fcmDashSub = FcmService.instance.onMessageReceived.listen((_) {
      if (mounted) _refreshFromBackend();
    });
    _poll = Timer.periodic(_pollEvery, (_) {
      // Quiet unless Home is actually showing, the app is foregrounded and
      // there's a network — no point burning field data in someone's pocket.
      if (!mounted || !widget.active) return;
      if (!context.read<ConnectivityService>().isOnline) return;
      _refreshFromBackend();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The phone was locked or the app backgrounded while the counsellor
    // registered someone — the commonest way this queue goes stale.
    if (state == AppLifecycleState.resumed) _refreshFromBackend();
  }

  /// Pull-to-refresh from the shell. Always fetches.
  Future<void> refreshNow() => _refreshFromBackend(immediate: true);

  /// Home tab re-selected. Throttled — tapping between tabs shouldn't hammer
  /// the API.
  void refreshOnReturn() => _refreshFromBackend();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to SyncService — every time the counsellor's push drains
    // we re-pull the doctor queue so a just-registered patient shows
    // up without a manual refresh.
    final s = context.read<SyncService>();
    if (!identical(_sync, s)) {
      _sync?.removeListener(_onSyncTick);
      _sync = s..addListener(_onSyncTick);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _fcmDashSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sync?.removeListener(_onSyncTick);
    super.dispose();
  }

  void _onSyncTick() {
    // Only refetch when a drain actually landed something new (or
    // rejected something). Avoids a refresh loop when the queue is
    // idle.
    final sig = (_sync?.lastApplied ?? 0) * 100000 + (_sync?.lastRejected ?? 0) * 100 + (_sync?.lastFailed ?? 0);
    if (sig != _lastDrainSignature && (_sync?.lastDrainAt != null)) {
      _lastDrainSignature = sig;
      _refreshFromBackend();
    }
  }

  String get _doctorCacheKey {
    final app = context.read<AppState>();
    return 'doctor_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _hydratePatientsFromCache() async {
    try {
      final store = await PatientsCacheStore.open();
      final rows = store.load(_doctorCacheKey);
      if (rows.isEmpty || !mounted) return;
      context.read<CounsellorState>().mergeBackendPatients(rows);
    } catch (_) {/* first run — nothing cached yet */}
  }

  Future<void> _refreshFromBackend({bool immediate = false}) async {
    if (_refreshing || !mounted) return;
    final last = _lastFetchAt;
    if (!immediate && last != null && DateTime.now().difference(last) < _minGap) {
      return;
    }
    _lastFetchAt = DateTime.now();
    setState(() { _refreshing = true; _lastError = null; });
    try {
      final api = context.read<QueuesApi>();
      // Silent-on-failure (user 2026-08-26: banner didn't clear even
      // after server came back). Cached list stays on screen; retry is
      // one tap away. Primary queue failure returns early — banner was
      // already cleared at start.
      QueueList queue;
      try {
        queue = await api.doctorQueue(limit: 200);
      } catch (_) {
        return;
      }
      Future<QueueList> safe(Future<QueueList> f) =>
          f.catchError((_) => QueueList(items: const [], total: 0, count: 0));
      final results = await Future.wait([
        safe(api.doctorAttended(limit: 200)),
        safe(api.pendingPayment(limit: 200)),
        safe(api.labQueue(limit: 200)),
      ]);
      if (!mounted) return;
      final store = context.read<CounsellorState>();
      final combined = [
        ...queue.items,
        for (final r in results) ...r.items,
      ];
      store.mergeBackendPatients(combined);
      try {
        final cache = await PatientsCacheStore.open();
        await cache.save(_doctorCacheKey, combined);
      } catch (_) {/* best-effort */}
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final name = widget.name;
    final initials = name.replaceAll('Dr. ', '').isEmpty ? 'D' : name.replaceAll('Dr. ', '')[0].toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradGreeting(name: name, sub: 'Doctor Dashboard', initials: initials),
      // API-refresh status strip — thin bar while /api/queues/doctor
      // is being pulled, or a red banner if it failed.
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
            DoctorPatientList(title: 'In Queue', patients: s.doctorQueue))),
          child: StatTile('${s.doctorQueue.length}', 'In Queue', C2.cyan))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            DoctorPatientList(title: 'Completed', patients: s.doctorAttended))),
          child: StatTile('${s.doctorCompleted}', 'Completed', C2.green))),
        const SizedBox(width: 8),
        Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            DoctorPatientList(title: 'All Patients · Past 7 Days', patients: s.doctorPast7Days))),
          child: StatTile('${s.doctorPast7Days.length}', 'Past 7 Days', C2.navy))),
      ]),
      const SizedBox(height: 14),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Patient Queue'),
        if (s.doctorQueue.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('No patients in queue', style: ct(12, FontWeight.w400, C2.text2))))
        else
          ...s.doctorQueue.take(5).map((p) => QueueRow(p: p, sub: '${p.age}y · ${p.symptoms.take(2).join(', ')}',
            badge: p.status == 'registered' ? 'Waiting' : 'In Progress',
            badgeBg: p.status == 'registered' ? const Color(0xFFFEF7E0) : C2.cyanLight,
            badgeFg: p.status == 'registered' ? const Color(0xFFB8860B) : C2.cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorCaseDetails(patient: p))))),
        if (s.doctorQueue.length > 5)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing 5 of ${s.doctorQueue.length} · tap "In Queue" to view all', style: ct(11, FontWeight.w500, C2.text2))),
      ])),
      // Attended (view-only)
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecBar('Attended Patients'),
        if (s.doctorAttended.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attended patients yet', style: ct(12, FontWeight.w400, C2.text2))))
        else ...[
          ...s.doctorAttended.take(5).map((p) => InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => PatientHistoryScreen(patient: p))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                  // Queue rows carry no Rx lines, only their count — local
                  // p.prescription is always empty for server-merged rows,
                  // which is why every card said "0 meds" (user 2026-08-22).
                  Text('${p.disease.isEmpty ? "—" : p.disease} · ${p.prescription.isNotEmpty ? p.prescription.length : p.medicineCount} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                ])),
                doctorStatusBadge(p.status),
                const SizedBox(width: 6), const Icon(Icons.lock_outline, size: 15, color: C2.text3),
              ]),
            ))),
          if (s.doctorAttended.length > 5)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing 5 of ${s.doctorAttended.length} · tap "Completed" to view all', style: ct(11, FontWeight.w500, C2.text2))),
        ],
      ])),
    ]);
  }
}

/// CR26: Doctor Home → searchable list of patients (In Queue / Completed).
/// Tapping a patient opens basic details (same as counsellor screens).
class DoctorPatientList extends StatefulWidget {
  final String title;
  final List<CPatient> patients;
  const DoctorPatientList({super.key, required this.title, required this.patients});
  @override
  State<DoctorPatientList> createState() => _DoctorPatientListState();
}

class _DoctorPatientListState extends State<DoctorPatientList> {
  String _q = '';

  /// Open the screen that matches the patient's stage.
  ///
  /// Mirrors how the dashboard's own cards route: a case still waiting on the
  /// doctor opens the editable Case Details, a finished one opens the
  /// read-only summary. This list is shared by the In Queue / Completed /
  /// Past 7 Days tiles and used to send every row to the counsellor's
  /// read-only screen, so tapping a queued patient here gave the doctor no
  /// way to actually record the consultation.
  void _openPatient(BuildContext context, CPatient p) {
    final awaitingDoctor = p.status == 'registered' || p.status == 'with_doctor';
    if (awaitingDoctor) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DoctorCaseDetails(patient: p)));
    } else {
      // Finished case → the full record. The old bottom sheet only rendered
      // whatever the in-memory CPatient happened to hold, which for a backend
      // row is a single visit with most fields blank.
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PatientHistoryScreen(patient: p)));
    }
  }
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.patients
        : widget.patients.where((p) => p.name.toLowerCase().contains(q) || p.uniqueCode.toLowerCase().contains(q)).toList();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('${widget.title} (${widget.patients.length})', style: ct(16, FontWeight.w700, C2.navy))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              decoration: cInput('Search by name or unique code…').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
              onChanged: (v) => setState(() => _q = v))),
          Expanded(child: list.isEmpty
            ? Center(child: Text(q.isEmpty ? 'No patients' : 'No patient matches "$_q"', style: ct(13, FontWeight.w400, C2.text2)))
            : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), children: [
                CCard(child: Column(children: list.map((p) => InkWell(
                  onTap: () => _openPatient(context, p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                        const SizedBox(height: 1),
                        Text(p.symptoms.isEmpty ? '${p.age}y · —' : '${p.age}y · ${p.symptoms.join(', ')}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: ct(11.5, FontWeight.w400, C2.text2)),
                      ])),
                      _statusBadge(p.status),
                    ]),
                  ))).toList())),
              ])),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) => doctorStatusBadge(status);
}

/// Badge for a case's position on the status ladder (§6.2). Shared by the
/// dashboard cards and the drill-down list so a patient never reads as two
/// different things on two screens.
Widget doctorStatusBadge(String status) {
  final (label, bg, fg) = switch (status) {
    'completed'       => ('Completed', const Color(0xFFEDF7E0), C2.green),
    'with_pharma'     => ('At Pharmacy', C2.cyanLight, C2.cyan),
    // Post-consultation rungs: the doctor is done, the case is moving on.
    'with_counsellor' => ('Awaiting Test Payment', const Color(0xFFFEF7E0), const Color(0xFFB8860B)),
    'with_lab'        => ('At Lab', C2.cyanLight, C2.cyan),
    'with_doctor'     => ('In Progress', C2.cyanLight, C2.cyan),
    _                 => ('Waiting', const Color(0xFFFEF7E0), const Color(0xFFB8860B)),
  };
  return CBadge(label, bg: bg, fg: fg);
}

class QueueRow extends StatelessWidget {
  final CPatient p;
  final String sub, badge;
  final Color badgeBg, badgeFg;
  final VoidCallback onTap;
  const QueueRow({super.key, required this.p, required this.sub, required this.badge, required this.badgeBg, required this.badgeFg, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
              const SizedBox(height: 1),
              Text(sub, style: ct(11.5, FontWeight.w400, C2.text2)),
            ])),
            CBadge(badge, bg: badgeBg, fg: badgeFg),
          ]),
        ),
      );
}

// Case tab → searchable list of queue patients to pick
class DoctorCaseList extends StatefulWidget {
  const DoctorCaseList({super.key});
  @override
  State<DoctorCaseList> createState() => _DoctorCaseListState();
}

class _DoctorCaseListState extends State<DoctorCaseList> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty ? s.doctorQueue : s.doctorQueue.where((p) => p.name.toLowerCase().contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Select Patient')),
      TextField(
        decoration: cInput('Search patient by name…').copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: C2.navy)),
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: 10),
      if (list.isEmpty)
        CCard(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: Text(q.isEmpty ? 'No patients in queue' : 'No patient matches "$_q"', style: ct(12, FontWeight.w400, C2.text2)))))
      else
        CCard(child: Column(children: list.map((p) => QueueRow(p: p, sub: '${p.gender}, ${p.age}y · ${p.village}',
          badge: p.status == 'registered' ? 'Waiting' : 'In Progress',
          badgeBg: p.status == 'registered' ? const Color(0xFFFEF7E0) : C2.cyanLight,
          badgeFg: p.status == 'registered' ? const Color(0xFFB8860B) : C2.cyan,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorCaseDetails(patient: p))))).toList())),
    ]);
  }
}

// ───────────────── Attendance / Report / Profile (shared simple) ─────────────────
class DoctorAttendance extends StatefulWidget {
  /// Bumped by the shell when the user refreshes (pull / app-bar) while
  /// this tab is current — re-pulls server data; never touches the queue.
  final Listenable? refreshSignal;
  const DoctorAttendance({super.key, this.refreshSignal});
  @override
  State<DoctorAttendance> createState() => _DoctorAttendanceState();
}

class _DoctorAttendanceState extends State<DoctorAttendance> {
  bool showForm = false;
  // Attendance mode (rule 2026-08-05): Check-In and Check-Out are mutually
  // exclusive so the doctor can only mark one side at a time.
  String _mode = 'in';   // 'in' | 'out'
  String _date = '';
  String _checkIn = '';
  String _checkOut = '';
  String? location;
  final _notes = TextEditingController();
  String? _photoPath;
  double? _lat;
  double? _lng;
  // Counsellor's mark for this doctor today — surfaced as a banner so
  // the doctor knows their presence has already been logged upstream
  // (user rule 2026-08-16). Set from _checkCounsellorMark().
  String? _counsellorMarkedBy;
  // Camp anchors from /camps/anchors — the SAME source the counsellor
  // uses, so the location string matches across roles (ATTEND task B;
  // replaces the old hardcoded 3-camp list that showed "Gajraula Camp"
  // everywhere). Cached per user so GPS snap works offline too.
  List<Map<String, dynamic>> _anchors = const [];
  int? _campAnchorId;
  StreamSubscription<void>? _fcmSub;
  // 60-second ticker so the checkout-boundary popup can fire on the
  // exact minute (user 2026-08-26 — same fix as counsellor).
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
    BackFormRegistry.register('doc.attend', () {
      if (!mounted || !showForm) return false;
      // Clear the draft too — reopening must not resurrect stale
      // notes/photo/times (user 2026-08-26, same rule as counsellor).
      _resetAttendForm();
      return true;
    });
    _loadAnchors();
    _hydrateTodayFromBackend();
    _checkCounsellorMark();
    // Live refresh: the counsellor's mark pushes an FCM message — pull the
    // fresh row immediately so the doctor sees it WITHOUT re-login
    // (user bug 2026-08-18).
    _fcmSub = FcmService.instance.onMessageReceived.listen((_) {
      _hydrateTodayFromBackend();
      _checkCounsellorMark();
    });
    widget.refreshSignal?.addListener(_onExternalRefresh);
  }

  /// Blank every draft field of the check-in/out form and close it.
  /// Reopening starts pristine (user 2026-08-26 — stale drafts were
  /// resurfacing on Close/Back/Refresh across all roles).
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
    return 'doctor_${app.backendUserId ?? app.currentUser}';
  }

  /// Anchors: server first, offline cache as fallback (user rule
  /// 2026-08-18 — attendance fully functional offline).
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
      } catch (_) {/* no cache — facility-name fallback in _autofill */}
    }
  }

  /// GET /api/attendance for today at this facility. Parses each row's
  /// notes field for the counsellor-written "Staff (In): …" string and
  /// records their name when this role's word ("Doctor") is listed.
  /// Silent on error — banner just doesn't show.
  Future<void> _checkCounsellorMark({String role = 'Doctor'}) async {
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
        if (RegExp(r'Staff \((In|Out)\)[^.]*\b' + role + r'\b',
                caseSensitive: false).hasMatch(notes)) {
          if (!mounted) return;
          setState(() =>
              _counsellorMarkedBy = (r['full_name'] ?? 'Counsellor').toString());
          return;
        }
      }
    } catch (_) { /* offline / not deployed — banner stays hidden */ }
  }

  @override
  void dispose() {
    BackFormRegistry.unregister('doc.attend');
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    _fcmSub?.cancel(); _notes.dispose();
    _minuteTicker?.cancel();
    super.dispose();
  }

  /// Boundary hour (3, 6, 9, …) when the current wall-clock minute is
  /// exactly a 3-hour mark past check-in; else -1. Same shape as the
  /// counsellor's helper (user 2026-08-26).
  int _checkoutBoundaryHourFor(AttendanceRecord? open) {
    if (open == null || open.checkIn.isEmpty || open.checkOut.isNotEmpty) {
      return -1;
    }
    // AttendanceRecord.checkIn is a "hh:mm AM/PM" label; combine with
    // today's date to get an instant.
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

  /// Server photo_path is a bare filename in the shared uploads folder —
  /// expand to a public URL (same rule as the counsellor screen). Local
  /// device paths / full URLs pass through untouched.
  static String _serverPhotoUrl(dynamic p) {
    final s = (p ?? '').toString().trim();
    if (s.isEmpty || s.startsWith('http') || s.startsWith('/')) return s;
    return '$kUploadsBase/patient_docs/$s';
  }

  /// Rebuild today's shift from the server so Check-Out survives a restart.
  ///
  /// `doctorAttendance` is in-memory only — a relaunch (or a hot restart)
  /// empties it, so `_openDoctorShift` returns null and Check-Out stays
  /// disabled all day even though the morning's Check-In is safely on the
  /// server. GET /api/attendance/today is the authority on whether this
  /// user has an open shift, so ask it before deciding what the form allows.
  Future<void> _hydrateTodayFromBackend() async {
    try {
      final res = await context.read<AttendanceApi>().today();
      final row = res['attendance'];
      // Server says "no attendance for today" — reflect that locally.
      // Before this the app kept a deleted row on screen until re-login
      // (user 2026-08-25: admin deleted the row, refresh didn't clean).
      if (row is! Map) {
        if (mounted) {
          final today = fmtDate(DateTime.now());
          context.read<CounsellorState>().removeDoctorAttendanceOn(today);
          setState(() => _counsellorMarkedBy = null);
        }
        try {
          final st = await AttendanceStore.open();
          await st.saveToday(_userKey, null);
        } catch (_) {}
        return;
      }
      final m = row.cast<String, dynamic>();
      // The server stamps who auto-marked this row (counsellor's crew
      // tick) — authoritative source for the "marked you present" banner.
      final autoBy = (m['auto_marked_by'] ?? '').toString().trim();
      if (autoBy.isNotEmpty && mounted) {
        setState(() => _counsellorMarkedBy = autoBy);
      }
      final date    = _fmtServerDate('${m['attendance_date'] ?? ''}');
      final checkIn = _fmtServerTime('${m['check_in'] ?? ''}');
      // No usable check-in means there is nothing to reopen.
      if (date.isEmpty || checkIn.isEmpty) return;
      if (!mounted) return;
      final s = context.read<CounsellorState>();
      final serverOut = _fmtServerTime('${m['check_out'] ?? ''}');
      AttendanceRecord? local;
      for (final r in s.doctorAttendance) {
        if (r.date == date) { local = r; break; }
      }
      if (local != null) {
        // Already shown — but the counsellor may have CLOSED the shift on
        // the server (auto check-out, task C). Mirror that locally so the
        // form flips back to Check-In-done state without a re-login.
        if (serverOut.isNotEmpty && local.checkOut.isEmpty) {
          s.closeDoctorShift(local, local.copyWith(checkOut: serverOut));
        }
      } else {
        s.addDoctorAttendance(AttendanceRecord(
          date:      date,
          checkIn:   checkIn,
          checkOut:  serverOut,
          location:  '${m['location'] ?? m['anchor_name'] ?? ''}',
          status:    '${m['status'] ?? 'Present'}',
          notes:     '${m['notes'] ?? ''}',
          photoPath: _serverPhotoUrl(m['photo_path']),
          photo:     _serverPhotoUrl(m['photo_path']).isNotEmpty,
          photoPathOut: _serverPhotoUrl(m['photo_path_out']),
          lat:       (m['latitude']  as num?)?.toDouble(),
          lng:       (m['longitude'] as num?)?.toDouble(),
        ));
      }
      if (mounted) setState(() {});
      // Fresh server truth → refresh the offline snapshot.
      unawaited(AttendanceStore.open()
          .then((st) => st.saveToday(_userKey, m)));
    } catch (_) {
      // Offline, or the endpoint isn't deployed — try the cached snapshot
      // so a restart with no signal still shows the open shift and gates
      // Check-Out correctly (user rule 2026-08-18).
      try {
        final store = await AttendanceStore.open();
        final m = store.loadToday(_userKey);
        if (m == null || !mounted) return;
        final date    = _fmtServerDate('${m['attendance_date'] ?? ''}');
        final checkIn = _fmtServerTime('${m['check_in'] ?? ''}');
        if (date.isEmpty || checkIn.isEmpty) return;
        final s = context.read<CounsellorState>();
        if (s.doctorAttendance.any((r) => r.date == date)) return;
        s.addDoctorAttendance(AttendanceRecord(
          date:     date,
          checkIn:  checkIn,
          checkOut: _fmtServerTime('${m['check_out'] ?? ''}'),
          location: '${m['location'] ?? m['anchor_name'] ?? ''}',
          status:   '${m['status'] ?? 'Present'}',
          notes:    '${m['notes'] ?? ''}',
        ));
        if (mounted) setState(() {});
      } catch (_) {/* no cache — local state stands */}
    }
  }

  /// '2026-08-13' (or an ISO datetime) -> '13-08-2026', matching [fmtDate].
  static String _fmtServerDate(String v) {
    if (v.length < 10) return '';
    final p = v.substring(0, 10).split('-');
    if (p.length != 3) return '';
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  /// '14:05:00' (or an ISO datetime) -> '2:05 PM'. Blank/null stays blank,
  /// which is what marks a shift as still open.
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

  /// Today's open check-in record for the doctor (rule 2026-08-05).
  /// Non-null when a check-in without a matching check-out exists — that's
  /// the only shape where Check-Out is allowed. Non-open records (already
  /// closed) or absence of today's check-in return null.

  /// Any attendance row for today, open OR complete (user bug 2026-08-25:
  /// after counsellor's auto-close the button fell back to Mark Check-In).
  AttendanceRecord? _todayDoctorShift(CounsellorState s) {
    for (final r in s.doctorAttendance) {
      if (r.date == _date && r.checkIn.isNotEmpty) return r;
    }
    return null;
  }

  AttendanceRecord? _openDoctorShift(CounsellorState s) {
    for (final r in s.doctorAttendance) {
      if (r.date == _date && r.checkIn.isNotEmpty && r.checkOut.isEmpty) {
        return r;
      }
    }
    return null;
  }

  /// Auto-fill time for the currently selected mode + snap Location to the
  /// nearest camp via GPS. Called when the form opens or the mode toggles.
  Future<void> _autofill(CounsellorState s) async {
    final now = TimeOfDay.now();
    final open = _openDoctorShift(s);
    setState(() {
      if (_mode == 'in') {
        _checkIn = fmtTime12(now);
      } else {
        _checkOut = fmtTime12(now);
      }
    });
    // Check-Out inherits the location the doctor recorded at check-in so
    // the audit trail stays consistent.
    if (_mode == 'out' && open != null) {
      setState(() => location = open.location);
      return;
    }
    if (location != null) return;
    // Same source + same fallback ladder as the counsellor screen
    // (ATTEND task B): nearest /camps/anchors anchor via GPS, else the
    // facility name from bootstrap — never a hardcoded camp.
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
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: C2.danger));
    final open = _openDoctorShift(s);
    // Guard rule 2026-08-05: Check-Out is only allowed if a matching
    // Check-In exists on the same day. Otherwise the audit trail can't
    // reconstruct the shift.
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
    if (_mode == 'in') {
      s.addDoctorAttendance(AttendanceRecord(
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
        // Local path lifted on next drain (bug 2026-08-20 — photo was
        // being dropped from offline check-in payloads).
        if (_photoPath != null) 'photo_key': _photoPath,
      });
      // Offline snapshot: a restart with no signal still shows the open
      // shift (user rule 2026-08-18) — mirror of the counsellor flow.
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
      // Close the open shift so today's record ends up complete rather
      // than as two separate rows.
      final closed = open!.copyWith(
        checkOut: _checkOut,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photoPathOut: _photoPath!,
        latOut: _lat, lngOut: _lng,
      );
      s.closeDoctorShift(open, closed);
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
      // Fixed 2026-08-20: bug was writing NOW twice (check_in = check_out
      // = same millisecond) which produced a synthetic "already closed"
      // row that _hydrateTodayFromBackend then never overwrote. Use the
      // real check-in from the open shift, and the just-submitted _checkOut.
      unawaited(AttendanceStore.open().then((st) => st.saveToday(_userKey, {
        'attendance_date': _date,
        'check_in': open.checkIn,
        'check_out': _checkOut,
        'location': open.location,
        'status': 'Present',
      })));
      // D2: shift closed — stop the pending reminders.
      unawaited(NotificationsService.instance.cancelCheckoutReminders());
      // Re-fetch server truth so the UI flips to "Day complete" without
      // waiting for a restart (bug 2026-08-20: "doc is done checkout
      // showing again check in").
      unawaited(_hydrateTodayFromBackend());
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Attendance (${_mode == 'in' ? 'Check-In' : 'Check-Out'}) submitted'),
      backgroundColor: C2.green,
    ));
    setState(() {
      showForm = false; _checkIn = ''; _checkOut = '';
      _date = fmtDate(DateTime.now());
      location = null; _notes.clear();
      _photoPath = null; _lat = null; _lng = null;
      // Snap back to the mode that makes sense the next time the form
      // opens — a fresh day starts with Check-In.
      _mode = 'in';
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

  /// Read-only pill used for auto-filled fields the doctor must not
  /// hand-edit (Check-in/out time + Location). Same styling as the
  /// counsellor lock (rule 2026-08-05).
  Widget _readOnlyPill({required IconData icon, required String value, bool empty = false}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: C2.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C2.border),
      ),
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final open = _openDoctorShift(s);
    // Today's shift may already be COMPLETE (both check_in AND check_out
    // set — either the doctor closed it or the counsellor auto-closed it
    // via cross-role mark). Hide the action button then; a lingering
    // "Mark Check-In" made it look like the check-out never happened
    // (user bug 2026-08-20: "doc is done checkout showing again check in").
    final todayClosed = s.doctorAttendance.any((r) =>
        r.date == _date && r.checkIn.isNotEmpty && r.checkOut.isNotEmpty);
    // Enforce Check-In first (rule 2026-08-05): Check-Out is only clickable
    // when an open shift exists. If the doctor previously landed on 'out'
    // without a shift, snap the mode back to 'in' so the button + form
    // stay in sync.
    if (open == null && _mode == 'out') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_openDoctorShift(context.read<CounsellorState>()) == null && _mode == 'out') {
          setState(() => _mode = 'in');
        }
      });
    }
    // Check-out pending popup — fires ONLY on the exact 3h / 6h / 9h
    // minute past check-in (user 2026-08-26 "no window, exact time").
    // The 60-sec ticker keeps this check running on the current frame.
    final _bh = _checkoutBoundaryHourFor(open);
    if (_bh > 0 && !showForm && !todayClosed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        PendingAlert.showOnce(
          context,
          key: 'doc-checkout-pending-h$_bh',
          title: 'Check-out Pending',
          message: 'You checked in at ${open!.checkIn}. Your check-out '
              'is still pending. Please complete your check-out.',
        );
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Counsellor-marked banner (user rule 2026-08-16): when the
      // counsellor ticked "Doctor" in Staff (In) on today's shift,
      // surface it here so the doctor knows their presence is on
      // record. Doctor's own check-in is still available if they want
      // their personal shift row saved — this is informational.
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
              'Counsellor $_counsellorMarkedBy has marked you present today.',
              style: ct(12.5, FontWeight.w600, C2.green))),
          ]),
        ),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('My Attendance',
        trailing: (showForm || !todayClosed)
            ? COutlineButton(showForm ? 'Close' : (open == null ? 'Mark Check-In' : 'Mark Check-Out'),
          icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
          onTap: () {
            final opening = !showForm;
            if (!opening) {
              // Close — drop the draft so reopening starts clean
              // (user 2026-08-26).
              _resetAttendForm();
              return;
            }
            setState(() {
              showForm = true;
              // Auto-select the mode based on whether an open shift exists.
              _mode = open == null ? 'in' : 'out';
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _autofill(context.read<CounsellorState>());
            });
          })
            : const SizedBox.shrink())),
      // Day-complete banner — mirrors the counsellor "attendance complete"
      // card so the doctor gets clear confirmation without a stale button.
      if (todayClosed && !showForm)
        CCard(child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFEDF7E0),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.event_available, color: C2.green)),
          const SizedBox(width: 12),
          Expanded(child: Text("Today's attendance is complete",
              style: ct(13.5, FontWeight.w700, C2.navy))),
        ])),
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
          // Time — auto-filled read-only pill (rule 2026-08-05). Cannot be
          // hand-edited so the audit trail cannot be back-dated.
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
          // Location auto-picked from GPS (nearest camp) — read-only pill
          // matches the counsellor lockdown.
          CField('Location', _readOnlyPill(
            icon: Icons.location_on_outlined,
            value: location ?? 'Detecting nearest camp via GPS…',
            empty: location == null,
          ), required: true),
          CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: null, decoration: cInput('Optional — type or use the mic').copyWith(
            suffixIcon: RemarksMicButton(controller: _notes)))),
          CField('Selfie + Location', AttendanceCapture(
            initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
            // MMU name on the watermark (user 2026-08-20). Snapped anchor
            // wins, facility name falls back — same ladder as counsellor.
            placeLabel: location
                ?? ((context.read<MastersStore>().facility?['name']
                       ?? context.read<MastersStore>().facility?['facility_name'])
                     as String?)?.trim()
                ?? '',
            onCaptured: (path, lat, lng) => setState(() { _photoPath = path; _lat = lat; _lng = lng; }),
          ), required: true),
          const SizedBox(height: 4),
          CPrimaryButton(_mode == 'in' ? 'Submit Check-In' : 'Submit Check-Out',
            icon: Icons.check_circle_outline, onTap: () => _submit(s)),
        ])),
      if (!showForm) ...[
        if (s.doctorAttendance.isEmpty)
          CCard(child: Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('No attendance marked yet', style: ct(12, FontWeight.w400, C2.text2)))))
        else
          ...s.doctorAttendance.map((r) => CCard(
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
        // Rows + check-in photo can outgrow the default half-screen sheet
        // on small devices — cap at 85% and scroll (same fix as counsellor).
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
            _row('Date', r.date), _row('Check-in', r.checkIn), _row('Check-out', r.checkOut),
            _row('Location', r.location), _row('Status', r.status),
            if (r.notes.isNotEmpty) _row('Notes', r.notes),
            if (r.lat != null && r.lng != null)
              _row('GPS', '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'),
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

  /// Render an attendance selfie: server rows carry a URL (counsellor's
  /// uploaded photo — user bug 2026-08-18 "check in image not showing"),
  /// own submissions carry a local file path.
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
}

/// Read-only summary of an attended case (doctor home → attended patient).
void showAttendedCase(BuildContext context, CPatient p) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(
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
          Text('${p.gender}, ${p.age}y · ${p.village}', style: ct(12, FontWeight.w400, C2.text2)),
        ])),
        const Icon(Icons.lock_outline, size: 18, color: C2.text3),
      ]),
      const Divider(height: 24),
      _row('Diagnosis', p.disease.isEmpty ? '—' : p.disease),
      _row('Symptoms', p.symptoms.isEmpty ? '—' : p.symptoms.join(', ')),
      if (p.observations.isNotEmpty) _row('Observations', p.observations),
      if (p.tests.isNotEmpty) _row('Tests', p.tests.join(', ')),
      if (p.doctorRemarks.isNotEmpty) _row('Remarks', p.doctorRemarks),
      const SizedBox(height: 8),
      Text('Prescription', style: ct(12.5, FontWeight.w700, C2.navy)),
      const SizedBox(height: 4),
      if (p.prescription.isEmpty) Text('—', style: ct(12, FontWeight.w400, C2.text2)),
      ...p.prescription.map((m) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('• ${m.name} — ${m.interval} × ${m.days} (Qty ${m.qty})', style: ct(12.5, FontWeight.w400, C2.text)))),
      const SizedBox(height: 12),
    ]))),
  ));
}

Widget _row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
      Expanded(child: Text(v, style: ct(13, FontWeight.w500, C2.text))),
    ]));

/// Patient Report — pick From/To dates, generate an on-screen report, export PDF.
class DoctorReport extends StatefulWidget {
  const DoctorReport({super.key});
  @override
  State<DoctorReport> createState() => _DoctorReportState();
}

class _DoctorReportState extends State<DoctorReport> {
  String _from = '';
  String _to = '';
  bool _generated = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CounsellorState>();
    final attended = s.doctorAttended;
    final completed = s.patients.where((p) => p.status == 'completed').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('Patient Report')),
      CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CField('From', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(), onPicked: (d) => setState(() => _from = fmtDate(d))))),
          const SizedBox(width: 8),
          Expanded(child: CField('To', DateField(hint: 'Select date', first: DateTime(2024), last: DateTime.now(), onPicked: (d) => setState(() => _to = fmtDate(d))))),
        ]),
        CPrimaryButton('Generate Report', icon: Icons.assessment, onTap: () {
          if (_from.isEmpty || _to.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select both From and To dates'), backgroundColor: C2.danger));
            return;
          }
          setState(() => _generated = true);
        }),
      ])),
      if (_generated)
        CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: SecBar('Patient Report · ${_from.isEmpty ? "—" : _from} – ${_to.isEmpty ? "—" : _to}')),
          ]),
          Row(children: [
            Expanded(child: StatTile('${attended.length}', 'Attended', C2.navy)),
            const SizedBox(width: 8),
            Expanded(child: StatTile('$completed', 'Completed', C2.green)),
          ]),
          const SizedBox(height: 10),
          Text('Cases', style: ct(12.5, FontWeight.w700, C2.navy)),
          const SizedBox(height: 4),
          if (attended.isEmpty) Text('No cases in this period.', style: ct(12, FontWeight.w400, C2.text2)),
          ...attended.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                Text('${p.gender}, ${p.age}y · ${p.disease.isEmpty ? "—" : p.disease}', style: ct(11.5, FontWeight.w400, C2.text2)),
              ])),
              CBadge(p.status == 'completed' ? 'Completed' : 'With Pharmacist',
                bg: p.status == 'completed' ? const Color(0xFFEDF7E0) : C2.cyanLight,
                fg: p.status == 'completed' ? C2.green : C2.cyan),
            ]),
          )),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 160,
            child: CPrimaryButton('Export PDF', icon: Icons.picture_as_pdf, onTap: () => _exportPdf(attended, completed)))),
        ])),
    ]);
  }

  Future<void> _exportPdf(List<CPatient> attended, int completed) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (ctx) => [
        pw.Header(level: 0, child: pw.Text('JubiCare - Patient Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Period: ${_from.isEmpty ? "—" : _from} to ${_to.isEmpty ? "—" : _to}'),
        pw.SizedBox(height: 6),
        pw.Text('Attended: ${attended.length}    Completed: $completed'),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: ['Date', 'Patient', 'Age/Gender', 'Diagnosis', 'Status'],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          columnWidths: {for (var i = 0; i < 5; i++) i: const pw.IntrinsicColumnWidth()},
          data: attended.map((p) => [
            p.regDate.isEmpty ? '-' : p.regDate, p.name, '${p.age}/${p.gender}',
            p.disease.isEmpty ? '-' : p.disease,
            p.status == 'with_pharma' ? 'with pharmacist' : p.status,
          ]).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'JubiCare_Patient_Report');
  }
}

/// Doctor + Pharmacist profile — same shape as the counsellor's screen
/// (user 2026-08-25 "do same for pharmacist, doctor same as counsellor").
/// Everything comes from the real backend session (bootstrap user +
/// facility blocks + AppState fields), nothing hard-coded.
class SimpleProfile extends StatelessWidget {
  final String name, role;
  const SimpleProfile({super.key, required this.name, required this.role});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final masters = context.watch<MastersStore>();
    final app = context.watch<AppState>();
    final u = masters.user;
    final f = masters.facility;

    final displayName =
        ((u?['full_name'] as String?)?.trim().isNotEmpty ?? false)
            ? (u!['full_name'] as String).trim()
            : name;
    final roleLabel = _cap((u?['role'] ?? role).toString());
    final username = (u?['username'] ?? '').toString();
    final facilityName =
        (f?['name'] ?? u?['facility_name'] ?? app.backendFacilityName ?? '—')
            .toString();
    final facilityCode =
        (f?['code'] ?? u?['facility_code'] ?? app.backendFacilityCode ?? '')
            .toString();
    final blockName =
        (f?['block_name'] ?? app.backendBlockName ?? '').toString();
    final districtName =
        (f?['district_name'] ?? app.backendDistrictName ?? '').toString();
    final vehicleNo = (f?['vehicle_no'] ?? '').toString();
    final status = _cap((f?['status'] ?? 'active').toString());
    final location = [
      if (blockName.isNotEmpty) blockName,
      if (districtName.isNotEmpty) districtName,
    ].join(', ');
    final initials =
        displayName.isEmpty ? role[0] : displayName[0].toUpperCase();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(
          backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)),
          title: Text('My Profile', style: ct(16, FontWeight.w700, C2.navy)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                gradient: C2.headerGrad,
                borderRadius: BorderRadius.circular(14),
                boxShadow: C2.shadow,
              ),
              child: Column(children: [
                Container(
                  width: 72, height: 72, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: Text(initials, style: ct(28, FontWeight.w700, Colors.white)),
                ),
                const SizedBox(height: 10),
                Text(displayName, style: ct(18, FontWeight.w700, Colors.white)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(roleLabel, style: ct(11.5, FontWeight.w600, Colors.white)),
                ),
              ]),
            ),
            CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecBar('Details'),
              _kv('Role', roleLabel),
              if (username.isNotEmpty) _kv('Username', username),
              _kv('Facility', facilityCode.isEmpty
                  ? facilityName
                  : '$facilityName ($facilityCode)'),
              if (location.isNotEmpty) _kv('Location', location),
              if (vehicleNo.isNotEmpty) _kv('Vehicle No', vehicleNo),
              _kv('Status', status),
            ])),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () async {
                if (!await confirmLogout(context)) return;
                if (!context.mounted) return;
                // REAL logout (user 2026-08-26: Yes was just popping back
                // to Home while the session stayed alive). Same lines as
                // the shell menu's logout — end the server session, stop
                // pushes, wipe user-scoped state, land on Login with no
                // back stack. Serves BOTH doctor and pharmacist (the
                // pharmacist shell reuses this SimpleProfile).
                unawaited(context.read<AuthApi>().logout().catchError((_) {}));
                unawaited(FcmService.instance
                    .unregister(context.read<ApiClient>())
                    .catchError((_) {}));
                context.read<CounsellorState>().resetForNewUser();
                context.read<AppState>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: C2.danger),
              label: Text('Log out', style: ct(14, FontWeight.w600, C2.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C2.danger),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
          Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
        ]),
      );
}
