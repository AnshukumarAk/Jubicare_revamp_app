import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../api/auth_api.dart';
import '../api/queues_api.dart';
import '../api/masters_store.dart';
import '../api/sync_service.dart';
import '../screens/unified_login.dart';
import '../services/location_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_router.dart';
import '../services/notifications_store.dart';
import '../services/patients_cache_store.dart';
import '../services/terminology_store.dart';
import '../services/connectivity_service.dart';
import '../state/app_state.dart';
import 'cw.dart';
import 'cstate.dart';
import 'screens_dashboard.dart';
import 'screens_register.dart';
import 'screens_misc.dart';
import '../services/back_form_registry.dart';

/// Counsellor module shell: 2.0 white header (official logo + profile) and a
/// bottom navigation bar. Hosts the module's screens in an IndexedStack.
class CounsellorShell extends StatelessWidget {
  final String userName;
  const CounsellorShell({super.key, this.userName = 'Divya'});
  @override
  Widget build(BuildContext context) {
    // Uses the shared CounsellorState provided at app root.
    return _Shell(userName: userName);
  }
}

class _Shell extends StatefulWidget {
  final String userName;
  const _Shell({required this.userName});
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;

  // Visited-tab history. Android's back button walks this backwards instead
  // of closing the app so the counsellor can "roll back" through tabs the
  // way they'd expect from a browser. Duplicates are stripped so the stack
  // grows at most O(tabs).
  final List<int> _tabHistory = [0];

  // Backend refresh plumbing (mirrors the doctor/pharmacist shell pattern).
  // On mount we fetch /queues/summary/tiles + /queues/counsellor/past-7-days
  // once, then re-fetch each time SyncService drains a batch — that keeps the
  // tiles + list live with what the server actually sees.
  SyncService? _sync;
  int _lastDrainSig = -1;

  static const _nav = [
    (Icons.grid_view_rounded, 'Home'),
    (Icons.fact_check_outlined, 'Status'),
    (Icons.note_add_outlined, 'Register'),
    (Icons.location_on_outlined, 'Camps'),
    (Icons.thermostat_outlined, 'Devices'),
    // Reports tab removed 2026-07-29 per user rule.
    (Icons.event_available_outlined, 'Attend'),
  ];

