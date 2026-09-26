import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/api_client.dart';
import '../state/auth_persistence.dart';
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
        _msgSub = FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
          // Nobody is signed in on this handset, so there is nobody to
          // notify. Asked first, and of the stored flag rather than of
          // currentUserKey, because the cross-user check below reads that
          // key and logout empties it — the guard switched itself off in
          // exactly the state it was needed for, which is why pushes kept
          // arriving after sign-out (user 2026-09-26).
          if (!await AuthPersistence.hasSession()) return;
          // A push addressed to a DIFFERENT user of this handset (uid in
          // the data payload) is dropped outright — neither banner nor
          // bell history (user 2026-08-26 cross-user leak).
          final uid = (m.data['uid'] as String?) ?? '';
          final active = NotificationsStore.currentUserKey ?? '';
          if (uid.isNotEmpty && active.isNotEmpty && uid != active) return;
          final n = m.notification;
          final title = n?.title ?? (m.data['title'] as String? ?? '');
          final body = n?.body ?? (m.data['body'] as String? ?? '');
          // Encode route + arg into a single payload string —
          // "route|arg" (arg optional). NotificationsService splits
          // it back apart on tap and publishes to NotificationRouter
          // (user 2026-09-10 foreground tap fix).
          final route = (m.data['route'] as String? ?? '').trim();
          final arg = (m.data['route_arg'] as String? ?? '').trim();
          String? payload;
          if (route.isNotEmpty) {
            payload = arg.isEmpty ? route : '$route|$arg';
          }
          if (title.isNotEmpty || body.isNotEmpty) {
            NotificationsService.instance.showNow(
              title: title.isEmpty ? 'JubiCare' : title,
              body: body,
              payload: payload,
            );
          }
          if (!_messages.isClosed) _messages.add(null);
        });
      }
    } catch (_) {/* push is a courtesy — never break the app for it */}
  }

  Future<void> _persistOnly(RemoteMessage m) async {
    // Same guard as the foreground listener: with nobody signed in there is
    // no bell to append to, and appending anyway is how a previous user's
    // notifications turned up for the next one (user 2026-09-26).
    if (!await AuthPersistence.hasSession()) return;
    final n = m.notification;
    final title = n?.title ?? (m.data['title'] as String? ?? '');
    final body = n?.body ?? (m.data['body'] as String? ?? '');
    if (title.isEmpty && body.isEmpty) return;
    // messageId dedupes against the background-isolate save of the SAME
    // push; uid drops pushes addressed to a previous user (2026-08-26).
    NotificationsStore.add(
        title: title.isEmpty ? 'JubiCare' : title, body: body,
        id: m.messageId, targetUid: m.data['uid'] as String?);
    // Emit the tap so the app-level listener can navigate — the OS has
    // already shown the tray notification; this only fires when the
    // user actually tapped it (user 2026-09-10 "click on notification
    // will go to that page for action").
    if (!_taps.isClosed) _taps.add(m);
  }

  /// Stream of RemoteMessages the user tapped. Payload's `route` +
  /// `route_arg` (both strings) tell the shell which screen to open.
  /// Fired for both `onMessageOpenedApp` (background → open) and
  /// `getInitialMessage` (killed → open).
  final _taps = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationTap => _taps.stream;

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
          // Capped: on a phone that cannot reach Firebase this sits there
          // for as long as the plugin feels like, and the user is staring
          // at a spinner on the Logout they already confirmed. Failing to
          // delete the token locally costs nothing — the server drops the
          // row on the first UnregisteredError push (user 2026-09-26).
          await FirebaseMessaging.instance
              .deleteToken()
              .timeout(const Duration(milliseconds: 800));
        } catch (_) {}
      }
    } catch (_) {}
    try {
      // Backend endpoint accepts DELETE; a POST with empty token also
      // upserts to a no-op row. DELETE is cleaner — matches the intent.
      //
      // 1.2 s rather than 4: this is best-effort cleanup, and the caller
      // is holding a signed-out user on screen while it runs. On a working
      // network it answers in a few hundred milliseconds; on a broken one,
      // waiting four seconds does not make it likelier to arrive.
      await client.delete('/users/fcm-token').timeout(
          const Duration(milliseconds: 1200));
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
    // Nobody signed in: drop it. This isolate has its own memory, so it
    // cannot consult currentUserKey — it reads the stored flag straight
    // off disk, which is the one thing logout reliably clears
    // (user 2026-09-26).
    //
    // Worth being honest about the limit: a push carrying a `notification`
    // block is drawn by Android itself before this runs, and no app code
    // can unring that. What this does prevent is the bell filling up with
    // a signed-out user's messages, and every data-only push getting
    // through. Stopping the banner needs the server to stop sending —
    // that is the FCM registration being deleted at logout.
    if (!await AuthPersistence.hasSession()) return;
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
