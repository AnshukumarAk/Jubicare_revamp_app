import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_landing.dart';

/// Simple per-role home dashboard. Tiles are placeholders to be fleshed out
/// from the user's further instructions.
class RoleHome extends StatelessWidget {
  final Role role;
  const RoleHome({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return JcScaffold(
      title: 'Home',
      showBack: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout',
          onPressed: () {
            context.read<AppState>().logout();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginLanding()),
              (r) => false,
            );
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _greeting(s),
          const SizedBox(height: 16),
          ..._tilesFor(role).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HomeTile(
                  icon: t.$1,
                  iconColor: role.color,
                  label: t.$2,
                  count: t.$3,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Module coming soon — awaiting further instructions')),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _greeting(AppState s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: JC.headerGradient, borderRadius: JC.radius, boxShadow: JC.cardShadow),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(role.icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, ${role.label}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(s.currentUser.isEmpty ? role.demoUser : s.currentUser,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.circle, size: 9, color: s.online ? JC.teal : JC.coral),
              const SizedBox(width: 5),
              Text(s.online ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// (icon, label, optional count) tiles per role.
  List<(IconData, String, String?)> _tilesFor(Role r) => switch (r) {
        Role.counselor => [
            (Icons.event_available, 'Appointments', '0'),
            (Icons.person_add_alt_1, 'Register Patient', null),
            (Icons.fact_check_outlined, 'Attendance', null),
            (Icons.insert_chart_outlined, 'Reports', null),
          ],
        Role.doctor => [
            (Icons.pending_actions, 'Pending Patients', '0'),
            (Icons.assignment_turned_in_outlined, 'Attended Cases', '0'),
          ],
        Role.pharmacist => [
            (Icons.medication_liquid, 'Pending Prescriptions', '0'),
            (Icons.check_circle_outline, 'Dispensed', '0'),
            (Icons.inventory_2_outlined, 'Medicine Stock', null),
          ],
      };
}