  @override
  void initState() {
    super.initState();
    // Start MMU location tracking once the counsellor lands in the shell.
    // Wait for the first frame so Provider is fully wired up. If no MMU was
    // chosen at login (shouldn't happen — the login screen enforces it), we
    // just skip and the status pill stays 'Idle'.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      final tracker = context.read<LocationService>();
      final mmuId = app.currentMmuId;
      if (mmuId != null && mmuId.isNotEmpty) {
        tracker.start(mmuId: mmuId, counsellor: widget.userName);
      }
      // Hydrate the patient list from the OFFLINE CACHE first so the
      // dashboard has rows to show even before the server call returns —
      // and, critically, so an app restart with no signal still shows
      // yesterday's registrations (user bug 2026-08-20 "close app → go
      // offline → registered patient not showing").
      _hydratePatientsFromCache();
      // Then the online pull — any error surfaces via
      // CounsellorState.lastRefreshError but the cache stays on screen.
      _refreshFromBackend();
    });
    // Notification-tap listener — a tap on a check-out reminder jumps
    // to Attend, on a device-status reminder to Devices, etc (user
    // 2026-09-10). Consume() clears the pending action so a random
    // rebuild doesn't re-trigger the jump.
    NotificationRouter.instance.pending.addListener(_applyNotificationRoute);
    // Also apply any tap that landed before the shell mounted (e.g. cold
    // start from a killed-app tap).
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyNotificationRoute());
  }

  void _applyNotificationRoute() {
    if (!mounted) return;
    final r = NotificationRouter.instance.consume();
    if (r == null) return;
    switch (r.route) {
      case 'attend':   _go(5); break;
      case 'devices':  _go(4); break;
      case 'camps':    _go(3); break;
      case 'register': _go(2); break;
      case 'status':   _go(1); break;
      case 'home':     _go(0); break;
      default: /* unknown route — ignore rather than crash */ break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to SyncService drains — every time a batch (patient
    // register, doctor submit, dispense, attendance) lands on the server
    // we re-pull so the counsellor's Home reflects the fresh state without
    // a manual refresh. This mirrors dshell.dart / pshell.dart.
    final s = context.read<SyncService>();
    if (!identical(_sync, s)) {
      _sync?.removeListener(_onSyncTick);
      _sync = s..addListener(_onSyncTick);
    }
  }

  @override
  void dispose() {
    _registerScroll.dispose();
    _sync?.removeListener(_onSyncTick);
    NotificationRouter.instance.pending.removeListener(_applyNotificationRoute);
    // If the counsellor closes the app without hitting Logout, still stop the
    // sampler so we don't leak a Timer. Fire-and-forget is fine — the timer is
    // local and gets GC'd when the state does.
    try {
      context.read<LocationService>().stop();
    } catch (_) {}
    super.dispose();
  }

  /// Called every time SyncService notifies. Refresh only when a drain
  /// has actually landed something (applied/rejected/failed differs from
  /// the last snapshot) so an idle-notification storm doesn't hammer the
  /// backend.
  void _onSyncTick() {
    final s = _sync;
    if (s == null || s.lastDrainAt == null) return;
    final sig = s.lastApplied * 100000 + s.lastRejected * 100 + s.lastFailed;
    if (sig == _lastDrainSig) return;
    _lastDrainSig = sig;
    _refreshFromBackend();
  }

  /// Pull the counsellor tiles + past-7-days list from /api/queues/*, feed
  /// them into CounsellorState, and reflect success / error via
  /// setRefreshState so the dashboard's loading strip + banner update.
  String get _patientsCacheKey {
    final app = context.read<AppState>();
    return 'counsellor_${app.backendUserId ?? app.currentUser}';
  }

  Future<void> _hydratePatientsFromCache() async {
    try {
      final store = await PatientsCacheStore.open();
      final rows = store.load(_patientsCacheKey);
      if (rows.isEmpty || !mounted) return;
      context.read<CounsellorState>().mergeBackendPatients(rows);
    } catch (_) {/* first run — nothing cached yet */}
  }

  Future<void> _refreshFromBackend() async {
    if (!mounted) return;
    final store = context.read<CounsellorState>();
    final api = context.read<QueuesApi>();
    store.setRefreshState(loading: true);
    try {
      // Silent-on-failure (user 2026-08-26: banner stuck even after
      // server came back). Both calls independent + swallow errors;
      // cached values stay on screen; retry is one tap away.
      final tilesF = api.tiles().then<Map<String, dynamic>?>((v) => v)
          .catchError((_) => null);
      final listF = api.counsellorPast7Days(limit: 200)
          .then<QueueList?>((v) => v)
          .catchError((_) => null);
      // Doctor-attended (WITH_PHARMACIST + COMPLETED) pulled alongside so
      // the Home tile "Visits Completed" opens instantly on tap without a
      // per-tap fetch (user 2026-08-29 "only one time download and when
      // refresh to pull down + app bar refresh then download").
      final attendedF = api.doctorAttended(limit: 200)
          .then<QueueList?>((v) => v)
          .catchError((_) => null);
      final results = await Future.wait([tilesF, listF, attendedF]);
      if (!mounted) return;
      final tiles = results[0] as Map<String, dynamic>?;
      final list = results[1] as QueueList?;
      final attended = results[2] as QueueList?;
      if (tiles != null) store.applyTiles(tiles);
      if (list != null) {
        store.mergeBackendPatients(list.items);
        try {
          final cache = await PatientsCacheStore.open();
          await cache.save(_patientsCacheKey, list.items);
        } catch (_) {/* best-effort */}
      }
      if (attended != null) {
        // Additive — attended only ADDS its rows (WITH_PHARMACIST + COMPLETED)
        // to the primary past-7-days snapshot. Non-additive would wipe every
        // 'B' row the past-7-days merge just inserted, including brand-new
        // registrations that never enter the attended list (user 2026-09-02
        // "register today 1 ho gaya but not showing in the list").
        store.mergeBackendPatients(attended.items, additive: true);
      }
      store.setRefreshState(loading: false);
    } catch (_) {
      if (!mounted) return;
      store.setRefreshState(loading: false);
    }
  }

  final _campsRefresh = ValueNotifier(0);
  final _devicesRefresh = ValueNotifier(0);
  final _attendRefresh = ValueNotifier(0);
  // Register tab's scroll position — jumped to 0 on every entry so a new
  // registration always opens at the top of the form (user 2026-08-21).
  final _registerScroll = ScrollController();

  /// One refresh path for the app-bar button AND pull-to-refresh: online
  /// check first, then the home data (existing behaviour) plus the CURRENT
  /// tab's own rows. Never touches the offline sync queue (user 2026-08-21).
  Future<void> _refreshCurrentTab() async {
    if (!mounted || !context.read<ConnectivityService>().isOnline) return;
    // Masters + terminology also refresh on the app-bar/pull refresh so
    // any new medicine, symptom, block/village or clinical-sheet update
    // reaches the app without a re-login (user 2026-08-25).
    // AWAIT the masters refresh so the fresh /mobile/bootstrap `user`
    // block can be re-applied to AppState right after — a backend-side
    // org plan flip (free ↔ paid) then reflects on this very pull, not
    // only on the next app open (user 2026-09-08 "on refresh to pull
    // down free paid change not working").
    final masters = context.read<MastersStore>();
    await masters.refresh();
    if (!mounted) return;
    final freshUser = masters.user;
    if (freshUser != null) {
      context.read<AppState>().applyBackendUser(freshUser);
    }
    unawaited(context.read<TerminologyStore>().refresh());
    await _refreshFromBackend();
    switch (_tab) {
      case 3: _campsRefresh.value++; break;
      case 4: _devicesRefresh.value++; break;
      case 5: _attendRefresh.value++; break;
    }
  }

  void _go(int i) {
    final s = context.read<CounsellorState>();
    // Leaving Register tab in-app? Signal a full form reset so the
    // next entry starts blank (user rule 2026-08-16 — tab switch
    // clears; app-background preserves).
    if (_tab == 2 && i != 2) s.requestRegisterFullReset();
    // Normal entry into Register (no fresh Re-Appointment prefill waiting)
    // → tell the form to drop any ABANDONED re-appointment residue so a
    // new patient starts on a blank slate (user bug report 2026-08-13).
    // The re-appointment jump itself sets the prefill BEFORE _go(2), so
    // hasPrefill is true on that path and the clear is skipped.
    if (i == 2) {
      if (!s.hasPrefill) s.requestAbandonedReAppointmentClear();
      // A fresh registration starts at the TOP of the form — the
      // IndexedStack keeps the tab alive, so without this the form
      // reopens wherever it was last scrolled (user 2026-08-21).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _registerScroll.hasClients) _registerScroll.jumpTo(0);
      });
    }
    setState(() {
      if (_tab == i) return;
      _tabHistory.remove(i);
      _tabHistory.add(i);
      _tab = i;
    });
  }

  /// PopScope handler: rewind through visited tabs instead of closing the app.
  /// Returns true if the back gesture was absorbed (we switched tabs); false
  /// to let the system pop the shell (which exits at the root).
  bool _handleBack() {
    // An open inline form on the ACTIVE tab eats the first back press —
    // close it and stay on the tab's list (user 2026-08-21 check-out bug).
    if (_tab == 5 && BackFormRegistry.close('coun.attend')) return true;
    // Camps form: same close-and-clear rule (user 2026-08-26).
    if (_tab == 3 && BackFormRegistry.close('coun.camps')) return true;
    // Devices: closer only discards unsaved dropdown edits and returns
    // false, so the back press still rewinds tabs as usual.
    if (_tab == 4) BackFormRegistry.close('coun.devices');
    if (_tabHistory.length <= 1) return false; // let the system close the app
    _tabHistory.removeLast();
    final nextTab = _tabHistory.last;
    // Same tab-leave rule as _go — Android back button counts too.
    if (_tab == 2 && nextTab != 2) {
      context.read<CounsellorState>().requestRegisterFullReset();
    }
    setState(() => _tab = nextTab);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Watch state so the Re-Appointment signal fired from the Patient
    // Detail screen reaches us. When set, jump to Register on the next
    // frame (setState during build is forbidden) — the Register form's
    // build then consumes the pending prefill.
    final s = context.watch<CounsellorState>();
    if (s.consumeSwitchToRegister()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _go(2);
      });
    }
    final initials = widget.userName.isEmpty ? 'C' : widget.userName[0].toUpperCase();
    final pages = [
      CounDashboard(onRegister: () => _go(2), name: widget.userName, onRefresh: _refreshFromBackend),
      // Status → Register tab jump for the Re-Appointment button. Uses the
      // shared CounsellorState.setPrefill so the Register form picks it up on
      // the next frame.
      CounAppointmentStatus(onReAppointment: (p) {
        context.read<CounsellorState>().setPrefill(p);
        _go(2);
      }),
      // After a successful Register submit, jump back to Home so the newly
      // added patient (which insert-at-0'd into CounsellorState.patients) is
      // right at the top of the "Registered Patients" list.
      CounRegister(onSubmitted: () => _go(0)),
      CounCamps(refreshSignal: _campsRefresh),
      CounDevices(refreshSignal: _devicesRefresh),
      // CounReports removed 2026-07-29 per user rule.
      CounAttendance(refreshSignal: _attendRefresh),
    ];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      // canPop false + didPop handler = we get first crack at the back gesture.
      // Only when tab history is exhausted do we allow the system to pop the
      // shell (which would otherwise close the app on the first press).
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
          // top header
          Container(
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
                    // Sync status lives here as an icon (user 2026-08-14:
                    // banner out of the Home body) — tap for counts +
                    // "Sync now". Same data + same drain action as the
                    // old pill.
                    const SyncStatusIcon(),
                    const SizedBox(width: 10),
                    // Manual refresh — recovers the app when internet
                    // stalls without needing a restart (user rule
                    // 2026-08-16).
                    ShellRefreshButton(onRefresh: _refreshCurrentTab),
                    const SizedBox(width: 10),
                    const NotificationsBell(),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _profileMenu(context, initials),
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
          ),
          Expanded(
            // Pull-to-refresh on every tab (user rule 2026-08-16 —
            // matches the doctor role). AlwaysScrollable so the gesture
            // works even when the content is short. Same callback as
            // the app-bar refresh button so behaviour is consistent.
            child: IndexedStack(index: _tab, children: [
              for (final e in pages.asMap().entries)
                _KeepAlive(child: RefreshIndicator(
                  onRefresh: _refreshCurrentTab,
                  child: SingleChildScrollView(
                    // Register keeps a named controller so _go(2) can
                    // snap a fresh form back to the top.
                    controller: e.key == 2 ? _registerScroll : null,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    child: e.value),
                )),
            ]),
          ),
        ]),
        bottomNavigationBar: _bottomNav(),
      ),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: C2.white,
        border: Border(top: BorderSide(color: C2.border, width: 1.5)),
        boxShadow: [BoxShadow(color: Color(0x0F003087), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: List.generate(_nav.length, (i) {
            final active = i == _tab;
            final col = active ? C2.cyan : C2.text3;
            return Expanded(
              child: InkWell(
                onTap: () => _go(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_nav[i].$1, size: 19, color: col),
                    const SizedBox(height: 2),
                    Text(_nav[i].$2, style: ct(9.5, FontWeight.w600, col)),
                  ]),
                ),
              ),
            );
          })),
        ),
      ),
    );
  }

  void _profileMenu(BuildContext context, String initials) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: C2.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: C2.cyan),
            title: Text('My Profile', style: ct(14, FontWeight.w600, C2.text)),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CounProfile(name: widget.userName))); },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: C2.navy),
            title: Text('Logout', style: ct(14, FontWeight.w600, C2.text)),
            onTap: () async {
              Navigator.pop(context);
              if (!await confirmLogout(context)) return;
              if (!mounted) return;
              // Center loader so the user sees progress while the
              // FCM DELETE + auth logout round-trips run — up to a
              // few seconds on a slow network (user 2026-09-10).
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              // Stop location tracking BEFORE clearing session — otherwise the
              // sampler keeps firing after logout.
              context.read<LocationService>().stop();
              // Kill the FCM registration FIRST so the DELETE call still
              // carries a valid access token (user 2026-09-10: logout was
              // racing token-clear vs fcm DELETE; DELETE 401'd and the
              // server-side FCM row survived, so notifications kept
              // arriving after logout). AWAIT it with a short cap so a
              // slow network never blocks the logout tap.
              try {
                await FcmService.instance
                    .unregister(context.read<ApiClient>())
                    // 2 s, not 5. This is best-effort cleanup and the
                    // user has already confirmed Logout; holding them
                    // five seconds on a bad network to tidy up a push
                    // registration is the wrong trade (2026-09-26).
                    // It cannot simply move to the background: the
                    // AuthApi.logout() below clears the very token this
                    // DELETE needs, and if the user signs back in within
                    // that window it would clear the NEW session's token.
                    .timeout(const Duration(seconds: 2));
              } catch (_) {/* offline — the server auto-cleans on the
                              next UnregisteredError push */}
              if (!mounted) return;
              // Best-effort backend logout (v2 §1.3 — ends every session
              // for this account on the server). Fire-and-forget after
              // fcm unregister has finished.
              unawaited(context.read<AuthApi>().logout().catchError((_) {}));
              // Wipe user-scoped lists (user rule 2026-08-16).
              context.read<CounsellorState>().resetForNewUser();
              context.read<AppState>().logout();
              // Replace the whole navigation stack with the unified login.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                (route) => false,
              );
            },
          ),
        ])),
      ),
    );
  }
}

