import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';

/// One GPS sample. Buffered locally when offline, drained to Firestore when
/// connectivity returns.
class TrackPoint {
  final String mmuId;
  final String counsellor;
  final double lat;
  final double lng;
  final double accuracyMeters;
  final int timestampMs;

  TrackPoint({
    required this.mmuId,
    required this.counsellor,
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'mmuId': mmuId,
        'counsellor': counsellor,
        'lat': lat,
        'lng': lng,
        'accuracyMeters': accuracyMeters,
        'timestampMs': timestampMs,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
        mmuId: j['mmuId'] as String,
        counsellor: j['counsellor'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        accuracyMeters: (j['accuracyMeters'] as num).toDouble(),
        timestampMs: j['timestampMs'] as int,
      );
}

/// Continuous foreground GPS tracker. Samples every [sampleInterval], buffers
/// to SharedPreferences when offline, drains the buffer to Firestore whenever
/// connectivity comes back or a new point is captured while online.
///
/// Foreground-only by design: no ACCESS_BACKGROUND_LOCATION permission is
/// requested. If the counsellor backgrounds the app the OS will pause the
/// Timer, and tracking resumes when the app returns to the foreground.
class LocationService extends ChangeNotifier {
  static const Duration sampleInterval = Duration(seconds: 90);
  static const String _bufferKey = 'jc_track_buffer_v1';

  final FirebaseService firebase;
  LocationService(this.firebase);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _running = false;
  bool _online = true;
  String? _mmuId;
  String? _counsellor;
  int _bufferedCount = 0;
  String _statusText = 'Idle';

  bool get isRunning => _running;
  bool get isOnline => _online;
  int get bufferedCount => _bufferedCount;
  String get statusText => _statusText;

  /// Starts sampling. Safe to call multiple times — a no-op if already running
  /// for the same MMU. If the MMU changes, restart with the new tag.
  Future<void> start({required String mmuId, required String counsellor}) async {
    if (_running && _mmuId == mmuId) return;
    await stop();

    _mmuId = mmuId;
    _counsellor = counsellor;
    _running = true;

    // Ask for permission up front. If the user denies, we still run — points
    // simply won't be captured until they enable location later.
    await _ensurePermission();

    // Prime: immediately take a first sample so the dashboard sees a point
    // right after login instead of waiting a full sample interval.
    await _sampleOnce();

    _timer = Timer.periodic(sampleInterval, (_) => _sampleOnce());

    // Watch connectivity. When it flips back to online, drain any queued
    // samples. Also reflect the online/offline state in the status pill.
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      _online = online;
      if (online) await _drain();
      _refreshStatus();
    });
    // Kick off an initial connectivity check (the stream only fires on change).
    try {
      final results = await Connectivity().checkConnectivity();
      _online = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _online = true; // assume online if the check fails; drains will simply fail-and-buffer
    }

    _bufferedCount = await _bufferSize();
    _refreshStatus();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _connSub?.cancel();
    _connSub = null;
    _running = false;
    _mmuId = null;
    _counsellor = null;
    _statusText = 'Idle';
    notifyListeners();
  }

  Future<void> _ensurePermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      // If deniedForever, do nothing — the user has to change it in Settings.
    } catch (e) {
      debugPrint('[LocationService] permission error: $e');
    }
  }

  Future<void> _sampleOnce() async {
    if (!_running || _mmuId == null || _counsellor == null) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _statusText = 'GPS off';
        notifyListeners();
        return;
      }
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _statusText = 'Location denied';
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = TrackPoint(
        mmuId: _mmuId!,
        counsellor: _counsellor!,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: pos.accuracy,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

      // Try to push straight to Firestore. On failure (offline, Firebase not
      // initialised yet, transient network) fall back to the local buffer.
      final pushed = await _tryPush(point);
      if (!pushed) {
        await _append(point);
      } else {
        // If we just came back online we may have leftover queued points too.
        await _drain();
      }
      _refreshStatus();
    } catch (e) {
      debugPrint('[LocationService] sample error: $e');
    }
  }

  Future<bool> _tryPush(TrackPoint p) async {
    if (!_online) return false;
    try {
      return await firebase.pushPoint(p);
    } catch (e) {
      debugPrint('[LocationService] push error: $e');
      return false;
    }
  }

  Future<void> _append(TrackPoint p) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_bufferKey) ?? <String>[];
    raw.add(jsonEncode(p.toJson()));
    await prefs.setStringList(_bufferKey, raw);
    _bufferedCount = raw.length;
    _refreshStatus();
  }

  Future<int> _bufferSize() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_bufferKey) ?? const []).length;
  }

  /// Push everything queued, in order. Any point that fails goes back to the
  /// front of the queue so we never lose a sample.
  Future<void> _drain() async {
    if (!_online) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_bufferKey) ?? <String>[];
    if (raw.isEmpty) {
      _bufferedCount = 0;
      _refreshStatus();
      return;
    }
    final failed = <String>[];
    for (final s in raw) {
      try {
        final p = TrackPoint.fromJson(jsonDecode(s) as Map<String, dynamic>);
        final ok = await firebase.pushPoint(p);
        if (!ok) failed.add(s);
      } catch (e) {
        // Malformed row — drop it so it doesn't jam the queue forever.
        debugPrint('[LocationService] drop malformed buffered point: $e');
      }
    }
    await prefs.setStringList(_bufferKey, failed);
    _bufferedCount = failed.length;
    _refreshStatus();
  }

  void _refreshStatus() {
    if (!_running) {
      _statusText = 'Idle';
    } else if (!_online) {
      _statusText = 'Offline · $_bufferedCount queued';
    } else if (_bufferedCount > 0) {
      _statusText = 'Syncing · $_bufferedCount queued';
    } else {
      _statusText = 'Tracking · synced';
    }
    notifyListeners();
  }
}
