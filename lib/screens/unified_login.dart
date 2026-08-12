import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_errors.dart';
import '../api/auth_api.dart';
import '../api/masters_store.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auth_persistence.dart';
import '../theme/app_theme.dart';
import '../counsellor/shell.dart';
import '../doctor/dshell.dart';
import '../pharmacist/pshell.dart';

/// Single login screen. The user enters username + password. The app
/// hits `/api/auth/login` first; on success it persists tokens + user,
/// pulls `/mobile/bootstrap`, and routes to the matching role shell.
/// When the backend is unreachable, the local mock login (matches
/// role.credUser / role.credPass) kicks in so the demo still works
/// on a laptop with no server.
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});
  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _busy = false;

  Role? _matchLocalRole() {
    final u = _user.text.trim();
    final p = _pass.text;
    for (final r in Role.values) {
      if (u == r.credUser && p == r.credPass) return r;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter username and password');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _doLogin();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doLogin() async {
    final auth = context.read<AuthApi>();
    final masters = context.read<MastersStore>();
    final app = context.read<AppState>();

    LoginResult? result;
    try {
      result = await auth.login(_user.text.trim(), _pass.text);
    } on ApiException catch (e) {
      // Fall back to the local mock login when the backend is
      // unreachable OR temporarily unhealthy (5xx). A legit
      // credentials rejection (401) still shows its message so we
      // don't mask real auth errors behind a happy demo path.
      final serverDown = e.code == ApiErrorCode.networkUnreachable ||
          (e.statusCode != null && e.statusCode! >= 500);
      if (serverDown) {
        return _fallbackLocalLogin(app);
      }
      setState(() => _error = e.message);
      return;
    } catch (_) {
      setState(() => _error = 'Sign-in failed. Please try again.');
      return;
    }

    // Load AppState from the backend user block, persist the session
    // + backend snapshot for cold starts, then chain /mobile/bootstrap.
    final user = result.user;
    app.applyBackendUser(user);
    final role = app.currentRole;
    if (role == null) {
      setState(() => _error = 'This role is not supported in the mobile app yet.');
      return;
    }

    // Await bootstrap BEFORE navigating — the facility block carries the
    // human-readable state/district/block names that every sync-push
    // payload needs (the login response only carries their ids). Without
    // this the counsellor Register form pushes NULLs and the server
    // rejects on unknown village.
    await masters.refresh();
    final facility = masters.facility;
    if (facility != null) app.applyBootstrapFacility(facility);

    // AuthPersistence.save stores the flag + the backend user block so
    // a cold start restores enough to render the shell before /me
    // returns.
    await AuthPersistence.save(
      role: role,
      username: _user.text.trim(),
      mmuId: app.currentMmuId,
      backendUser: user,
    );

    _goToShell(role);
  }

  void _fallbackLocalLogin(AppState app) {
    final role = _matchLocalRole();
    if (role == null) {
      setState(() => _error = 'Cannot reach the server. Please check your internet.');
      return;
    }
    final mmuId = role == Role.counselor ? 'MMU001' : null;
    app.login(role, _user.text, _pass.text, mmuId: mmuId);
    unawaited(AuthPersistence.save(
      role: role,
      username: _user.text.trim(),
      mmuId: mmuId,
    ));
    _goToShell(role);
  }

  void _goToShell(Role role) {
    if (!mounted) return;
    final name = role.fullName;
    final Widget dest = switch (role) {
      Role.counselor => CounsellorShell(userName: name),
      Role.doctor => DoctorShell(userName: name),
      Role.pharmacist => PharmacistShell(userName: name),
    };
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JC.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: JC.headerGradient),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Column(children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/jubicare_logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 14),
                const Text('JubiCare MMU',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Sign in to continue',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Username', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _user,
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Enter username', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _pass,
                  enabled: !_busy,
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
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(_busy ? 'Signing in…' : 'Login'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