/// Keep each tab's scroll state alive across tab switches.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}


/// App-bar sync status: icon-only, with a pending-count badge; tapping
/// opens a sheet with the live counts and a "Sync now" action (user
/// 2026-08-14 — the old Home banner, relocated; the data and the
/// force-drain behaviour are unchanged).
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final pending = sync.pending;
    final trouble = sync.lastFailed > 0 || sync.lastRejected > 0;
    final color = pending == 0 && !trouble
        ? C2.green
        : (trouble ? C2.danger : C2.navy);
    final icon = sync.isDraining
        ? Icons.sync
        : (pending == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined);
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: color),
          if (pending > 0)
            Positioned(
              right: -5, top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: C2.danger, borderRadius: BorderRadius.circular(8)),
                child: Text('$pending', style: ct(9, FontWeight.w700, Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: C2.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        // Consumer, not a snapshot — the counts keep updating while the
        // sheet is open (e.g. a drain finishing).
        child: SafeArea(top: false, child: Consumer<SyncService>(
          builder: (_, sync, __) {
            final ts = sync.lastDrainAt;
            final label = sync.pending == 0
                ? (ts == null
                    ? 'Nothing to send yet'
                    : 'Applied ${sync.lastApplied} · rejected ${sync.lastRejected} · failed ${sync.lastFailed}')
                : '${sync.pending} pending${sync.isDraining ? ' · sending…' : ''}';
            final fg = sync.pending == 0 && sync.lastFailed == 0 && sync.lastRejected == 0
                ? C2.green
                : (sync.lastFailed > 0 || sync.lastRejected > 0 ? C2.danger : C2.text);
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.cloud_outlined, size: 18, color: C2.navy),
                const SizedBox(width: 8),
                Text('Sync Status', style: ct(15, FontWeight.w700, C2.navy)),
              ]),
              const SizedBox(height: 10),
              Text(label, style: ct(13.5, FontWeight.w600, fg)),
              if (ts != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Last push: ${fmtTime12(TimeOfDay.fromDateTime(ts))}',
                      style: ct(11.5, FontWeight.w400, C2.text2)),
                ),
              const SizedBox(height: 14),
              CPrimaryButton(sync.isDraining ? 'Sending…' : 'Sync now',
                  icon: Icons.sync,
                  onTap: sync.isDraining ? null : sync.drain),
            ]);
          },
        )),
      ),
    );
  }
}

