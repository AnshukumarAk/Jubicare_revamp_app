import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../counsellor/cstate.dart';
import '../counsellor/cw.dart' show confirmLogout;
import '../screens/unified_login.dart';
import '../state/app_state.dart';
import 'fcm_service.dart';
import 'location_service.dart';

/// Signing out, in one place.
///
/// There are four Logout buttons in the app — two shell menus and two
/// profile screens — and they had drifted into four slightly different
/// sequences. One of them (the counsellor's profile) called AuthApi.logout()
/// before the FCM unregister, so its DELETE went out with no bearer token
/// essentially every time; the menus felt slower than the profiles because
/// they close a sheet first and then wait for the network with the busy Home
/// screen still on top. The user reported exactly that: "from profile I am
/// logging out fast" (2026-09-26).
///
/// So: nobody waits. The session is cleared and the login screen is shown at
/// once, and the server-side tidying runs detached behind it.
///
/// That used to be unsafe, and the old comments said so: a user signing back
/// in within a couple of seconds would have had the NEW session's push token
/// deleted, or the new session revoked, by the previous logout's calls
/// arriving late. Both now name what they are removing — the refresh token
/// for the session, the token string for the push registration — so a late
/// call can only remove the old one. Making those per-device is what made
/// this possible.
///
/// Order still matters inside the background work: the FCM DELETE needs the
/// access token that AuthApi.logout() clears, so it goes first.
Future<void> performLogout(BuildContext context) async {
  if (!await confirmLogout(context)) return;
  if (!context.mounted) return;

  // Read everything off the context BEFORE the stack is replaced — after
  // that this context is dead and context.read would throw.
  final client = context.read<ApiClient>();
  final authApi = context.read<AuthApi>();
  final navigator = Navigator.of(context);

  // Stop the GPS sampler before the session goes, or it keeps firing for a
  // user who has signed out.
  context.read<LocationService>().stop();
  // Wipe user-scoped lists so the next person on this handset never sees the
  // previous one's rows (user rule 2026-08-16).
  context.read<CounsellorState>().resetForNewUser();
  // Clears AuthPersistence, so the push handlers stop accepting messages
  // immediately. It does NOT clear TokenStore — that is AuthApi.logout()'s
  // job below, which is why the background calls still have a token to use.
  context.read<AppState>().logout();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
    (route) => false,
  );

  unawaited(_tidyUpBehind(client, authApi));
}

/// Server-side cleanup, off the user's path.
///
/// Every step is best-effort. The generous timeouts are affordable now that
/// nobody is watching a spinner through them: the handset has already moved
/// on, and the only cost of a slow call here is a little battery.
Future<void> _tidyUpBehind(ApiClient client, AuthApi authApi) async {
  try {
    await FcmService.instance
        .unregister(client)
        .timeout(const Duration(seconds: 6));
  } catch (_) {/* the server drops the row on the first Unregistered push */}
  try {
    await authApi.logout();
  } catch (_) {/* the session expires on its own; TokenStore is cleared in
                  AuthApi.logout's finally either way */}
}
