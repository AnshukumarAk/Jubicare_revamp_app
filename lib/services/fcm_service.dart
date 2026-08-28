import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/api_client.dart';
import 'notifications_service.dart';
import 'notifications_store.dart';

/// Firebase Cloud Messaging wiring (ATTEND task D1, 2026-08-18).
///
/// Coverage across every app state (user requirement):
///  * FOREGROUND — Android suppresses the system banner, so [register]'s
///    onMessage listener re-renders the push through
///    [NotificationsService.showNow].
///  * BACKGROUND / KILLED — FCM "notification" messages are displayed by
///    the OS itself on the `attend` channel (declared in the manifest
///    meta-data), no app code required.
///
/// Token lifecycle: after login the device token is POSTed to
/// `/users/fcm-token`; onTokenRefresh re-registers. The backend upserts on
/// the token, so a shared MMU handset follows whoever logged in last.
///
/// Everything is best-effort: if google-services.json is absent or Firebase
/// failed to init, [register] quietly does nothing — attendance still works.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _listening = false;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _msgSub;

  /// Fires once per foreground FCM message. The Attend screens listen and
  /// re-hydrate from the server, so a counsellor's mark shows up WITHOUT a
  /// re-login (user bug 2026-08-18).
  final _messages = StreamController<void>.broadcast();
  Stream<void> get onMessageReceived => _messages.stream;

  /// Ask notification permission, upload the FCM token, and start the
  /// foreground listener. Call after login (and at app start when a
  /// stored session exists). Safe to call repeatedly.
  Future<void> register(ApiClient client) async {
    try {
      if (Firebase.apps.isEmpty) return; // Firebase never initialised
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();

      Future<void> upload(String? token) async {
        if (token == null || token.isEmpty) return;
        try {
          await client.post('/users/fcm-token', body: {'token': token});
        } catch (_) {/* offline — retried on next register/refresh */}
      }

      await upload(await fm.getToken());

      if (!_listening) {
        _listening = true;
        _tokenSub = fm.onTokenRefresh.listen(upload);
        // Background/killed-state notifications are shown by the OS, so
        // the app only learns about them when the user taps one — persist
        // those into the per-user history too (user 2026-08-19).
        FirebaseMessaging.onMessageOpenedApp.listen(_persistOnly);
        fm.getInitialMessage().then((m) {
          if (m != null) _persistOnly(m);
        });
        _msgSub = FirebaseMessaging.onMessage.listen((RemoteMessage m) {
          // A push addressed to a DIFFERENT user of this handset (uid in
          // the data payload) is dropped outright — neither banner nor
          // bell history (user 2026-08-26 cross-user leak).
          final uid = (m.data['uid'] as String?) ?? '';
          final active = NotificationsStore.currentUserKey ?? '';
          if (uid.isNotEmpty && active.isNotEmpty && uid != active) return;
          final n = m.notification;
          final title = n?.title ?? (m.data['title'] as String? ?? '');
          final body = n?.body ?? (m.data['body'] as String? ?? '');
          if (title.isNotEmpty || body.isNotEmpty) {
            NotificationsService.instance.showNow(
              title: title.isEmpty ? 'JubiCare' : title,
              body: body,
            );
          }
          if (!_messages.isClosed) _messages.add(null);
        });
      }
    } catch (_) {/* push is a courtesy — never break the app for it */}
  }

  void _persistOnly(RemoteMessage m) {
    final n = m.notification;
    final title = n?.title ?? (m.data['title'] as String? ?? '');
    final body = n?.body ?? (m.data['body'] as String? ?? '');
    if (title.isEmpty && body.isEmpty) return;
    // messageId dedupes against the background-isolate save of the SAME
    // push; uid drops pushes addressed to a previous user (2026-08-26).
    NotificationsStore.add(
        title: title.isEmpty ? 'JubiCare' : title, body: body,
        id: m.messageId, targetUid: m.data['uid'] as String?);
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _msgSub?.cancel();
    _listening = false;
  }

  /// Logout hook — the OS keeps pushing to whatever token was last
  /// registered, so the previous user still gets Check-out / Devices
  /// notifications on this handset (user bug 2026-08-20). Steps:
  ///   1. Delete the FCM token on-device — the next user login will
  ///      request a fresh one.
  ///   2. Best-effort DELETE on backend (`/users/fcm-token`). The
  ///      server also auto-cleans a token on the first push that comes
  ///      back UnregisteredError, so failure here is not fatal.
  ///   3. Clear the persisted active-user key so the background isolate
  ///      doesn't append notifications to the logged-out user's bell.
  Future<void> unregister(ApiClient client) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
      }
    } catch (_) {}
    try {
      // Backend endpoint accepts DELETE; a POST with empty token also
      // upserts to a no-op row. DELETE is cleaner — matches the intent.
      await client.delete('/users/fcm-token').timeout(
          const Duration(seconds: 4));
    } catch (_) {/* offline / not deployed — the token dies locally anyway */}
    await NotificationsStore.setCurrentUser(null);
    await dispose();
  }
}

/// Background/killed-state message hook. FCM notification-messages are
/// shown by the OS without this, but the handler must exist (and be a
/// top-level @pragma function) for data-only messages not to be dropped.
///
/// User rule 2026-08-20: "save notification when user inside app,
/// outside app, or kill app". The system tray banner is the OS's job;
/// we ALSO append the message to the per-user bell history here so it
/// shows up in-app whether or not the user ever tapped the tray.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Firebase must be initialised in the background isolate too — the
    // main isolate's init doesn't carry over.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final n = message.notification;
    final title = n?.title ?? (message.data['title'] as String? ?? '');
    final body = n?.body ?? (message.data['body'] as String? ?? '');
    if (title.isEmpty && body.isEmpty) return;
    await NotificationsStore.add(
      title: title.isEmpty ? 'JubiCare' : title,
      body: body,
      // Same push may be persisted again when the user taps the tray
      // banner (onMessageOpenedApp) — messageId collapses the two.
      id: message.messageId,
      targetUid: message.data['uid'] as String?,
    );
  } catch (_) {/* never crash the isolate */}
}