/// App-bar notifications bell (user rule 2026-08-16). Placeholder for
/// now — tap opens a sheet that says "no new notifications". Wired for
/// backend push later without touching the shells again.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key});

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    final n = await NotificationsStore.unreadCount();
    if (mounted) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _sheet(context),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_none, size: 22, color: C2.navy),
          if (_unread > 0)
            Positioned(right: -2, top: -2, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: C2.danger, borderRadius: BorderRadius.circular(8)),
              constraints: const BoxConstraints(minWidth: 14),
              child: Text('$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            )),
        ]),
      ),
    );
  }

  /// Per-user saved history (user 2026-08-19): every notification the app
  /// showed/received is listed here, newest first. Opening marks all seen.
  Future<void> _sheet(BuildContext context) async {
    final items = await NotificationsStore.list();
    await NotificationsStore.markSeen();
    if (mounted) setState(() => _unread = 0);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: C2.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: C2.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.notifications_none, size: 18, color: C2.navy),
            const SizedBox(width: 8),
            Text('Notifications', style: ct(15, FontWeight.w700, C2.navy)),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_outline, size: 18, color: C2.text3),
                const SizedBox(width: 8),
                Text('You\'re all caught up', style: ct(13, FontWeight.w500, C2.text2)),
              ]),
            )
          else
            Flexible(child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: C2.border),
              itemBuilder: (_, i) {
                final e = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: C2.cyanLight, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.notifications_active_outlined, size: 16, color: C2.cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e['title'] ?? ''}', style: ct(13, FontWeight.w700, C2.text)),
                      if ('${e['body'] ?? ''}'.isNotEmpty)
                        Text('${e['body']}', style: ct(12, FontWeight.w400, C2.text2)),
                      Text(_ago('${e['at'] ?? ''}'), style: ct(10.5, FontWeight.w500, C2.text3)),
                    ])),
                  ]),
                );
              },
            )),
        ])),
      ),
    );
  }

  static String _ago(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${at.day.toString().padLeft(2, '0')}-${at.month.toString().padLeft(2, '0')}-${at.year} '
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }
}

