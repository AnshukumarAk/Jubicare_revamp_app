import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide connectivity flag. Backed by connectivity_plus.
///
/// Consumed by widgets that must hide themselves when the device is offline —
/// most notably the AI Clinical Advisory (doctor Case Details) and the Likely
/// Conditions panel (counsellor SymptomField). The user rule is: no AI/ML
/// features may be shown when the counsellor/doctor is offline.
///
/// Usage:
///   final online = context.watch<ConnectivityService>().isOnline;
///   if (online) ...
class ConnectivityService extends ChangeNotifier {
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _online;
  bool get isOffline => !_online;

  ConnectivityService() {
    // Fire-and-forget: probe once, then subscribe.
    _probe();
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
  }

  Future<void> _probe() async {
    try {
      final r = await Connectivity().checkConnectivity();
      _apply(r);
    } catch (_) {
      // If the platform channel throws, assume online — safer than hiding the
      // advisory forever because a plugin misbehaved.
      _online = true;
      notifyListeners();
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final on = results.any((r) => r != ConnectivityResult.none);
    if (on != _online) {
      _online = on;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
