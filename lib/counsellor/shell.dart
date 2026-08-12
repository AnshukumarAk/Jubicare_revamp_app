import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import '../api/auth_api.dart';
import '../screens/unified_login.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import 'cw.dart';
import 'cstate.dart';
import 'screens_dashboard.dart';
import 'screens_register.dart';
import 'screens_misc.dart';

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
    });
  }

  @override
  void dispose() {
    // If the counsellor closes the app without hitting Logout, still stop the
    // sampler so we don't leak a Timer. Fire-and-forget is fine — the timer is
    // local and gets GC'd when the state does.
    try {
      context.read<LocationService>().stop();
    } catch (_) {}
    super.dispose();
  }

  void _go(int i) => setState(() {
    if (_tab == i) return;
    _tabHistory.remove(i);
    _tabHistory.add(i);
    _tab = i;
  });

  /// PopScope handler: rewind through visited tabs instead of closing the app.
  /// Returns true if the back gesture was absorbed (we switched tabs); false
  /// to let the system pop the shell (which exits at the root).
  bool _handleBack() {
    if (_tabHistory.length <= 1) return false; // let the system close the app
    _tabHistory.removeLast();
    setState(() => _tab = _tabHistory.last);
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
      CounDashboard(onRegister: () => _go(2), name: widget.userName),
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
      const CounCamps(),
      const CounDevices(),
      // CounReports removed 2026-07-29 per user rule.
      const CounAttendance(),
    ];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      // canPop false + didPop handler = we get first crack at the back gesture.
      // Only when tab history is exhausted do we allow the system to pop the
      // shell (which would otherwise close the app on the first press).
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final absorbed = _handleBack();
          if (!absorbed) SystemNavigator.pop();
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
            child: IndexedStack(index: _tab, children: pages.map((p) =>
              _KeepAlive(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), child: p))).toList()),
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
            onTap: () {
              Navigator.pop(context);
              // Stop location tracking BEFORE clearing session — otherwise the
              // sampler keeps firing after logout.
              context.read<LocationService>().stop();
              // Best-effort backend logout (v2 §1.3 — ends every session
              // for this account on the server). Fire-and-forget; local
              // cleanup happens either way.
              unawaited(context.read<AuthApi>().logout().catchError((_) {}));
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

