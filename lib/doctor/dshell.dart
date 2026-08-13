import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../api/api_errors.dart';
import '../api/attendance_api.dart';
import '../api/auth_api.dart';
import '../api/queues_api.dart';
import '../api/sync_service.dart';
import '../counsellor/cw.dart';
import '../counsellor/cstate.dart';
import '../counsellor/screens_dashboard.dart' show CounPatientDetail;
import '../screens/unified_login.dart';
import '../state/app_state.dart';
import '../widgets/attendance_capture.dart';
import 'dcase.dart';
import 'voice.dart';

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
  static const _nav = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.medical_services_outlined, 'Case'),
    // Report tab removed 2026-08-05 per user rule.
    (Icons.event_available_outlined, 'Attend'),
  ];
  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.replaceAll('Dr. ', '').isEmpty ? 'D' : widget.userName.replaceAll('Dr. ', '')[0].toUpperCase();
    final pages = [
      DoctorDashboard(name: widget.userName, onOpenCase: () => _go(1)),
      const DoctorCaseList(),
      // DoctorReport removed 2026-08-05 per user rule.
      const DoctorAttendance(),
    ];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        body: Column(children: [
          DocHeader(initials: initials, userName: widget.userName, role: 'Doctor'),
          Expanded(child: IndexedStack(index: _tab, children: pages.map((p) =>
            SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), child: p)).toList())),
        ]),
        bottomNavigationBar: DocBottomNav(items: _nav, current: _tab, onTap: _go),
      ),
    );
  }
}

/// Shared 2.0 header (logo + bell + profile avatar) reused by doctor/pharmacist.
class DocHeader extends StatelessWidget {
  final String initials, userName, role;
  const DocHeader({super.key, required this.initials, required this.userName, required this.role});
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
              onTap: () {
                Navigator.pop(context);
                // Best-effort backend logout (v2 §1.3).
                unawaited(context.read<AuthApi>().logout().catchError((_) {}));
                // Clear session state and route back to the unified login.
                // pushAndRemoveUntil is required because pushReplacement chained
                // the previous routes off the stack — nothing to pop back to.
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
  const DoctorDashboard({super.key, required this.name, required this.onOpenCase});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  bool _refreshing = false;
  String? _lastError;
  SyncService? _sync;
  int _lastDrainSignature = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBackend());
  }

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

  Future<void> _refreshFromBackend() async {
    if (_refreshing || !mounted) return;
    setState(() { _refreshing = true; _lastError = null; });
    try {
      final api = context.read<QueuesApi>();
      // Pull queue + attended in one shot so the tiles + lists stay
      // consistent with the same server-side snapshot.
      final queue = await api.doctorQueue(limit: 200);
      final attended = await api.doctorAttended(limit: 200);
      if (!mounted) return;
      final store = context.read<CounsellorState>();
      // One merge call carrying both queue + attended rows — server
      // status ('with_doctor', 'with_pharma', 'completed') decides
      // whether each lands in doctorQueue vs doctorAttended.
      final combined = [ ...queue.items, ...attended.items ];
      store.mergeBackendPatients(combined);
    } on ApiException catch (e) {
      if (mounted) setState(() => _lastError = e.message);
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
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
                Expanded(child: Text('Showing cached list — tap to retry',
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
            onTap: () => showAttendedCase(context, p),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C2.cyanLight))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: ct(13, FontWeight.w600, C2.text)),
                  Text('${p.disease.isEmpty ? "—" : p.disease} · ${p.prescription.length} meds', style: ct(11.5, FontWeight.w400, C2.text2)),
                ])),
                CBadge(p.status == 'completed' ? 'Completed' : 'At Pharmacy', bg: p.status == 'completed' ? const Color(0xFFEDF7E0) : C2.cyanLight, fg: p.status == 'completed' ? C2.green : C2.cyan),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CounPatientDetail(p: p, showReAppointment: false))),
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

  Widget _statusBadge(String status) {
    final (label, bg, fg) = switch (status) {
      'completed' => ('Completed', const Color(0xFFEDF7E0), C2.green),
      'with_pharma' => ('At Pharmacy', C2.cyanLight, C2.cyan),
      'with_doctor' => ('In Progress', C2.cyanLight, C2.cyan),
      _ => ('Waiting', const Color(0xFFFEF7E0), const Color(0xFFB8860B)),
    };
    return CBadge(label, bg: bg, fg: fg);
  }
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
  const DoctorAttendance({super.key});
  @override
  State<DoctorAttendance> createState() => _DoctorAttendanceState();
}