/// App-bar refresh button used by every shell (user rule 2026-08-16 —
/// when internet drops or a request stalls, the user needs a way to
/// re-pull data WITHOUT restarting the app). Tap:
///   1. Calls the shell's own refresh callback (queues, tiles, roster…)
///   2. Drains the sync queue (retries anything stuck offline)
///   3. Shows a spinning indicator while in-flight
///   4. Toasts success or error
///
/// The onRefresh callback owns "what to fetch" — each shell passes its
/// existing private method (counsellor: _refreshFromBackend, doctor +
/// pharmacist: their own). This widget owns "how to present" only.
class ShellRefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const ShellRefreshButton({super.key, required this.onRefresh});

  @override
  State<ShellRefreshButton> createState() => _ShellRefreshButtonState();
}

class _ShellRefreshButtonState extends State<ShellRefreshButton>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _spin = AnimationController(
    duration: const Duration(seconds: 1), vsync: this)..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final sync = context.read<SyncService>();
    try {
      // Kick a sync drain in parallel — no await, it self-manages and
      // logs its own errors; we don't want its slowness to keep the
      // spinner going after the visible refresh has already returned.
      unawaited(sync.drain());
      await widget.onRefresh();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Refreshed'),
          duration: Duration(seconds: 1),
          backgroundColor: C2.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Refresh failed — check internet'),
          backgroundColor: C2.danger,
        ));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _busy
            ? RotationTransition(
                turns: _spin,
                child: const Icon(Icons.refresh, size: 22, color: C2.navy))
            : const Icon(Icons.refresh, size: 22, color: C2.navy),
      ),
    );
  }
}
