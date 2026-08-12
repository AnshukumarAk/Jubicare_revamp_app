import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../counsellor/shell.dart';
import '../doctor/dshell.dart';
import '../pharmacist/pshell.dart';

/// Per-role login screen (username + password). Mock auth: any non-empty
/// credentials are accepted, then routes to the role's home.
class RoleLoginScreen extends StatefulWidget {
  final Role role;
  const RoleLoginScreen({super.key, required this.role});
  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;

  Role get role => widget.role;

  void _submit() {
    // Location tracking still runs on the counsellor role — for the prototype
    // we auto-tag every point with the first seed MMU (JubiCare Gajraula-01).
    // When the dashboard-side auth pipeline is wired up we'll replace this
    // with a proper mapping from user → MMU.
    final autoMmuId = role == Role.counselor ? kMmuOptions.first.id : null;
    final ok = context.read<AppState>().login(role, _user.text, _pass.text, mmuId: autoMmuId);
    if (!ok) {
      setState(() => _error = 'Invalid username or password');
      return;
    }
    final name = role.fullName;
    final Widget dest = switch (role) {
      Role.counselor => CounsellorShell(userName: name),
      Role.doctor => DoctorShell(userName: name),
      Role.pharmacist => PharmacistShell(userName: name),
    };
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JC.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Role-branded header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: JC.headerGradient),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
              child: Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                  child: Icon(role.icon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text('${role.label} Login',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(role.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Username', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _user,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Enter username', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: JC.coral, fontSize: 12.5)),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text('Sign in with your ${role.label} credentials',
                      style: const TextStyle(color: JC.muted, fontSize: 11.5)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