// Reused for both the doctor + pharmacist attendance forms so the location
// auto-pick uses the same set of camp anchors as the counsellor screen.
const Map<String, ({double lat, double lng})> _kDocCampCoords = {
  'Gajraula Camp': (lat: 28.845, lng: 78.240),
  'Amroha Camp':   (lat: 28.910, lng: 78.470),
  'Hasanpur Camp': (lat: 28.719, lng: 78.302),
};

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

  @override
  void initState() {
    super.initState();
    _date = fmtDate(DateTime.now());
    _hydrateTodayFromBackend();
  }

  @override
  void dispose() { _notes.dispose(); super.dispose(); }

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
      if (row is! Map) return;
      final m = row.cast<String, dynamic>();
      final date    = _fmtServerDate('${m['attendance_date'] ?? ''}');
      final checkIn = _fmtServerTime('${m['check_in'] ?? ''}');
      // No usable check-in means there is nothing to reopen.
      if (date.isEmpty || checkIn.isEmpty) return;
      if (!mounted) return;
      final s = context.read<CounsellorState>();
      // A record marked in this same session already covers the day —
      // re-adding it would show the shift twice in History.
      if (s.doctorAttendance.any((r) => r.date == date)) return;
      s.addDoctorAttendance(AttendanceRecord(
        date:      date,
        checkIn:   checkIn,
        checkOut:  _fmtServerTime('${m['check_out'] ?? ''}'),
        location:  '${m['location'] ?? m['anchor_name'] ?? ''}',
        status:    '${m['status'] ?? 'Present'}',
        notes:     '${m['notes'] ?? ''}',
        photoPath: '${m['photo_path'] ?? ''}',
        photo:     '${m['photo_path'] ?? ''}'.isNotEmpty,
        lat:       (m['latitude']  as num?)?.toDouble(),
        lng:       (m['longitude'] as num?)?.toDouble(),
      ));
      if (mounted) setState(() {});
    } catch (_) {
      // Offline, or the endpoint isn't deployed — fall back to local state.
      // Check-In still works; Check-Out stays gated exactly as before.
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
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      String? nearest;
      double best = double.infinity;
      for (final e in _kDocCampCoords.entries) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, e.value.lat, e.value.lng);
        if (d < best) { best = d; nearest = e.key; }
      }
      if (nearest != null && mounted) setState(() => location = nearest);
    } catch (_) { /* fall through — counsellor can pick manually */ }
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
        'attendance_date': _date,
        'check_in':        _checkIn,
        'location':        location!,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
      });
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
        'attendance_date': _date,
        'check_out':       _checkOut,
        'latitude':        _lat,
        'longitude':       _lng,
        'notes':           _notes.text.trim(),
      });
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SecBar('My Attendance',
        trailing: COutlineButton(showForm ? 'Close' : (open == null ? 'Mark Check-In' : 'Mark Check-Out'),
          icon: showForm ? Icons.close : (open == null ? Icons.login : Icons.logout),
          onTap: () {
            final opening = !showForm;
            setState(() {
              showForm = opening;
              // Auto-select the mode based on whether an open shift exists.
              if (opening) _mode = open == null ? 'in' : 'out';
            });
            if (opening) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _autofill(context.read<CounsellorState>());
              });
            }
          }))),
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
          CField('Notes', TextField(controller: _notes, minLines: 2, maxLines: 3, decoration: cInput('Optional — type or use the mic').copyWith(
            suffixIcon: VoiceMicButton(controller: _notes)))),
          CField('Selfie + Location', AttendanceCapture(
            initialPhotoPath: _photoPath, initialLat: _lat, initialLng: _lng,
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
        builder: (_) => Container(
          decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.file(File(r.photoPath), height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 80, color: C2.border,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: C2.text3))))),
            ],
          ])),
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

class SimpleProfile extends StatelessWidget {
  final String name, role;
  const SimpleProfile({super.key, required this.name, required this.role});
  @override
  Widget build(BuildContext context) {
    final initials = name.replaceAll('Dr. ', '').isEmpty ? '?' : name.replaceAll('Dr. ', '')[0].toUpperCase();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: C2.bg,
        appBar: AppBar(backgroundColor: C2.white, foregroundColor: C2.navy, elevation: 0,
          shape: const Border(bottom: BorderSide(color: C2.cyan, width: 3)), title: Text('My Profile', style: ct(16, FontWeight.w700, C2.navy))),
        body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
          CCard(child: Column(children: [
            Container(width: 64, height: 64, alignment: Alignment.center, decoration: const BoxDecoration(gradient: C2.headerGrad, shape: BoxShape.circle),
              child: Text(initials, style: ct(26, FontWeight.w700, Colors.white))),
            const SizedBox(height: 10),
            Text(name, style: ct(17, FontWeight.w700, C2.text)),
            Text(role, style: ct(12.5, FontWeight.w400, C2.text2)),
          ])),
          CCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SecBar('Details'),
            _kv('Role', role), _kv('Phone', '9876500011'), _kv('Facility', 'MMU-01 · Gajraula Block, Amroha'), _kv('Status', 'Active'),
          ])),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.logout, color: C2.danger),
            label: Text('Log out', style: ct(14, FontWeight.w600, C2.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: C2.danger), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
        ])),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: ct(12, FontWeight.w400, C2.text2))),
        Expanded(child: Text(v, style: ct(13, FontWeight.w600, C2.text))),
      ]));
}
