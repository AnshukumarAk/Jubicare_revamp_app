import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'role_login.dart';

/// Entry screen: pick a role, which opens that role's own login screen.
class LoginLanding extends StatelessWidget {
  const LoginLanding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/jubicare_logo.png',
                  height: 96,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('Mobile Medical Unit',
                    style: TextStyle(color: JC.muted, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2)),
              ),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('Login as', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: JC.ink)),
              ),
              ...Role.values.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _RoleCard(role: r),
                  )),
              const SizedBox(height: 18),
              const Center(
                child: Text('© 2026 Jubilant Bhartia Foundation',
                    style: TextStyle(color: JC.muted, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Role role;
  const _RoleCard({required this.role});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: JC.card,
      borderRadius: JC.radius,
      elevation: 0,
      child: InkWell(
        borderRadius: JC.radius,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => RoleLoginScreen(role: role))),
        child: Container(
          decoration: BoxDecoration(borderRadius: JC.radius, boxShadow: JC.cardShadow),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: role.color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(role.icon, color: role.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(role.subtitle, style: const TextStyle(color: JC.muted, fontSize: 12.5)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: JC.muted),
          ]),
        ),
      ),
    );
  }
}
