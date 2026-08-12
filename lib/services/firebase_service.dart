import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'location_service.dart';

/// Thin wrapper around Firestore for MMU location writes. The mobile app calls
/// [pushPoint] for every GPS sample; the dashboard subscribes to the same
/// collection to render live positions and trails.
///
/// Firestore layout:
///   mmu_positions/{mmuId}
///     current              — last known point (small doc, dashboard listens here)
///     points/{autoId}      — full historical trail (paginated, dashboard reads on demand)
///
/// Setup — see `docs/firebase_setup.md` (also inlined in the response).
/// If Firebase isn't configured yet, [ensureInitialized] no-ops gracefully and
/// [pushPoint] returns false so the LocationService will just keep buffering.
class FirebaseService {
  bool _initialized = false;
  bool _initFailed = false;
  FirebaseFirestore? _db;

  bool get isReady => _initialized && _db != null;
  bool get initFailed => _initFailed;

  /// Call once at app startup. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_initialized || _initFailed) return;
    try {
      // Uses google-services.json on Android / GoogleService-Info.plist on iOS.
      // If missing, this throws — we catch, mark failed, and let location
      // sampling fall through to the offline buffer.
      await Firebase.initializeApp();
      _db = FirebaseFirestore.instance;
      _initialized = true;
      debugPrint('[FirebaseService] initialised');
    } catch (e) {
      _initFailed = true;
      debugPrint('[FirebaseService] init failed — running without cloud sync: $e');
    }
  }

  /// Push one GPS sample. Returns true only if the write actually succeeded.
  /// Returns false (without throwing) if Firebase isn't configured yet or the
  /// network write fails — the caller (LocationService) will buffer it.
  Future<bool> pushPoint(TrackPoint p) async {
    if (!isReady) return false;
    try {
      final mmuDoc = _db!.collection('mmu_positions').doc(p.mmuId);
      final data = {
        'mmuId': p.mmuId,
        'counsellor': p.counsellor,
        'lat': p.lat,
        'lng': p.lng,
        'accuracyMeters': p.accuracyMeters,
        'timestampMs': p.timestampMs,
        'serverTs': FieldValue.serverTimestamp(),
      };
      // Latest-known position for the live dot on the map.
      await mmuDoc.set(data, SetOptions(merge: true));
      // Append to the historical trail.
      await mmuDoc.collection('points').add(data);
      return true;
    } catch (e) {
      debugPrint('[FirebaseService] push failed: $e');
      return false;
    }
  }
}
