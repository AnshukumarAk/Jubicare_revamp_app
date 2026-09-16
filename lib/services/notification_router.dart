import 'package:flutter/foundation.dart';

/// Global router for notification-tap actions.
///
/// [FcmService] emits a tap → main.dart parses `route`/`route_arg` from the
/// FCM data → sets [pending]. Each role shell listens to [pending] and
/// switches to the matching tab (or opens the matching detail sheet)
/// once it applies the route (user 2026-09-10 "click on notification
/// will go to that page for action").
///
/// Every shell should [consume] the pending action after handling so a
/// subsequent unrelated rebuild doesn't re-trigger the same jump.
class NotificationRouter {
  NotificationRouter._();
  static final NotificationRouter instance = NotificationRouter._();

  final ValueNotifier<PendingRoute?> pending = ValueNotifier<PendingRoute?>(null);

  void push(String route, [String? arg]) {
    if (route.isEmpty) return;
    pending.value = PendingRoute(route: route, arg: arg);
  }

  PendingRoute? consume() {
    final r = pending.value;
    pending.value = null;
    return r;
  }
}

class PendingRoute {
  final String route;
  final String? arg;
  const PendingRoute({required this.route, this.arg});
}
